# 任务二：压缩感知仿真实验

本实验对应题目：

`y = A x + n`

- `A`：`300 x 1000` 高斯随机观测矩阵
- `x`：`1000 x 1` 随机稀疏信号
- `n`：高斯噪声
- 任务：利用 L1 压缩感知算法从 `y` 恢复 `x`
- 要求：使用迭代阈值算法和 ADMM 算法恢复 `x`，并画出收敛性曲线

## 文件说明

- `compressed_sensing_simulation.py`：压缩感知仿真主程序，只依赖 `numpy`
- `generate_plots.ps1`：根据 CSV 结果生成 PNG 图片
- `run_all.ps1`：一键运行仿真并生成图片
- `summary.txt`：实验参数和最终误差
- `convergence_objective.png`：L1 目标函数收敛曲线
- `convergence_relative_error.png`：恢复相对误差收敛曲线


说明：`run_all.ps1` 运行过程中会临时生成 CSV 文件，用于绘制图片；运行结束后会自动清理这些中间文件，避免目录过于冗余。

## 运行方法

在 PowerShell 中进入该目录：

```powershell
cd "C:\Users\Administrator\Desktop\experence\yasuoganzhi"
```

一键运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_all.ps1
```

也可以分步运行：

```powershell
python compressed_sensing_simulation.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\generate_plots.ps1
```

## 算法说明

本实验求解的是带噪声情况下的 L1 正则化最小二乘模型：

```text
min_x ||Ax - y||_2^2 + lambda ||x||_1
```

迭代阈值算法使用软阈值更新：

```text
x(k+1) = S_{λ}(x(k) - t A^T(Ax(k)-y))
```

ADMM 将问题拆分为：

```text
min ||Ax-y||_2^2 + λ ||z||_1
s.t. x = z
```

其中 `z` 子问题同样使用软阈值完成稀疏化。
