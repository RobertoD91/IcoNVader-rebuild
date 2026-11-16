# Salvaschermi macOS

Archivio di vecchi salvaschermi per Mac e restauro di uno di questi, **IcoNVader**, a partire dal
solo binario compilato.

| Salvaschermo | Autore | Versione | Funziona sui Mac di oggi? |
|---|---|---|---|
| `IcoNVader.saver` | Daedale (2004-2006) | 3.0 | No: solo PowerPC e Intel a 32 bit. **Restaurato**, vedi sotto |
| [`LotsaSnow.saver`](https://wakaba.c3.cx/s/lotsablankers/lotsasnow.html) | Dag Ågren | 1.6 | Solo Intel (x86_64) |
| [`LotsaWater.saver`](https://wakaba.c3.cx/s/lotsablankers/lotsawater.html) | Dag Ågren | 1.8 | Solo Intel (x86_64) |

I bundle originali sono conservati così come sono stati distribuiti e non vengono modificati.
LotsaSnow e LotsaWater hanno ancora una pagina ufficiale sul sito dell'autore:
[LotsaSnow](https://wakaba.c3.cx/s/lotsablankers/lotsasnow.html) e
[LotsaWater](https://wakaba.c3.cx/s/lotsablankers/lotsawater.html).

## IcoNVader restaurato

IcoNVader riempie lo schermo di icone animate in sei modi diversi: **Comets**, **Fireworks**,
**Game Of Life**, **Hypnosis**, **DNA** e **Jumpers**. L'originale non si carica più da macOS 10.15
(Catalina) in poi, perché contiene solo codice a 32 bit, e i sorgenti non sono mai stati pubblicati.

Il comportamento è stato ricavato leggendo il disassemblato del binario (costanti, formule, casi
limite e anche i piccoli difetti dell'originale) e riscritto due volte:

- **versione web** (`web/iconvader/`), in JavaScript con Canvas 2D;
- **salvaschermo per macOS moderni** (`macos/`), in Swift, universale per Apple Silicon e Intel,
  da macOS 11 in poi.

Le due versioni producono **esattamente** la stessa animazione: con lo stesso generatore casuale
danno le stesse posizioni, rotazioni, scale e opacità fotogramma per fotogramma
(`macos/Tests/compare.sh`).

### Versione web

Pubblicata su GitHub Pages: **https://robertodisanto.it/salvaschermi-macos/**
(anche `robertod91.github.io/salvaschermi-macos/`, che reindirizza lì). Il workflow
**Pubblica su Pages** la aggiorna a ogni push su `main` che modifica `web/`.

Si può anche aprire in locale `web/iconvader/index.html`: non servono server né installazioni.

| Tasto | Azione |
|---|---|
| **P** | apre il pannello opzioni |
| **F** | schermo intero |
| **Spazio** o **N** | riavvia l'animazione (con "Casuale" ne sceglie una nuova) |

Per aprire direttamente un comportamento: `?behavior=DNA&icons=Daedale`
(comportamenti: `Comets`, `Fireworks`, `GameOfLife`, `Hypnosis`, `DNA`, `Jumpers`;
set di icone: `Christmas`, `Daedale`).

### Salvaschermo per macOS

**Scaricarlo.** Il salvaschermo si compila con GitHub Actions:

1. vai su **Actions → Compila salvaschermo macOS → Run workflow**;
2. a fine esecuzione scarica l'artefatto **IcoNVader-saver** (contiene `IcoNVader-saver.zip`).

Spuntando **release** (e indicando un **tag**, per esempio `v3.0.1`) lo zip viene pubblicato anche
come release GitHub. L'artefatto **screenshot** contiene un'immagine di ogni comportamento generata
durante il collaudo.

**Installarlo.** Il bundle ha una firma ad-hoc e non è notarizzato, quindi macOS lo blocca al primo
avvio. Dopo aver estratto lo zip:

```bash
xattr -dr com.apple.quarantine ~/Downloads/IcoNVader.saver
```

```bash
open ~/Downloads/IcoNVader.saver
```

Il doppio clic (o `open`) lo installa per l'utente corrente in `~/Library/Screen Savers/`.
Poi si sceglie in **Impostazioni di Sistema → Salvaschermo**; il pulsante **Opzioni** apre lo stesso
pannello dell'originale (comportamento, cambio casuale, aspettativa di vita, livello d'invasione,
velocità, set di icone, dimensione, colore di sfondo).

**Set di icone personalizzati.** Come nell'originale, basta creare una cartella con file `.icns` o
`.png` in `~/Library/Application Support/IcoNVader/Icon Sets/<Nome del set>/`: comparirà nel menu
**Icone** del pannello.

**Compilarlo in locale** (serve Xcode):

```bash
brew install xcodegen
```

```bash
cd macos && xcodegen generate && open IcoNVader.xcodeproj
```

## Struttura del repository

```
IcoNVader.saver/ LotsaSnow.saver/ LotsaWater.saver/   bundle originali (non modificati)
docs/iconvader/                  reverse engineering: architettura, preferenze, metodo
docs/iconvader/comportamenti/    pseudocodice dettagliato di ogni comportamento (in inglese)
web/iconvader/                   versione web
macos/Sources/Core/              nucleo Swift (solo Foundation, compilabile anche su Linux)
macos/Sources/Saver/             vista ScreenSaver, disegno e pannello opzioni (AppKit)
macos/Tests/                     confronto Swift/JS e collaudo del bundle compilato
tools/                           disassemblato annotato e conversione delle icone
.github/workflows/               compilazione macOS (manuale) e pubblicazione su Pages
```

## Per approfondire

[`docs/iconvader/README.md`](docs/iconvader/README.md) racconta come è stato fatto il reverse
engineering: il formato del binario, come rendere leggibile il disassemblato, l'architettura
dell'originale, le opzioni e le stranezze mantenute di proposito.

```bash
tools/reversing/disassembla.sh     # disassemblato annotato in build/reversing/ (serve llvm-objdump)
```

```bash
macos/Tests/compare.sh             # confronto tra Swift e JavaScript (servono swiftc e node)
```

## Note legali

IcoNVader 3.0 è © 2004-2006 Daedale. Questo è un progetto didattico di conservazione di un software
non più distribuito né mantenuto; le icone incluse sono quelle del pacchetto originale.
LotsaSnow e LotsaWater sono © Dag Ågren ([pagina di LotsaSnow](https://wakaba.c3.cx/s/lotsablankers/lotsasnow.html),
[pagina di LotsaWater](https://wakaba.c3.cx/s/lotsablankers/lotsawater.html)).
