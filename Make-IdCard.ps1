# make-idcard.ps1
# aufruf: .\make-idcard.ps1 "Org,Name,Role,ID,Valid,PhotoFile,OutFile"

Param([string]$ArgsLine)

$MagickPath = "C:\Program Files (x86)\ImageMagick-7.1.2-Q16-HDRI\magick.exe"
if (-not (Test-Path $MagickPath)) { Write-Host "magick.exe fehlt -> $MagickPath"; exit 1 }

# env
$MagickDir = Split-Path $MagickPath -Parent
$env:MAGICK_HOME = $MagickDir
$env:MAGICK_CODER_MODULE_PATH = Join-Path $MagickDir "modules\coders"
$env:MAGICK_CONFIGURE_PATH    = $MagickDir
if ($env:Path -notlike "*$MagickDir*") { $env:Path += ";$MagickDir" }

# feste ordner
$PhotoDir = "C:\Mac\Home\Documents\Scripting\Scripting Projekt\Bilder\"
$OutDir   = "C:\Mac\Home\Documents\Scripting\Scripting Projekt\"

# args parsen
if ([string]::IsNullOrWhiteSpace($ArgsLine)) {
  Write-Host "erwartet: ""Org,Name,Role,ID,Valid,PhotoFile,OutFile"""
  exit 1
}
$parts = $ArgsLine -split ","
if ($parts.Count -lt 7) {
  Write-Host "zu wenige felder (7 benoetigt)"
  exit 1
}
$Org      = $parts[0].Trim()
$FullName = $parts[1].Trim()
$Role     = $parts[2].Trim()
$CardId   = $parts[3].Trim()
$Valid    = $parts[4].Trim()
$Photo    = if ([string]::IsNullOrWhiteSpace($parts[5])) { "" } else { Join-Path $PhotoDir $parts[5].Trim() }
$Out      = if ([string]::IsNullOrWhiteSpace($parts[6])) { Join-Path $OutDir "idcard.png" } else { Join-Path $OutDir $parts[6].Trim() }

# probe
& $MagickPath -size 8x8 xc:#FFFFFF _probe.png 2>$null
if (-not (Test-Path "_probe.png")) { Write-Host "imagemagick modules problem (xc)"; exit 1 }
Remove-Item _probe.png -ErrorAction SilentlyContinue

# layout
$WIDTH=1011; $HEIGHT=638; $HEADER=140; $MARGIN=60
$ACCENT="#0F766E"; $TEXT="#111111"; $SUBT="#444444"; $BG="#FFFFFF"
$Y_Name = $HEADER + 40; $Y_Role = $HEADER + 88; $Y_Id = $HEADER + 140; $Y_Val = $HEADER + 180

# basis + header
& $MagickPath -size "${WIDTH}x${HEIGHT}" "xc:$BG" m_base.png
& $MagickPath m_base.png -fill $ACCENT -draw "rectangle 0,0 $WIDTH,$HEADER" m_base.png

# texte
& $MagickPath m_base.png `
  -fill white -gravity Northwest -pointsize 44 -annotate +$MARGIN+48 "$Org" `
  -fill $TEXT  -gravity Northwest -pointsize 38 -annotate +$MARGIN+$Y_Name "$FullName" `
  -fill $SUBT  -gravity Northwest -pointsize 28 -annotate +$MARGIN+$Y_Role "$Role" `
  -fill $SUBT  -gravity Northwest -pointsize 26 -annotate +$MARGIN+$Y_Id   "ID: $CardId" `
  -fill $SUBT  -gravity Northwest -pointsize 26 -annotate +$MARGIN+$Y_Val  "Gueltig bis: $Valid" `
  m_base.png

# foto optional
if (-not [string]::IsNullOrWhiteSpace($Photo) -and (Test-Path $Photo)) {
  $PhotoSize = 340; $PhotoX = $WIDTH - $PhotoSize - $MARGIN; $PhotoY = $HEADER + 30
  & $MagickPath -size "${PhotoSize}x${PhotoSize}" xc:none -fill white -draw "circle 170,170 170,0" m_pmask.png
  & $MagickPath "$Photo" -auto-orient -resize ${PhotoSize}x${PhotoSize}^ -gravity center -extent ${PhotoSize}x${PhotoSize} m_ptmp.png
  & $MagickPath m_ptmp.png m_pmask.png -compose DstIn -composite m_photo.png
  & $MagickPath m_base.png m_photo.png -gravity Northwest -geometry "+$PhotoX+$PhotoY" -compose Over -composite m_base.png
}

# qr falls vorhanden
$qr = Get-Command qrencode -ErrorAction SilentlyContinue
if ($qr) {
  $payload = "$FullName | $CardId"
  $tmp = [IO.Path]::GetTempFileName()
  Set-Content -LiteralPath $tmp -Value $payload -Encoding UTF8
  & qrencode -o m_qr.png -s 6 -m 0 -r $tmp | Out-Null
  Remove-Item $tmp -Force
  & $MagickPath m_qr.png -resize 180x180 m_qr.png
  & $MagickPath m_base.png m_qr.png -gravity Southwest -geometry "+$MARGIN+$MARGIN" -compose Over -composite m_base.png
}

# runde ecken + rand
& $MagickPath -size "${WIDTH}x${HEIGHT}" xc:none -fill white -draw "roundrectangle 2,2,$($WIDTH-3),$($HEIGHT-3),24,24" m_mask.png
& $MagickPath m_base.png m_mask.png -compose CopyOpacity -composite m_rounded.png
& $MagickPath m_rounded.png -stroke "#DDDDDD" -strokewidth 2 -fill none -draw "roundrectangle 2,2,$($WIDTH-3),$($HEIGHT-3),24,24" "$Out"

# cleanup
Remove-Item m_base.png,m_photo.png,m_qr.png,m_mask.png,m_ptmp.png,m_pmask.png,m_rounded.png -ErrorAction SilentlyContinue
Write-Host "fertig -> $Out"


