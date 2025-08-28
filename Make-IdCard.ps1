Param()

$MagickPath = "C:\Program Files (x86)\ImageMagick-7.1.2-Q16-HDRI\magick.exe"

function Require-File($path, $what) {
  if (-not (Test-Path $path)) {
    Write-Error "Fehlt: $what ($path)."
    exit 1
  }
}
Require-File $MagickPath "ImageMagick (magick.exe)"

$MagickDir = Split-Path $MagickPath -Parent
$env:MAGICK_HOME = $MagickDir
$env:MAGICK_CODER_MODULE_PATH = Join-Path $MagickDir "modules\coders"
$env:MAGICK_CONFIGURE_PATH    = $MagickDir
if ($env:Path -notlike "*$MagickDir*") { $env:Path += ";$MagickDir" }

& $MagickPath -size 10x10 xc:#FFFFFF _probe.png 2>$null
if (-not (Test-Path "_probe.png")) {
  Write-Error "ImageMagick funktioniert nicht korrekt."
  exit 1
}
Remove-Item _probe.png -ErrorAction SilentlyContinue

$FullName = Read-Host "Vollstaendiger Name"
$Role     = Read-Host "Rolle/Funktion"
$CardId   = Read-Host "Mitarbeiter- oder Schueler-ID"
$Valid    = Read-Host "Gueltig bis (z.B. 09/2026)"
$Photo    = Read-Host "Foto-Pfad (leer lassen fuer kein Foto)"
$Out      = Read-Host "Ausgabedatei (z.B. idcard.png)"
if ([string]::IsNullOrWhiteSpace($Out)) { $Out = "idcard.png" }

$WIDTH=1011; $HEIGHT=638; $HEADER=140; $MARGIN=60
$ACCENT="#0F766E"; $TEXT="#111111"; $SUBT="#444444"; $BG="#FFFFFF"
$Y_Name   = $HEADER + 40
$Y_Role   = $HEADER + 88
$Y_Id     = $HEADER + 140
$Y_Valid  = $HEADER + 180
$PhotoSize = 340
$PhotoX = $WIDTH - $PhotoSize - $MARGIN
$PhotoY = $HEADER + 30

& $MagickPath -size "${WIDTH}x${HEIGHT}" "xc:$BG" m_base.png
& $MagickPath m_base.png -fill $ACCENT -draw "rectangle 0,0 $WIDTH,$HEADER" m_base.png
& $MagickPath m_base.png `
  -fill white -gravity Northwest -pointsize 44 -annotate +$MARGIN+48 "ORGANIZATION" `
  -fill $TEXT  -gravity Northwest -pointsize 38 -annotate +$MARGIN+$Y_Name  "$FullName" `
  -fill $SUBT  -gravity Northwest -pointsize 28 -annotate +$MARGIN+$Y_Role  "$Role" `
  -fill $SUBT  -gravity Northwest -pointsize 26 -annotate +$MARGIN+$Y_Id    "ID: $CardId" `
  -fill $SUBT  -gravity Northwest -pointsize 26 -annotate +$MARGIN+$Y_Valid "Gueltig bis: $Valid" `
  m_base.png

if (-not [string]::IsNullOrWhiteSpace($Photo) -and (Test-Path $Photo)) {
  & $MagickPath -size "${PhotoSize}x${PhotoSize}" xc:none -fill white -draw "circle 170,170 170,0" m_pmask.png
  & $MagickPath "$Photo" -auto-orient -resize ${PhotoSize}x${PhotoSize}^ -gravity center -extent ${PhotoSize}x${PhotoSize} m_ptmp.png
  & $MagickPath m_ptmp.png m_pmask.png -compose DstIn -composite m_photo.png
  & $MagickPath m_base.png m_photo.png -gravity Northwest -geometry "+$PhotoX+$PhotoY" -compose Over -composite m_base.png
}

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

& $MagickPath -size "${WIDTH}x${HEIGHT}" xc:none -fill white -draw "roundrectangle 2,2,$($WIDTH-3),$($HEIGHT-3),24,24" m_mask.png
& $MagickPath m_base.png m_mask.png -compose CopyOpacity -composite m_rounded.png
& $MagickPath m_rounded.png -stroke "#DDDDDD" -strokewidth 2 -fill none -draw "roundrectangle 2,2,$($WIDTH-3),$($HEIGHT-3),24,24" "$Out"

Remove-Item m_base.png,m_photo.png,m_qr.png,m_mask.png,m_ptmp.png,m_pmask.png,m_rounded.png -ErrorAction SilentlyContinue
Write-Host "Fertig: $Out"