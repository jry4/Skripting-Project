# Skripting-Project

# ID Card Generator (PowerShell + ImageMagick)

Dieses Projekt erstellt automatisch eine kleine ID-Karte (PNG/JPEG) auf Basis von Benutzereingaben.  
Es nutzt **PowerShell** und **ImageMagick**.

## Voraussetzungen

- Windows mit PowerShell
- [ImageMagick 7](https://imagemagick.org) installiert  
  (z. B. in `C:\Program Files (x86)\ImageMagick-7.1.2-Q16-HDRI\magick.exe`)

## Installation

1. Dieses Repository klonen oder herunterladen.
2. Pfad zu `magick.exe` im Skript **Make-IdCard.ps1** ggf. anpassen:
   ```powershell
   $MagickPath = "C:\Program Files (x86)\ImageMagick-7.1.2-Q16-HDRI\magick.exe"
