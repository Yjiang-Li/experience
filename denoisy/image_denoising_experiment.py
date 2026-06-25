import csv
from pathlib import Path

import numpy as np


OUT_DIR = Path(__file__).resolve().parent
SIZE = 256
CHANNELS = 3
NOISE_SIGMA = 0.08
DCT_LAMBDA = 0.035
TV_LAMBDA = 0.055
RHO = 1.0
DCT_ITER = 80
TV_ITER = 120
SEED = 2026


def read_raw_image(path):
    data = np.fromfile(path, dtype=np.uint8)
    img = data.reshape(SIZE, SIZE, CHANNELS).astype(np.float64) / 255.0
    return img


def write_raw_image(path, img):
    arr = np.clip(img * 255.0 + 0.5, 0, 255).astype(np.uint8)
    arr.tofile(path)


def soft_threshold(x, tau):
    return np.sign(x) * np.maximum(np.abs(x) - tau, 0.0)


def psnr(x, ref):
    mse = np.mean((x - ref) ** 2)
    if mse <= 1e-14:
        return 99.0
    return 10.0 * np.log10(1.0 / mse)


def rel_error(x, ref):
    return np.linalg.norm(x - ref) / np.linalg.norm(ref)


def dct_matrix(n):
    i = np.arange(n)
    k = i.reshape(-1, 1)
    mat = np.cos(np.pi * (i + 0.5) * k / n)
    mat[0, :] *= np.sqrt(1.0 / n)
    mat[1:, :] *= np.sqrt(2.0 / n)
    return mat


def dct2(img, c):
    out = np.empty_like(img)
    for ch in range(img.shape[2]):
        out[:, :, ch] = c @ img[:, :, ch] @ c.T
    return out


def idct2(coef, c):
    out = np.empty_like(coef)
    for ch in range(coef.shape[2]):
        out[:, :, ch] = c.T @ coef[:, :, ch] @ c
    return out


def dct_objective(x, y, c):
    coef = dct2(x, c)
    return 0.5 * np.sum((x - y) ** 2) + DCT_LAMBDA * np.sum(np.abs(coef))


def dct_soft_threshold_denoise(y, clean):
    c = dct_matrix(y.shape[0])
    x = y.copy()
    step = 0.85
    history = []

    for it in range(1, DCT_ITER + 1):
        v = x - step * (x - y)
        coef = dct2(v, c)
        coef = soft_threshold(coef, DCT_LAMBDA * step)
        x = np.clip(idct2(coef, c), 0.0, 1.0)

        history.append((
            it,
            dct_objective(x, y, c),
            psnr(x, clean),
            rel_error(x, clean),
        ))

    return x, history


def gradient(x):
    gx = np.roll(x, -1, axis=1) - x
    gy = np.roll(x, -1, axis=0) - x
    return gx, gy


def divergence(px, py):
    return (np.roll(px, 1, axis=1) - px) + (np.roll(py, 1, axis=0) - py)


def tv_value(x):
    gx, gy = gradient(x)
    return np.sum(np.abs(gx)) + np.sum(np.abs(gy))


def tv_objective(x, y):
    return 0.5 * np.sum((x - y) ** 2) + TV_LAMBDA * tv_value(x)


def admm_tv_denoise(y, clean):
    h, w, ch = y.shape
    x = y.copy()
    zx = np.zeros_like(y)
    zy = np.zeros_like(y)
    ux = np.zeros_like(y)
    uy = np.zeros_like(y)

    ky = np.arange(h).reshape(-1, 1)
    kx = np.arange(w).reshape(1, -1)
    denom2d = 1.0 + RHO * (
        4.0 * np.sin(np.pi * kx / w) ** 2
        + 4.0 * np.sin(np.pi * ky / h) ** 2
    )
    denom = denom2d[:, :, None]

    history = []
    for it in range(1, TV_ITER + 1):
        rhs = y + RHO * divergence(zx - ux, zy - uy)
        x = np.real(np.fft.ifft2(np.fft.fft2(rhs, axes=(0, 1)) / denom, axes=(0, 1)))
        x = np.clip(x, 0.0, 1.0)

        gx, gy = gradient(x)
        zx_old = zx.copy()
        zy_old = zy.copy()
        zx = soft_threshold(gx + ux, TV_LAMBDA / RHO)
        zy = soft_threshold(gy + uy, TV_LAMBDA / RHO)
        ux += gx - zx
        uy += gy - zy

        primal = np.sqrt(np.mean((gx - zx) ** 2 + (gy - zy) ** 2))
        dual = RHO * np.sqrt(np.mean((zx - zx_old) ** 2 + (zy - zy_old) ** 2))
        history.append((
            it,
            tv_objective(x, y),
            psnr(x, clean),
            rel_error(x, clean),
            primal,
            dual,
        ))

    return x, history


def save_history(dct_history, tv_history):
    with (OUT_DIR / "iteration_history.csv").open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow([
            "iteration",
            "dct_objective",
            "tv_objective",
            "dct_psnr",
            "tv_psnr",
            "dct_relative_error",
            "tv_relative_error",
            "tv_primal_residual",
            "tv_dual_residual",
        ])
        max_iter = max(len(dct_history), len(tv_history))
        for i in range(max_iter):
            d = dct_history[min(i, len(dct_history) - 1)]
            t = tv_history[min(i, len(tv_history) - 1)]
            writer.writerow([i + 1, d[1], t[1], d[2], t[2], d[3], t[3], t[4], t[5]])


def save_summary(clean, noisy, dct_img, tv_img):
    rows = [
        ("image_size", f"{SIZE} x {SIZE}"),
        ("noise_sigma", NOISE_SIGMA),
        ("dct_lambda", DCT_LAMBDA),
        ("tv_lambda", TV_LAMBDA),
        ("rho", RHO),
        ("dct_iterations", DCT_ITER),
        ("tv_iterations", TV_ITER),
        ("noisy_psnr", psnr(noisy, clean)),
        ("dct_denoised_psnr", psnr(dct_img, clean)),
        ("admm_tv_denoised_psnr", psnr(tv_img, clean)),
        ("noisy_relative_error", rel_error(noisy, clean)),
        ("dct_relative_error", rel_error(dct_img, clean)),
        ("admm_tv_relative_error", rel_error(tv_img, clean)),
    ]

    with (OUT_DIR / "summary.csv").open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(["item", "value"])
        writer.writerows(rows)

    with (OUT_DIR / "summary.txt").open("w", encoding="utf-8") as f:
        f.write("图像去噪实验：y = x + n\n")
        f.write("实验方法：DCT域软阈值迭代去噪；ADMM-TV去噪\n\n")
        for k, v in rows:
            f.write(f"{k}: {v}\n")


def main():
    clean = read_raw_image(OUT_DIR / "clean_rgb_u8.raw")
    rng = np.random.default_rng(SEED)
    noisy = np.clip(clean + NOISE_SIGMA * rng.normal(size=clean.shape), 0.0, 1.0)

    dct_img, dct_history = dct_soft_threshold_denoise(noisy, clean)
    tv_img, tv_history = admm_tv_denoise(noisy, clean)

    write_raw_image(OUT_DIR / "noisy_rgb_u8.raw", noisy)
    write_raw_image(OUT_DIR / "dct_denoised_rgb_u8.raw", dct_img)
    write_raw_image(OUT_DIR / "admm_tv_denoised_rgb_u8.raw", tv_img)
    save_history(dct_history, tv_history)
    save_summary(clean, noisy, dct_img, tv_img)

    print("Image denoising simulation finished.")
    print(f"Output directory: {OUT_DIR}")


if __name__ == "__main__":
    main()
