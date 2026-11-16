# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Lingua e branch

- Comunica con l'utente in **italiano**.
- Lavora direttamente sul branch `main`.

## Natura del repository

Questo repository **non contiene codice sorgente** né un sistema di build: è un archivio di salvaschermi macOS di terze parti già compilati (bundle `.saver`), conservati così come sono stati distribuiti. Non esistono comandi di build, lint o test.

| Bundle | Autore / ID | Versione | Architetture binario | Classe principale |
|---|---|---|---|---|
| `IcoNVader.saver` | Daedale (`com.daedale.IcoNVader`) | 3.0 | ppc + i386 | `IVScreenView` |
| `LotsaSnow.saver` | Dag Ågren (`cx.c3.lotsasnow`) | 1.6 | x86_64 + i386 | `LSLotsaSnowView` |
| `LotsaWater.saver` | Dag Ågren (`cx.c3.lotsawater`) | 1.8 | x86_64 + i386 | `LWLotsaWaterView` |

Nessun binario include `arm64`; `IcoNVader` non ha una slice a 64 bit, quindi non può essere caricato da macOS 10.15 (Catalina) in poi, che non supporta più il codice a 32 bit.

## Struttura di un bundle `.saver`

Ogni bundle segue il layout standard dei bundle macOS (`CFBundlePackageType` = `BNDL`):

- `Contents/Info.plist` — metadati; `NSPrincipalClass` indica la sottoclasse di `ScreenSaverView` che il sistema istanzia.
- `Contents/MacOS/<Nome>` — binario Mach-O universale (non modificabile in modo significativo senza i sorgenti).
- `Contents/Resources/<Lingua>.lproj/` — localizzazioni (IcoNVader: English/French; LotsaSnow e LotsaWater: English/Japanese) e il pannello delle opzioni (`IVPreferences.nib` / `ConfigSheet.nib`).
- IcoNVader ha inoltre `DefaultPreferences.plist` (valori predefiniti delle opzioni) e `Resources/Icon Sets/<Set>/*.icns`: aggiungere una sottocartella con file `.icns` crea un nuovo set di icone.

## Avvertenze per la modifica dei file

- **Codifiche diverse**: gli `InfoPlist.strings` di LotsaSnow/LotsaWater sono UTF-16 LE; quelli di IcoNVader sono ASCII/UTF-8. Mantieni la codifica originale quando li modifichi.
- **Nib compilati**: i `ConfigSheet.nib` di LotsaSnow/LotsaWater sono plist binari compilati, e `objects.nib` di IcoNVader è un typedstream NeXT; non sono modificabili come testo.
- **Firma del codice**: `LotsaWater.saver` contiene `Contents/_CodeSignature/CodeResources` con gli hash delle risorse; modificare qualsiasi file del bundle invalida la firma (andrebbe rifirmato su macOS, ad es. con `codesign --force --deep -s - LotsaWater.saver`). LotsaSnow e IcoNVader non sono firmati.
- Strumenti macOS come `plutil`, `codesign`, `lipo` e `otool` non sono disponibili in un ambiente Linux; usa `file` o `python3` (modulo `plistlib`) per ispezionare plist e binari.

## Installazione (su macOS)

Copia il bundle `.saver` in `~/Library/Screen Savers/` (solo per l'utente) o in `/Library/Screen Savers/` (per tutti gli utenti), oppure fai doppio clic sul bundle.
