$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InputImage = Join-Path $Dir "input_cat.jpg"
$RawFile = Join-Path $Dir "clean_rgb_u8.raw"
$CleanPng = Join-Path $Dir "clean_image.png"
$Size = 256

$src = [System.Drawing.Image]::FromFile($InputImage)
$bmp = New-Object System.Drawing.Bitmap $Size, $Size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.DrawImage($src, 0, 0, $Size, $Size)
$bmp.Save($CleanPng, [System.Drawing.Imaging.ImageFormat]::Png)

$bytes = New-Object byte[] ($Size * $Size * 3)
$idx = 0
for ($y = 0; $y -lt $Size; $y++) {
    for ($x = 0; $x -lt $Size; $x++) {
        $c = $bmp.GetPixel($x, $y)
        $bytes[$idx++] = [byte]$c.R
        $bytes[$idx++] = [byte]$c.G
        $bytes[$idx++] = [byte]$c.B
    }
}
[System.IO.File]::WriteAllBytes($RawFile, $bytes)

$g.Dispose()
$bmp.Dispose()
$src.Dispose()

Write-Output "Prepared clean image and raw RGB data."
