# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Lingua e branch

- Comunica con l'utente in **italiano**.
- Lavora direttamente sul branch `main`.

## Natura del repository

Il repository è dedicato solo a IcoNVader e contiene due cose:

1. **Il bundle originale** `IcoNVader.saver`, conservato così come era distribuito e senza sorgenti. Non va modificato.
2. **Il restauro** (esperimento didattico di reverse engineering): il comportamento del binario è stato ricostruito e reimplementato due volte.
   - `docs/iconvader/README.md`: architettura dell'originale, preferenze, metodo, differenze e stranezze mantenute. `docs/iconvader/comportamenti/*.md` contiene lo pseudocodice dettagliato di ogni comportamento (in inglese).
   - `web/iconvader/`: ricostruzione in JavaScript puro (Canvas 2D, script classici, nessuna dipendenza), pubblicata su GitHub Pages (https://robertodisanto.it/IcoNVader-rebuild/).
   - `macos/`: salvaschermo per macOS 11+ in Swift, universale arm64 + x86_64. `Sources/Core` è il porting dei comportamenti (solo Foundation), `Sources/Saver` la vista `ScreenSaverView`, il disegno e il pannello opzioni (AppKit). Il progetto Xcode si genera con XcodeGen da `project.yml` e non è versionato.
   - `tools/`: script per rigenerare il disassemblato annotato e le icone PNG.

Il `README.md` alla radice è la presentazione per gli utenti (download, installazione, uso), in inglese; `README.it.md` è la stessa in italiano: vanno tenuti allineati. Il codice della ricostruzione è sotto licenza MIT (`LICENSE`), che esclude esplicitamente il materiale di Daedale (bundle, binario, icone e loro conversioni).

## Comandi

```bash
tools/reversing/disassembla.sh        # disassemblato annotato della slice i386 in build/reversing/ (richiede llvm-objdump)
python3 tools/converti_icone.py       # rigenera web/iconvader/icons/*/*.png dai .icns (richiede Pillow)
macos/Tests/compare.sh [fotogrammi]   # confronta nucleo Swift e versione web con seme fisso (richiede swiftc e node)
cd macos && xcodegen generate         # genera IcoNVader.xcodeproj (solo macOS)
```

Per un singolo caso: `swiftc -o /tmp/t macos/Sources/Core/*.swift macos/Tests/main.swift && /tmp/t DNA 600 1` e `node macos/Tests/reference.js DNA 600 1` devono stampare righe identiche.

## Traduzioni e pannello opzioni

- Tutti i testi dell'interfaccia stanno in `i18n/stringhe.json` (inglese e francese sono quelli originali del bundle, più l'italiano). `python3 tools/genera_traduzioni.py` genera `macos/Resources/<lingua>.lproj/Localizable.strings` e `web/iconvader/js/i18n.js`: non modificare a mano i file generati. Il workflow macOS fallisce se non sono aggiornati (`--verifica`).
- Il pannello macOS (`ConfigureSheet.swift`) replica `IVPreferences.nib`: le coordinate dei controlli vengono dai nib `English.lproj` e `French.lproj` (decodificati con il pacchetto Python `pytypedstream`: `python -m typedstream decode objects.nib`); l'italiano usa la disposizione francese. La lingua segue il sistema; per i collaudi si forza con la variabile d'ambiente `ICONVADER_LANG`.
- Sul web la lingua è nelle preferenze (`language`: `auto`, `en`, `fr`, `it`) e si può passare con `?lang=`.

## Doppia implementazione: regola fondamentale

La versione web (`web/iconvader/js/behaviors/*.js`) e il nucleo Swift (`macos/Sources/Core/*.swift`) sono traduzioni riga per riga l'una dell'altra e **devono restare identiche**: stesso ordine delle chiamate a `random()`, stesse formule, stessi arrotondamenti (`Math.fround` ↔ `Float`). Ogni modifica a un comportamento va fatta in entrambi i linguaggi e verificata con `macos/Tests/compare.sh`, che fallisce alla prima differenza.

Nell'ambiente cloud non c'è Swift preinstallato: la toolchain per Linux si scarica da download.swift.org (Ubuntu 24.04) per compilare il nucleo; la parte AppKit si compila solo su macOS.

## GitHub Actions

