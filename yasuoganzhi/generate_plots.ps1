$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$History = Import-Csv -LiteralPath (Join-Path $Dir "iteration_history.csv")
$Signal = Import-Csv -LiteralPath (Join-Path $Dir "signal_reconstruction.csv")
$Culture = [System.Globalization.CultureInfo]::InvariantCulture

function D($value) {
    return [double]::Parse([string]$value, $Culture)
}

function Draw-LinePlot {
    param(
        [object[]]$Rows,
        [string]$XColumn,
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
    foreach ($r in $Rows) { $xs += D $r.$XColumn }
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
    if ([Math]::Abs($ymax - $ymin) -lt 1e-12) { $ymax = $ymin + 1.0 }
    $pad = 0.08 * ($ymax - $ymin)
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

    $g.DrawString($Title, $titleFont, $brush, 320, 20)
    $g.DrawRectangle($axisPen, $left, $top, $plotW, $plotH)

    for ($i = 0; $i -le 5; $i++) {
        $x = $left + $plotW * $i / 5
        $y = $top + $plotH * $i / 5
        $g.DrawLine($gridPen, $x, $top, $x, $top + $plotH)
        $g.DrawLine($gridPen, $left, $y, $left + $plotW, $y)

        $xv = $xmin + ($xmax - $xmin) * $i / 5
        $yv = $ymax - ($ymax - $ymin) * $i / 5
        if ($LogY) { $ylabel = ("{0:F2}" -f $yv) } else { $ylabel = ("{0:F3}" -f $yv) }
        $g.DrawString(("{0:F0}" -f $xv), $smallFont, $brush, $x - 15, $top + $plotH + 10)
        $g.DrawString($ylabel, $smallFont, $brush, 10, $y - 10)
    }

    for ($s = 0; $s -lt $YColumns.Count; $s++) {
        $col = $YColumns[$s]
        $pen = New-Object System.Drawing.Pen($Colors[$s], 3)
        $prev = $null
        foreach ($r in $Rows) {
            $xv = D $r.$XColumn
            $yv = D $r.$col
            if ($LogY) { $yv = [Math]::Log10([Math]::Max($yv, 1e-12)) }
            $px = $left + ($xv - $xmin) / ($xmax - $xmin) * $plotW
            $py = $top + ($ymax - $yv) / ($ymax - $ymin) * $plotH
            if ($null -ne $prev) { $g.DrawLine($pen, $prev[0], $prev[1], $px, $py) }
            $prev = @($px, $py)
        }

        $legendX = $left + 720
        $legendY = $top + 25 + 28 * $s
        $g.DrawLine($pen, $legendX, $legendY + 8, $legendX + 42, $legendY + 8)
        $g.DrawString($Labels[$s], $font, $brush, $legendX + 52, $legendY)
    }

    $g.DrawString("Iteration", $font, $brush, $left + $plotW / 2 - 35, $height - 42)
    $ylabelText = "Value"
    if ($LogY) { $ylabelText = "log10(Value)" }
    $g.DrawString($ylabelText, $font, $brush, 18, 28)

    $bmp.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

function Draw-SignalPlot {
    param([object[]]$Rows, [string]$Output)

    $width = 1200
    $height = 760
    $left = 95
    $right = 45
    $top = 65
    $bottom = 90
    $plotW = $width - $left - $right
    $plotH = $height - $top - $bottom

    $xs = @()
    $ys = @()
    foreach ($r in $Rows) {
        $xs += D $r.index
        $ys += D $r.x_true
        $ys += D $r.x_ista
        $ys += D $r.x_admm
    }
    $xmin = 0
    $xmax = ($xs | Measure-Object -Maximum).Maximum
    $ymin = ($ys | Measure-Object -Minimum).Minimum
    $ymax = ($ys | Measure-Object -Maximum).Maximum
    $pad = 0.12 * ($ymax - $ymin)
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
    $truePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 70, 70), 2)
    $istaPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(40, 120, 210), 2)
    $admmPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 90, 40), 2)
    $brush = [System.Drawing.Brushes]::Black
    $istaBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 120, 210))
    $admmBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 90, 40))

    $g.DrawString("Sparse signal reconstruction", $titleFont, $brush, 330, 20)
    $g.DrawRectangle($axisPen, $left, $top, $plotW, $plotH)

    for ($i = 0; $i -le 5; $i++) {
        $x = $left + $plotW * $i / 5
        $y = $top + $plotH * $i / 5
        $g.DrawLine($gridPen, $x, $top, $x, $top + $plotH)
        $g.DrawLine($gridPen, $left, $y, $left + $plotW, $y)
        $g.DrawString(("{0:F0}" -f ($xmin + ($xmax - $xmin) * $i / 5)), $smallFont, $brush, $x - 15, $top + $plotH + 10)
        $g.DrawString(("{0:F2}" -f ($ymax - ($ymax - $ymin) * $i / 5)), $smallFont, $brush, 15, $y - 10)
    }

    $zeroY = $top + ($ymax - 0) / ($ymax - $ymin) * $plotH
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150,150,150), 1)), $left, $zeroY, $left + $plotW, $zeroY)

    foreach ($r in $Rows) {
        $idx = D $r.index
        $trueVal = D $r.x_true
        if ([Math]::Abs($trueVal) -gt 1e-10) {
            $px = $left + ($idx - $xmin) / ($xmax - $xmin) * $plotW
            $pyTrue = $top + ($ymax - $trueVal) / ($ymax - $ymin) * $plotH
            $ista = D $r.x_ista
            $admm = D $r.x_admm
            $pyIsta = $top + ($ymax - $ista) / ($ymax - $ymin) * $plotH
            $pyAdmm = $top + ($ymax - $admm) / ($ymax - $ymin) * $plotH
            $g.DrawLine($truePen, $px, $zeroY, $px, $pyTrue)
            $g.FillEllipse([System.Drawing.Brushes]::Black, $px - 3, $pyTrue - 3, 6, 6)
            $g.FillEllipse($istaBrush, $px - 4, $pyIsta - 4, 8, 8)
            $g.FillEllipse($admmBrush, $px - 4, $pyAdmm - 4, 8, 8)
        }
    }

    $legendX = $left + 720
    $legendY = $top + 25
    $g.DrawLine($truePen, $legendX, $legendY + 8, $legendX + 42, $legendY + 8)
    $g.DrawString("true sparse signal", $font, $brush, $legendX + 52, $legendY)
    $g.FillEllipse($istaBrush, $legendX + 12, $legendY + 35, 10, 10)
    $g.DrawString("ISTA recovery", $font, $brush, $legendX + 52, $legendY + 28)
    $g.FillEllipse($admmBrush, $legendX + 12, $legendY + 63, 10, 10)
    $g.DrawString("ADMM recovery", $font, $brush, $legendX + 52, $legendY + 56)

    $g.DrawString("Signal index", $font, $brush, $left + $plotW / 2 - 38, $height - 42)
    $g.DrawString("Amplitude", $font, $brush, 18, 28)

    $bmp.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

Draw-LinePlot `
    -Rows $History `
    -XColumn "iteration" `
    -YColumns @("ista_objective", "admm_objective") `
    -Labels @("ISTA objective", "ADMM objective") `
    -Colors @([System.Drawing.Color]::FromArgb(40,120,210), [System.Drawing.Color]::FromArgb(220,90,40)) `
    -Title "L1 objective convergence" `
    -Output (Join-Path $Dir "convergence_objective.png") `
    -LogY $true

Draw-LinePlot `
    -Rows $History `
    -XColumn "iteration" `
    -YColumns @("ista_relative_error", "admm_relative_error") `
    -Labels @("ISTA relative error", "ADMM relative error") `
    -Colors @([System.Drawing.Color]::FromArgb(40,120,210), [System.Drawing.Color]::FromArgb(220,90,40)) `
    -Title "Recovery error convergence" `
    -Output (Join-Path $Dir "convergence_relative_error.png") `
    -LogY $true

Draw-SignalPlot -Rows $Signal -Output (Join-Path $Dir "signal_reconstruction.png")

Write-Output "Plots generated."
