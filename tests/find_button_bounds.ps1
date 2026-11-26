Add-Type -AssemblyName System.Drawing
$b = [System.Drawing.Bitmap]::FromFile((Resolve-Path "assets/ui/stage08_iron_peak/screens/01_intro.png"))
$w = $b.Width
$h = $b.Height

# Top-Right icons
# Find blue box or white icon bounds in top-right area (x > 0.8 * w, y < 0.25 * h)
$gearMinX = $w; $gearMaxX = 0; $gearMinY = $h; $gearMaxY = 0
$backMinX = $w; $backMaxX = 0; $backMinY = $h; $backMaxY = 0

for ($y = [int]($h * 0.02); $y -lt [int]($h * 0.2); $y++) {
    for ($x = [int]($w * 0.83); $x -lt [int]($w * 0.92); $x++) {
        $c = $b.GetPixel($x, $y)
        # dark navy/steel button background or white icon
        if (($c.R -gt 200 -and $c.G -gt 200 -and $c.B -gt 200) -or ($c.B -gt 50 -and $c.R -lt 40)) {
            if ($x -lt $gearMinX) { $gearMinX = $x }
            if ($x -gt $gearMaxX) { $gearMaxX = $x }
            if ($y -lt $gearMinY) { $gearMinY = $y }
            if ($y -gt $gearMaxY) { $gearMaxY = $y }
        }
    }
    for ($x = [int]($w * 0.91); $x -lt $w; $x++) {
        $c = $b.GetPixel($x, $y)
        if (($c.R -gt 200 -and $c.G -gt 200 -and $c.B -gt 200) -or ($c.B -gt 50 -and $c.R -lt 40)) {
            if ($x -lt $backMinX) { $backMinX = $x }
            if ($x -gt $backMaxX) { $backMaxX = $x }
            if ($y -lt $backMinY) { $bBackMinY = $y }
            if ($y -gt $backMaxY) { $backMaxY = $y }
        }
    }
}
Write-Host "Gear button bounds: X=($gearMinX to $gearMaxX), Y=($gearMinY to $gearMaxY)"
Write-Host "Gear ratios: Left=$($gearMinX/$w), Right=$($gearMaxX/$w), Top=$($gearMinY/$h), Bottom=$($gearMaxY/$h)"
Write-Host "Back button bounds: X=($backMinX to $backMaxX), Y=($backMinY to $backMaxY)"
Write-Host "Back ratios: Left=$($backMinX/$w), Right=$($backMaxX/$w), Top=$($gearMinY/$h), Bottom=$($backMaxY/$h)"

$b.Dispose()
