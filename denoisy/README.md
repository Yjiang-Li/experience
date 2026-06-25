# 作业2：图像去噪实验

实验要求：

```text
y = x + n
```

1. 对清晰图像添加高斯噪声。
2. 在 DCT 域 / TV 域构建目标函数。
3. 利用迭代阈值 / ADMM 算法恢复图像 `x`。
4. 画出迭代算法的收敛性曲线。

## 文件说明

- `input_cat.jpg`：原始小猫图像
- `prepare_image.ps1`：将原图缩放为 `256 x 256`，并导出原图 raw 数据
- `image_denoising_experiment.py`：图像去噪主程序
- `export_images_and_plots.ps1`：将 raw 结果导出为 PNG，并绘制收敛曲线
- `run_all.ps1`：一键运行全部流程
- `summary.txt`：实验参数和最终指标


## 输出图片

- `clean_image.png`：清晰原图
- `noisy_image.png`：加入高斯噪声后的图像
- `dct_soft_threshold_denoised.png`：DCT 域软阈值去噪结果
- `admm_tv_denoised.png`：ADMM-TV 去噪结果
- `comparison_grid.png`：四图对比
- `convergence_objective.png`：目标函数收敛曲线
- `convergence_psnr.png`：PSNR 收敛曲线

## 运行方法

```powershell
cd "C:\Users\Administrator\Desktop\experience\denoisy"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_all.ps1
```

## 算法模型

DCT 软阈值方法求解：

```text
min_x ||x-y||_2^2 + lambda ||DCT(x)||_1
```

ADMM-TV 方法求解：

```text
min_x ||x-y||_2^2 + lambda TV(x)
```

其中 `TV(x)` 为图像梯度的 L1 范数，能够在去噪的同时保持图像边缘。
