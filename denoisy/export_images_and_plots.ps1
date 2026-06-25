$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Size = 256
$Culture = [System.Globalization.CultureInfo]::InvariantCulture

function D($value) {
    return [double]::Parse([string]$value, $Culture)
}

function Raw-ToPng {
    param([string]$RawPath, [string]$PngPath)

    $data = [System.IO.File]::ReadAllBytes($RawPath)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $idx = 0
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $r = $data[$idx++]
            $g = $data[$idx++]
            $b = $data[$idx++]
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($r, $g, $b))
        }
    }
    $bmp.Save($PngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Draw-ComparisonGrid {
    param([string]$Output)

    $items = @(
        @{path="clean_image.png"; label="Clean image"},
        @{path="noisy_image.png"; label="Noisy image"},
        @{path="dct_soft_threshold_denoised.png"; label="DCT soft-threshold"},
        @{path="admm_tv_denoised.png"; label="ADMM-TV"}
    )
    $cellW = 300
    $cellH = 340
    $bmp = New-Object System.Drawing.Bitmap ($cellW * 2), ($cellH * 2)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $brush = [System.Drawing.Brushes]::Black

    for ($i = 0; $i -lt $items.Count; $i++) {
        $img = [System.Drawing.Image]::FromFile((Join-Path $Dir $items[$i].path))
        $x0 = ($i % 2) * $cellW
        $y0 = [Math]::Floor($i / 2) * $cellH
        $g.DrawImage($img, $x0 + 22, $y0 + 20, 256, 256)
        $g.DrawString($items[$i].label, $font, $brush, $x0 + 42, $y0 + 292)
        $img.Dispose()
    }

    $bmp.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

function Draw-LinePlot {
    param(
        [object[]]$Rows,
        [string[]]$YColumns,
        [string[]]$Labels,
        [System.Drawing.Color[]]$Colors,
        [string]$Title,
        [string]$Output,
        [bool]$LogY = $false
    )

    $width = 1200
    $height = 760
    $left = 95
    $right = 45
    $top = 65
    $bottom = 90
    $plotW = $width - $left - $right
    $plotH = $height - $top - $bottom

    $xs = @()
    foreach ($r in $Rows) { $xs += D $r.iteration }
    $xmin = ($xs | Measure-Object -Minimum).Minimum
    $xmax = ($xs | Measure-Object -Maximum).Maximum

    $allY = @()
    foreach ($col in $YColumns) {
        foreach ($r in $Rows) {
            $v = D $r.$col
            if ($LogY) { $v = [Math]::Log10([Math]::Max($v, 1e-12)) }
            $allY += $v
        }
    }
    $ymin = ($allY | Measure-Object -Minimum).Minimum
    $ymax = ($allY | Measure-Object -Maximum).Maximum
    $pad = 0.08 * ($ymax - $ymin)
    if ($pad -eq 0) { $pad = 1 }
    $ymin -= $pad
    $ymax += $pad

    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::White)

    $font = New-Object System.Drawing.Font("Segoe UI", 13)
    $titleFont = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
    $smallFont = New-Object System.Drawing.Font("Segoe UI", 11)
    $axisPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
    $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 220, 220), 1)
    $brush = [System.Drawing.Brushes]::Black

    $g.DrawString($Title, $titleFont, $brush, 330, 20)
    $g.DrawRectangle($axisPen, $left, $top, $plotW, $plotH)

    for ($i = 0; $i -le 5; $i++) {
        $x = $left + $plotW * $i / 5
        $y = $top + $plotH * $i / 5
        $g.DrawLine($gridPen, $x, $top, $x, $top + $plotH)
        $g.DrawLine($gridPen, $left, $y, $left + $plotW, $y)

        $xv = $xmin + ($xmax - $xmin) * $i / 5
        $yv = $ymax - ($ymax - $ymin) * $i / 5
        $g.DrawString(("{0:F0}" -f $xv), $smallFont, $brush, $x - 15, $top + $plotH + 10)
        $g.DrawString(("{0:F2}" -f $yv), $smallFont, $brush, 15, $y - 10)
    }

    for ($s = 0; $s -lt $YColumns.Count; $s++) {
        $col = $YColumns[$s]
        $pen = New-Object System.Drawing.Pen($Colors[$s], 3)
        $prev = $null
        foreach ($r in $Rows) {
            $xv = D $r.iteration
            $yv = D $r.$col
            if ($LogY) { $yv = [Math]::Log10([Math]::Max($yv, 1e-12)) }
            $px = $left + ($xv - $xmin) / ($xmax - $xmin) * $plotW
            $py = $top + ($ymax - $yv) / ($ymax - $ymin) * $plotH
            if ($null -ne $prev) { $g.DrawLine($pen, $prev[0], $prev[1], $px, $py) }
            $prev = @($px, $py)
        }
        $legendX = $left + 710
        $legendY = $top + 25 + 28 * $s
        $g.DrawLine($pen, $legendX, $legendY + 8, $legendX + 42, $legendY + 8)
        $g.DrawString($Labels[$s], $font, $brush, $legendX + 52, $legendY)
    }

    $ylabel = "Value"
    if ($LogY) { $ylabel = "log10(Value)" }
    $g.DrawString("Iteration", $font, $brush, $left + $plotW / 2 - 35, $height - 42)
    $g.DrawString($ylabel, $font, $brush, 18, 28)

    $bmp.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

Raw-ToPng (Join-Path $Dir "noisy_rgb_u8.raw") (Join-Path $Dir "noisy_image.png")
Raw-ToPng (Join-Path $Dir "dct_denoised_rgb_u8.raw") (Join-Path $Dir "dct_soft_threshold_denoised.png")
Raw-ToPng (Join-Path $Dir "admm_tv_denoised_rgb_u8.raw") (Join-Path $Dir "admm_tv_denoised.png")
Draw-ComparisonGrid (Join-Path $Dir "comparison_grid.png")

$History = Import-Csv -LiteralPath (Join-Path $Dir "iteration_history.csv")
Draw-LinePlot `
    -Rows $History `
    -YColumns @("dct_objective", "tv_objective") `
    -Labels @("DCT soft-threshold objective", "ADMM-TV objective") `
    -Colors @([System.Drawing.Color]::FromArgb(40,120,210), [System.Drawing.Color]::FromArgb(220,90,40)) `
    -Title "Image denoising objective convergence" `
    -Output (Join-Path $Dir "convergence_objective.png") `
    -LogY $true

Draw-LinePlot `
    -Rows $History `
    -YColumns @("dct_psnr", "tv_psnr") `
    -Labels @("DCT soft-threshold PSNR", "ADMM-TV PSNR") `
    -Colors @([System.Drawing.Color]::FromArgb(40,120,210), [System.Drawing.Color]::FromArgb(220,90,40)) `
    -Title "Image denoising PSNR convergence" `
    -Output (Join-Path $Dir "convergence_psnr.png") `
    -LogY $false

Write-Output "Images and plots exported."
