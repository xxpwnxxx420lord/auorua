Add-Type -AssemblyName System.Drawing

$input = "C:\Users\johnny\Downloads\B\assets\backdrop.png"
$output = "C:\Users\johnny\Downloads\B\assets\backdrop-blur.png"

$src = [System.Drawing.Image]::FromFile($input)
$smallW = 110
$smallH = 69
$small = New-Object System.Drawing.Bitmap $smallW, $smallH
$g = [System.Drawing.Graphics]::FromImage($small)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.DrawImage($src, 0, 0, $smallW, $smallH)
$g.Dispose()

$tinyW = 48
$tinyH = 30
$tiny = New-Object System.Drawing.Bitmap $tinyW, $tinyH
$g = [System.Drawing.Graphics]::FromImage($tiny)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.DrawImage($small, 0, 0, $tinyW, $tinyH)
$g.Dispose()

$out = New-Object System.Drawing.Bitmap 1280, 800
$g = [System.Drawing.Graphics]::FromImage($out)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.DrawImage($tiny, 0, 0, 1280, 800)
$g.Dispose()

$out.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
$out.Dispose()
$small.Dispose()
$tiny.Dispose()
$src.Dispose()

Get-Item $output | Select-Object Name, Length
