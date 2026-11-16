# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Lingua e branch

- Comunica con l'utente in **italiano**.
- Lavora direttamente sul branch `main`.

## Natura del repository

Il repository contiene due cose:

1. **Archivio** di salvaschermi macOS di terze parti già compilati (bundle `.saver`), conservati così come sono stati distribuiti e senza sorgenti. Non vanno modificati.
2. **Restauro di IcoNVader** (esperimento didattico di reverse engineering): il comportamento del binario è stato ricostruito e reimplementato come pagina web.
   - `docs/iconvader/README.md`: architettura dell'originale, preferenze, metodo, differenze e stranezze mantenute. `docs/iconvader/comportamenti/*.md` contiene lo pseudocodice dettagliato di ogni comportamento (in inglese).
   - `web/iconvader/`: ricostruzione in JavaScript puro (Canvas 2D, script classici, nessuna dipendenza).
   - `tools/`: script per rigenerare il disassemblato annotato e le icone PNG.

Non esistono sistemi di build, lint o test automatici.

## Comandi

```bash
tools/reversing/disassembla.sh        # disassemblato annotato della slice i386 in build/reversing/ (richiede llvm-objdump)
python3 tools/converti_icone.py       # rigenera web/iconvader/icons/*/*.png dai .icns (richiede Pillow)
```

La pagina web si apre direttamente da file (`web/iconvader/index.html`); parametri utili per provare un singolo comportamento: `?behavior=DNA&icons=Daedale`. Nell'ambiente cloud la verifica visiva si fa con Playwright (già installato) caricando l'URL `file://`.

## Ricostruzione web di IcoNVader

- `js/core.js` riproduce le classi di base dell'originale: `Actor` (`IVActor`), `Behavior` (`IVBehavior`), `Renderer` (`QuartzRenderer`), `ScreenSaver` (`IVScreenView`) e le preferenze (`IVPreferences`). Ogni file in `js/behaviors/` corrisponde a una classe `*Behavior` del binario e si registra con `IcoNVader.registerBehavior`. L'ordine dei tag `<script>` in `index.html` determina l'ordine della lista, che replica quello originale (Comets, Fireworks, GameOfLife, Hypnosis, DNA, Jumpers).
- I comportamenti lavorano in **coordinate Cocoa** (origine in basso a sinistra, y verso l'alto, angoli in gradi antiorari): la conversione verso il canvas avviene solo in `Renderer.renderActors`.
- Velocità e durate sono **per fotogramma**, come nell'originale; il ciclo in `ScreenSaver._frame` esegue `animateOneFrame` a `animationSpeed` fotogrammi al secondo.
- L'ordine di disegno è l'ordine dell'array `actors`; i comportamenti che lo richiedono lo riordinano con `compareDepth`, che alcune classi ridefiniscono.
- Nomi di metodi e campi (`resetActor`, `moveActor`, `blowFactor`, `timeToLive`…) ricalcano quelli del binario per poter confrontare il codice con il disassemblato. Le stranezze dell'originale sono mantenute di proposito e documentate in `docs/iconvader/README.md`: non "correggerle" senza aggiornare la documentazione.
- Il disassemblato si legge per classe in `build/reversing/cls/<Classe>.s` insieme a `build/reversing/ivars.txt` (offset dei campi). I commenti `; @sel(...)`, `; f32=`, `; f64=` sono aggiunti da `tools/reversing/annota.py`, che risolve gli accessi PIC relativi a `%ebx`/`%ecx`.

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