- `build-macos.yml` (avvio **manuale**): `compare.sh`, XcodeGen, `xcodebuild` universale con firma ad-hoc, verifica del bundle e `macos/Tests/render.swift`, che carica il `.saver` come fa il sistema, anima ogni comportamento e salva gli screenshot (artefatto `screenshot`). Produce l'artefatto `IcoNVader-saver` e, se richiesto, una release.
- Firma: se ci sono i secret `MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD` (firma Developer ID) e `APP_STORE_CONNECT_API_KEY_BASE64`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID` (notarizzazione con `notarytool` e staple), `build-macos.yml` firma e notarizza il bundle; altrimenti resta la firma ad-hoc. Istruzioni in `docs/firma-macos.md`.
- `pages.yml`: pubblica `web/iconvader` su Pages a ogni push su `main` che tocca `web/`, oppure a mano.

La pagina web si apre direttamente da file (`web/iconvader/index.html`); parametri utili per provare un singolo comportamento: `?behavior=DNA&icons=Daedale`. Nell'ambiente cloud la verifica visiva si fa con Playwright (già installato) caricando l'URL `file://`.

## Ricostruzione web di IcoNVader

- `js/core.js` riproduce le classi di base dell'originale: `Actor` (`IVActor`), `Behavior` (`IVBehavior`), `Renderer` (`QuartzRenderer`), `ScreenSaver` (`IVScreenView`) e le preferenze (`IVPreferences`). Ogni file in `js/behaviors/` corrisponde a una classe `*Behavior` del binario e si registra con `IcoNVader.registerBehavior`. L'ordine dei tag `<script>` in `index.html` determina l'ordine della lista, che replica quello originale (Comets, Fireworks, GameOfLife, Hypnosis, DNA, Jumpers).
- I comportamenti lavorano in **coordinate Cocoa** (origine in basso a sinistra, y verso l'alto, angoli in gradi antiorari): la conversione verso il canvas avviene solo in `Renderer.renderActors`.
- Velocità e durate sono **per fotogramma**, come nell'originale; il ciclo in `ScreenSaver._frame` esegue `animateOneFrame` a `animationSpeed` fotogrammi al secondo.
- L'ordine di disegno è l'ordine dell'array `actors`; i comportamenti che lo richiedono lo riordinano con `compareDepth`, che alcune classi ridefiniscono.
- Nomi di metodi e campi (`resetActor`, `moveActor`, `blowFactor`, `timeToLive`…) ricalcano quelli del binario per poter confrontare il codice con il disassemblato. Le stranezze dell'originale sono mantenute di proposito e documentate in `docs/iconvader/README.md`: non "correggerle" senza aggiornare la documentazione.
- Il disassemblato si legge per classe in `build/reversing/cls/<Classe>.s` insieme a `build/reversing/ivars.txt` (offset dei campi). I commenti `; @sel(...)`, `; f32=`, `; f64=` sono aggiunti da `tools/reversing/annota.py`, che risolve gli accessi PIC relativi a `%ebx`/`%ecx`.

## Il bundle originale

`IcoNVader.saver`: Daedale (`com.daedale.IcoNVader`), versione 3.0, classe principale `IVScreenView`, binario universale ppc + i386. Non ha una slice a 64 bit, quindi non può essere caricato da macOS 10.15 (Catalina) in poi, che non supporta più il codice a 32 bit.

Layout standard dei bundle macOS (`CFBundlePackageType` = `BNDL`):

- `Contents/Info.plist` — metadati; `NSPrincipalClass` indica la sottoclasse di `ScreenSaverView` che il sistema istanzia.
- `Contents/MacOS/<Nome>` — binario Mach-O universale (non modificabile in modo significativo senza i sorgenti).
- `Contents/Resources/<Lingua>.lproj/` — localizzazioni (English/French) e il pannello delle opzioni (`IVPreferences.nib`).
- `Contents/Resources/DefaultPreferences.plist` (valori predefiniti delle opzioni) e `Resources/Icon Sets/<Set>/*.icns`: aggiungere una sottocartella con file `.icns` crea un nuovo set di icone.

### Avvertenze

- `objects.nib` di `IVPreferences.nib` è un typedstream NeXT, non modificabile come testo; le stringhe localizzate sono ASCII/UTF-8.
- Strumenti macOS come `plutil`, `codesign`, `lipo` e `otool` non sono disponibili in un ambiente Linux; usa `file` o `python3` (modulo `plistlib`) per ispezionare plist e binari.
