# Generates assets/icon.png and assets/icon_fg.png with GDI+.
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$assets = Join-Path $root 'assets'
New-Item -ItemType Directory -Force -Path $assets | Out-Null

function Draw-Flame([System.Drawing.Graphics]$g, [double]$s) {
  # flame body path
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.StartFigure()
  [void]$p.AddBezier(
    (pt ($s*0.50) ($s*0.06)), (pt ($s*0.78) ($s*0.30)), (pt ($s*0.86) ($s*0.52)), (pt ($s*0.72) ($s*0.74)))
  [void]$p.AddBezier(
    (pt ($s*0.72) ($s*0.74)), (pt ($s*0.66) ($s*0.86)), (pt ($s*0.58) ($s*0.94)), (pt ($s*0.50) ($s*0.97)))
  [void]$p.AddBezier(
    (pt ($s*0.50) ($s*0.97)), (pt ($s*0.42) ($s*0.94)), (pt ($s*0.34) ($s*0.86)), (pt ($s*0.28) ($s*0.74)))
  [void]$p.AddBezier(
    (pt ($s*0.28) ($s*0.74)), (pt ($s*0.14) ($s*0.52)), (pt ($s*0.22) ($s*0.30)), (pt ($s*0.50) ($s*0.06)))
  $p.CloseFigure()

  # vertical gradient gold -> ember -> deep red
  $rectF = New-Object System.Drawing.RectangleF(0, 0, [float]$s, [float]$s)
  $gradTop = [System.Drawing.Color]::FromArgb(255, 255, 197, 61)
  $gradMid = [System.Drawing.Color]::FromArgb(255, 255, 106, 61)
  $gradEnd = [System.Drawing.Color]::FromArgb(255, 229, 72, 77)
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectF, $gradTop, $gradEnd, 90)
  $cb = New-Object System.Drawing.Drawing2D.ColorBlend 3
  $cb.Colors = @($gradTop, $gradMid, $gradEnd)
  $cb.Positions = @(0.0, 0.45, 1.0)
  $brush.InterpolationColors = $cb
  $g.FillPath($brush, $p)

  # inner core
  $core = New-Object System.Drawing.Drawing2D.GraphicsPath
  $core.StartFigure()
  [void]$core.AddBezier(
    (pt ($s*0.50) ($s*0.46)), (pt ($s*0.62) ($s*0.60)), (pt ($s*0.64) ($s*0.72)), (pt ($s*0.56) ($s*0.84)))
  [void]$core.AddBezier(
    (pt ($s*0.56) ($s*0.84)), (pt ($s*0.53) ($s*0.88)), (pt ($s*0.51) ($s*0.90)), (pt ($s*0.50) ($s*0.90)))
  [void]$core.AddBezier(
    (pt ($s*0.50) ($s*0.90)), (pt ($s*0.47) ($s*0.88)), (pt ($s*0.44) ($s*0.84)), (pt ($s*0.44) ($s*0.84)))
  [void]$core.AddBezier(
    (pt ($s*0.44) ($s*0.84)), (pt ($s*0.36) ($s*0.72)), (pt ($s*0.38) ($s*0.60)), (pt ($s*0.50) ($s*0.46)))
  $core.CloseFigure()
  $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 255, 255, 255))
  $g.FillPath($white, $core)

  # eye spark
  $eyeR = $s * 0.045
  $eyeBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 255, 244, 240))
  $g.FillEllipse($eyeBrush, [float]($s*0.5 - $eyeR), [float]($s*0.34 - $eyeR), [float](2*$eyeR), [float](2*$eyeR))

  # wing strokes
  $penW = [float]($s * 0.040)
  $wingColor = [System.Drawing.Color]::FromArgb(215, 255, 197, 61)
  $wing = New-Object System.Drawing.Pen($wingColor, $penW)
  $wing.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $wing.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawLine($wing, [float]($s*0.13), [float]($s*0.40), [float]($s*0.02), [float]($s*0.28))
  $g.DrawLine($wing, [float]($s*0.87), [float]($s*0.40), [float]($s*0.98), [float]($s*0.28))

  $p.Dispose(); $core.Dispose(); $brush.Dispose(); $white.Dispose(); $eyeBrush.Dispose(); $wing.Dispose()
}

function pt([double]$x, [double]$y) {
  return New-Object System.Drawing.PointF([float]$x, [float]$y)
}

function New-Icon([string]$outFile, [int]$size, [bool]$bg) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

  if ($bg) {
    $b = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 11, 12, 16))
    $g.FillRectangle($b, 0, 0, $size, $size)
    # radial ember glow
    $glowR = $size * 0.55
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    [void]$gp.AddEllipse([float]($size*0.5 - $glowR), [float]($size*0.48 - $glowR), [float](2*$glowR), [float](2*$glowR))
    $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp)
    $pgb.CenterColor = [System.Drawing.Color]::FromArgb(90, 255, 106, 61)
    $pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 106, 61))
    $g.FillPath($pgb, $gp)
    $b.Dispose(); $gp.Dispose(); $pgb.Dispose()
    # full-bleed flame
    Draw-Flame $g $size
  }
  else {
    # foreground: flame at ~66 percent, centered slightly high for adaptive icon safe zone
    $scale = 0.62 * $size
    $ox = ($size - $scale) / 2.0
    $oy = ($size * 0.44 - $scale / 2.0)
    $g.TranslateTransform([float]$ox, [float]$oy)
    Draw-Flame $g $scale
    $g.ResetTransform()
  }

  $bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Host "wrote $outFile"
}

New-Icon -outFile (Join-Path $assets 'icon.png')   -size 1024 -bg $true
New-Icon -outFile (Join-Path $assets 'icon_fg.png') -size 1024 -bg $false
