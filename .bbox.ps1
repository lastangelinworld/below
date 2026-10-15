Add-Type -AssemblyName System.Drawing
$parts = 'head','torso','BackUpperArm','BackForearm','BackHand','FrontUpperArm','FrontForearm','FrontHand','BackThigh','FrontThigh','BackShin','FrontShin','BackFoot','FrontFoot'
foreach ($p in $parts) {
  $bmp = New-Object System.Drawing.Bitmap("D:\GAME1\below\Texture\$p.png")
  $minX=$bmp.Width; $minY=$bmp.Height; $maxX=-1; $maxY=-1
  for ($y=0; $y -lt $bmp.Height; $y+=2) {
    for ($x=0; $x -lt $bmp.Width; $x+=2) {
      $c = $bmp.GetPixel($x,$y)
      if ($c.A -gt 20) {
        if ($x -lt $minX){$minX=$x}; if ($x -gt $maxX){$maxX=$x}
        if ($y -lt $minY){$minY=$y}; if ($y -gt $maxY){$maxY=$y}
      }
    }
  }
  Write-Output ("{0}: canvas {1}x{2} bbox {3},{4} - {5},{6}" -f $p,$bmp.Width,$bmp.Height,$minX,$minY,$maxX,$maxY)
  $bmp.Dispose()
}
