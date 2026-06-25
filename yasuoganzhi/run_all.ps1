$ErrorActionPreference = "Stop"

$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Dir

python compressed_sensing_simulation.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dir "generate_plots.ps1")

$intermediateFiles = @(
    "iteration_history.csv",
    "signal_reconstruction.csv",
    "summary.csv"
)

foreach ($file in $intermediateFiles) {
    $path = Join-Path $Dir $file
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
    }
}

Write-Output "All files generated in: $Dir"
Write-Output "Intermediate csv files cleaned. Final images and summary.txt are kept."
