# make-idcard.ps1
Param()

# -- pfad zu imagemagick (bitte anpassen, so lauft es bei mir) --
$MagickPath = "C:\Program Files (x86)\ImageMagick-7.1.2-Q16-HDRI\magick.exe"

# simple check
if (-not (Test-Path $MagickPath)) {
  Write-Host "magick.exe nicht gefunden -> $MagickPath"
  exit 1
}

# env so setzen, dass module gefunden werden (bei mir sonst fehler)
$MagickDir = Split-Path $MagickPath -Parent
$env:MAGICK_HOME = $MagickDir
$env:MAGICK_CODER_MODULE_PATH = Join-Path $MagickDir "modules\coders"
$env:MAGICK_CONFIGURE_PATH    = $MagickDir
if ($env:Path -notlike "*$MagickDir*") { $env:Path += ";$MagickDir" }


& $MagickPath -size 8x8 xc:#FFFFFF _probe.png 2>$null
if (-not (Test-Path "_probe.png")) {
  Write-Host "ImageMagick mag 'xc:' nicht -> evtl. powershell neu starten oder install checken"
  exit 1
}
Remove-Item _probe.png -ErrorAction SilentlyContinue

# fixe ordner (so habe ich es bei mir)
$PhotoDir = "C:\Mac\Home\Documents\Scripting\Scripting Projekt\Bilder\"
$OutDir   = "C:\Mac\Home\Documents\Scripting\Scripting Projekt\"

# eingaben
$Org      = Read-Host "Organisation / Firma"
$FullName = Read-Host "Vollstaendiger Name"
$Role     = Read-Host "Rolle/Funktion"
$CardId   = Read-Host "Mitarbeiter- oder Schueler-ID"
$Valid    = Read-Host "Gueltig bis (z.B. 09/2026)"
$PhotoFile = Read-Host "Gib den Namen des Bildes aus dem Ordner $PhotoDir an (oder leer lassen)"
$FileName = Read-Host "Dateiname der Ausgabedatei (z.B. idcard.png)"

# defaults falls leer 
if ([string]::IsNullOrWhiteSpace($FileName)) { $FileName = "idcard.png" }
$Photo = if ([string]::IsNullOrWhiteSpace($PhotoFile)) { "" } else { Join-Path $PhotoDir $PhotoFile }
$Out   = Join-Path $OutDir $FileName

# layout 
$WIDTH=1011; $HEIGHT=638
$HEADER=140; $MARGIN=60
$ACCENT="#0F766E"; $TEXT="#111111"; $SUBT="#444444"; $BG="#FFFFFF"
$Y_Name = $HEADER + 40
$Y_Role = $HEADER + 88
$Y_Id   = $HEADER + 140
$Y_Val  = $HEADER + 180

# basis
& $MagickPath -size "${WIDTH}x${HEIGHT}" "xc:$BG" m_base.png
& $MagickPath m_base.png -fill $ACCENT -draw "rectangle 0,0 $WIDTH,$HEADER" m_base.png

# header + infos
& $MagickPath m_base.png `
  -fill white -gravity Northwest -pointsize 44 -annotate +$MARGIN+48 "$Org" `
  -fill $TEXT  -gravity Northwest -pointsize 38 -annotate +$MARGIN+$Y_Name "$FullName" `
  -fill $SUBT  -gravity Northwest -pointsize 28 -annotate +$MARGIN+$Y_Role "$Role" `
  -fill $SUBT  -gravity Northwest -pointsize 26 -annotate +$MARGIN+$Y_Id   "ID: $CardId" `
  -fill $SUBT  -gravity Northwest -pointsize 26 -annotate +$MARGIN+$Y_Val  "Gueltig bis: $Valid" `
  m_base.png

# foto (wenn angegeben) – runde maske, dann rechts oben drauf
if (-not [string]::IsNullOrWhiteSpace($Photo) -and (Test-Path $Photo)) {
  $PhotoSize = 340
  $PhotoX = $WIDTH - $PhotoSize - $MARGIN
  $PhotoY = $HEADER + 30

  & $MagickPath -size "${PhotoSize}x${PhotoSize}" xc:none -fill white -draw "circle 170,170 170,0" m_pmask.png
  & $MagickPath "$Photo" -auto-orient -resize ${PhotoSize}x${PhotoSize}^ -gravity center -extent ${PhotoSize}x${PhotoSize} m_ptmp.png
  & $MagickPath m_ptmp.png m_pmask.png -compose DstIn -composite m_photo.png
  & $MagickPath m_base.png m_photo.png -gravity Northwest -geometry "+$PhotoX+$PhotoY" -compose Over -composite m_base.png
} else {
  # kein foto -> ok, mache einfach weiter
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

# runde ecken + zarter rand (hacky aber ok)
& $MagickPath -size "${WIDTH}x${HEIGHT}" xc:none -fill white -draw "roundrectangle 2,2,$($WIDTH-3),$($HEIGHT-3),24,24" m_mask.png
& $MagickPath m_base.png m_mask.png -compose CopyOpacity -composite m_rounded.png
& $MagickPath m_rounded.png -stroke "#DDDDDD" -strokewidth 2 -fill none -draw "roundrectangle 2,2,$($WIDTH-3),$($HEIGHT-3),24,24" "$Out"

# cleanup (lasse bewusst ruhig wenn was fehlt)
Remove-Item m_base.png,m_photo.png,m_qr.png,m_mask.png,m_ptmp.png,m_pmask.png,m_rounded.png -ErrorAction SilentlyContinue

Write-Host "fertig -> $Out"

