$ErrorActionPreference = "Stop"

$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Dir

powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dir "prepare_image.ps1")
python image_denoising_experiment.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dir "export_images_and_plots.ps1")

$intermediateFiles = @(
    "clean_rgb_u8.raw",
    "noisy_rgb_u8.raw",
    "dct_denoised_rgb_u8.raw",
    "admm_tv_denoised_rgb_u8.raw",
    "iteration_history.csv",
    "summary.csv"
)

foreach ($file in $intermediateFiles) {
    $path = Join-Path $Dir $file
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
    }
}

Write-Output "All image denoising experiment files generated in: $Dir"
Write-Output "Intermediate raw/csv files cleaned. Final images and summary.txt are kept."
