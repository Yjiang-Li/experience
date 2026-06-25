import csv
from pathlib import Path

import numpy as np


OUT_DIR = Path(__file__).resolve().parent

M = 300
N = 1000
SPARSITY = 35
NOISE_SIGMA = 0.01
LAMBDA = 0.03
RHO = 1.0
MAX_ITER = 250
SEED = 2026


def soft_threshold(v, tau):
    return np.sign(v) * np.maximum(np.abs(v) - tau, 0.0)


def objective(A, y, x, lam):
    r = A @ x - y
    return 0.5 * np.dot(r, r) + lam * np.sum(np.abs(x))


def estimate_lipschitz(A, seed=0, steps=60):
    rng = np.random.default_rng(seed)
    v = rng.normal(size=A.shape[1])
    v = v / np.linalg.norm(v)
    for _ in range(steps):
        w = A.T @ (A @ v)
        nrm = np.linalg.norm(w)
        v = w / nrm
    return float(v @ (A.T @ (A @ v)))


def make_problem():
    rng = np.random.default_rng(SEED)
    A = rng.normal(0.0, 1.0 / np.sqrt(M), size=(M, N))

    x_true = np.zeros(N)
    support = rng.choice(N, size=SPARSITY, replace=False)
    signs = np.sign(rng.normal(size=SPARSITY))
    amplitudes = 0.8 + 1.2 * rng.random(SPARSITY)
    x_true[support] = signs * amplitudes

    noise = NOISE_SIGMA * rng.normal(size=M)
    y = A @ x_true + noise
    return A, x_true, y


def ista(A, y, x_true):
    lam = LAMBDA
    L = estimate_lipschitz(A)
    step = 0.95 / L
    x = np.zeros(A.shape[1])
    history = []

    for it in range(1, MAX_ITER + 1):
        grad = A.T @ (A @ x - y)
        x = soft_threshold(x - step * grad, lam * step)

        rel_error = np.linalg.norm(x - x_true) / np.linalg.norm(x_true)
        residual = np.linalg.norm(A @ x - y)
        history.append((it, objective(A, y, x, lam), rel_error, residual))

    return x, history, L


def admm(A, y, x_true):
    lam = LAMBDA
    rho = RHO
    m, n = A.shape

    x = np.zeros(n)
    z = np.zeros(n)
    u = np.zeros(n)

    Aty = A.T @ y
    woodbury = np.linalg.inv(np.eye(m) + (A @ A.T) / rho)
    history = []

    for it in range(1, MAX_ITER + 1):
        z_old = z.copy()

        q = Aty + rho * (z - u)
        x = q / rho - A.T @ (woodbury @ (A @ q)) / (rho * rho)
        z = soft_threshold(x + u, lam / rho)
        u = u + x - z

        rel_error = np.linalg.norm(z - x_true) / np.linalg.norm(x_true)
        residual = np.linalg.norm(A @ z - y)
        primal = np.linalg.norm(x - z)
        dual = rho * np.linalg.norm(z - z_old)
        history.append((it, objective(A, y, z, lam), rel_error, residual, primal, dual))

    return z, history


def write_outputs(A, y, x_true, x_ista, h_ista, x_admm, h_admm, lipschitz):
    with (OUT_DIR / "iteration_history.csv").open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow([
            "iteration",
            "ista_objective",
            "admm_objective",
            "ista_relative_error",
            "admm_relative_error",
            "ista_measurement_residual",
            "admm_measurement_residual",
            "admm_primal_residual",
            "admm_dual_residual",
        ])
        for a, b in zip(h_ista, h_admm):
            writer.writerow([a[0], a[1], b[1], a[2], b[2], a[3], b[3], b[4], b[5]])

    with (OUT_DIR / "signal_reconstruction.csv").open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(["index", "x_true", "x_ista", "x_admm"])
        for i in range(len(x_true)):
            writer.writerow([i, x_true[i], x_ista[i], x_admm[i]])

    ista_final_error = np.linalg.norm(x_ista - x_true) / np.linalg.norm(x_true)
    admm_final_error = np.linalg.norm(x_admm - x_true) / np.linalg.norm(x_true)
    ista_residual = np.linalg.norm(A @ x_ista - y)
    admm_residual = np.linalg.norm(A @ x_admm - y)

    summary = [
        ("M", M),
        ("N", N),
        ("sparsity", SPARSITY),
        ("noise_sigma", NOISE_SIGMA),
        ("lambda", LAMBDA),
        ("rho", RHO),
        ("max_iter", MAX_ITER),
        ("random_seed", SEED),
        ("estimated_lipschitz_constant", lipschitz),
        ("ista_final_relative_error", ista_final_error),
        ("admm_final_relative_error", admm_final_error),
        ("ista_measurement_residual", ista_residual),
        ("admm_measurement_residual", admm_residual),
    ]

    with (OUT_DIR / "summary.csv").open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(["item", "value"])
        writer.writerows(summary)

    with (OUT_DIR / "summary.txt").open("w", encoding="utf-8") as f:
        f.write("压缩感知仿真实验：y = Ax + n\n")
        f.write(f"A: {M} x {N} Gaussian random measurement matrix\n")
        f.write(f"x: {N} x 1 random sparse signal, sparsity = {SPARSITY}\n")
        f.write(f"n: Gaussian noise, sigma = {NOISE_SIGMA}\n\n")
        f.write("Recovery model: min_x 0.5 ||Ax-y||_2^2 + lambda ||x||_1\n")
        f.write(f"lambda = {LAMBDA}, rho = {RHO}, iterations = {MAX_ITER}\n\n")
        f.write(f"ISTA final relative error: {ista_final_error:.6f}\n")
        f.write(f"ADMM final relative error: {admm_final_error:.6f}\n")
        f.write(f"ISTA measurement residual: {ista_residual:.6f}\n")
        f.write(f"ADMM measurement residual: {admm_residual:.6f}\n")


def main():
    A, x_true, y = make_problem()
    x_ista, h_ista, lipschitz = ista(A, y, x_true)
    x_admm, h_admm = admm(A, y, x_true)
    write_outputs(A, y, x_true, x_ista, h_ista, x_admm, h_admm, lipschitz)

    print("Simulation finished.")
    print(f"Output directory: {OUT_DIR}")
    print("Generated: iteration_history.csv, signal_reconstruction.csv, summary.csv, summary.txt")


if __name__ == "__main__":
    main()
