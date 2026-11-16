# IcoNVader - rebuild

[English](README.md) · **Italiano**

Restauro del salvaschermo per Mac **IcoNVader 3.0** (Daedale, 2004-2006) a partire dal solo
binario compilato. Il bundle originale, `IcoNVader.saver`, è conservato così come era distribuito
e non viene modificato.

- **Provalo nel browser:** https://robertodisanto.it/IcoNVader-rebuild/
- **Scarica il salvaschermo per macOS:** [ultima release](https://github.com/RobertoD91/IcoNVader-rebuild/releases/latest)

> **Disclaimer.** Non sono l'autore di IcoNVader e non ho alcun legame con Daedale. IcoNVader 3.0,
> il suo nome, le icone e il binario originale appartengono ai rispettivi titolari dei diritti.
> Questo è un progetto amatoriale e senza scopo di lucro, fatto per nostalgia e a scopo didattico,
> per far rivivere un software che non è più distribuito e non funziona sui Mac di oggi. Se sei
> il titolare dei diritti e preferisci che il materiale non sia pubblicato, aprimi una issue e lo
> rimuovo.

## Perché questo progetto

Me lo ricordo da quando ero bambino: lo vedevo su un vecchio Mac di casa. Anni dopo l'ho
ritrovato, ma non si apre più: è stato scritto per i Mac PowerPC e Intel a 32 bit, che macOS non
supporta da tempo, e i sorgenti non sono mai stati pubblicati.

Così ho provato a ricostruirlo **con l'aiuto dell'intelligenza artificiale**: partendo dal solo
binario, l'IA mi ha aiutato a disassemblarlo, a capire classe per classe come funzionava ogni
animazione e a riscriverlo da zero, prima come pagina web e poi come salvaschermo per i Mac di oggi.
L'obiettivo era rivederlo esattamente come lo ricordavo, con le stesse formule, gli stessi tempi e
perfino i piccoli difetti dell'originale.

## Il progetto

IcoNVader riempie lo schermo di icone animate in sei modi diversi: **Comets**, **Fireworks**,
**Game Of Life**, **Hypnosis**, **DNA** e **Jumpers**. L'originale non si carica più da macOS 10.15
(Catalina) in poi, perché contiene solo codice a 32 bit.

Il comportamento è stato ricavato leggendo il disassemblato del binario (costanti, formule, casi
limite e anche i piccoli difetti dell'originale) e riscritto due volte:

- **versione web** (`web/iconvader/`), in JavaScript con Canvas 2D;
- **salvaschermo per macOS moderni** (`macos/`), in Swift, universale per Apple Silicon e Intel,
  da macOS 11 in poi.

Le due versioni producono **esattamente** la stessa animazione: con lo stesso generatore casuale
danno le stesse posizioni, rotazioni, scale e opacità fotogramma per fotogramma
(`macos/Tests/compare.sh`).

Anche il **pannello delle opzioni** è ricostruito dall'originale: le tre schede (Aspetto,
Animazione, Avanzate), la posizione dei controlli, gli intervalli e i valori predefiniti vengono
dal file dell'interfaccia contenuto nel bundle. Come l'originale è **in inglese e francese**, con i
testi di allora, e in più **in italiano**.

### Versione web

Pubblicata su GitHub Pages: **https://robertodisanto.it/IcoNVader-rebuild/**. Il workflow
**Pubblica su Pages** la aggiorna a ogni push su `main` che modifica `web/`.

Si può anche aprire in locale `web/iconvader/index.html`: non servono server né installazioni.

| Tasto | Azione |
|---|---|
| **P** | apre il pannello opzioni |
| **F** | schermo intero |
| **Spazio** o **N** | riavvia l'animazione (con "Casuale" ne sceglie una nuova) |

La lingua segue quella del browser e si può cambiare nella scheda **Avanzate**.
Parametri utili nell'indirizzo: `?behavior=DNA&icons=Daedale&lang=fr`
(comportamenti: `Comets`, `Fireworks`, `GameOfLife`, `Hypnosis`, `DNA`, `Jumpers`;
set di icone: `Christmas`, `Daedale`; lingue: `en`, `fr`, `it`).

### Salvaschermo per macOS

**Scaricarlo.** Dalla pagina delle [release](https://github.com/RobertoD91/IcoNVader-rebuild/releases/latest)
scarica [`IcoNVader-saver.zip`](https://github.com/RobertoD91/IcoNVader-rebuild/releases/latest/download/IcoNVader-saver.zip).

Per compilarne una nuova con GitHub Actions:

1. vai su **Actions → Compila salvaschermo macOS → Run workflow**;
2. a fine esecuzione scarica l'artefatto **IcoNVader-saver** (contiene `IcoNVader-saver.zip`).

Spuntando **release** (e indicando un **tag**, per esempio `v3.0.3`) lo zip viene pubblicato anche
come release GitHub. L'artefatto **screenshot** contiene un'immagine di ogni comportamento e di ogni
scheda del pannello, in tutte le lingue, generata durante il collaudo.

**Installarlo.** Il bundle ha una firma ad-hoc e non è notarizzato, quindi macOS lo blocca al primo
avvio. Dopo aver estratto lo zip:

```bash
xattr -dr com.apple.quarantine ~/Downloads/IcoNVader.saver
```

```bash
open ~/Downloads/IcoNVader.saver
```

Il doppio clic (o `open`) lo installa per l'utente corrente in `~/Library/Screen Savers/`.
Poi si sceglie in **Impostazioni di Sistema → Salvaschermo**; il pulsante **Opzioni** apre il
pannello, nella lingua del sistema.

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
IcoNVader.saver/                 bundle originale (non modificato)
docs/iconvader/                  reverse engineering: architettura, preferenze, metodo
docs/iconvader/comportamenti/    pseudocodice dettagliato di ogni comportamento (in inglese)
i18n/stringhe.json               testi in inglese, francese e italiano (sorgente unica)
web/iconvader/                   versione web
macos/Sources/Core/              nucleo Swift (solo Foundation, compilabile anche su Linux)
macos/Sources/Saver/             vista ScreenSaver, disegno e pannello opzioni (AppKit)
macos/Resources/                 traduzioni per macOS (generate)
macos/Tests/                     confronto Swift/JS e collaudo del bundle compilato
tools/                           disassemblato annotato, icone e traduzioni
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

```bash
python3 tools/genera_traduzioni.py # rigenera le traduzioni da i18n/stringhe.json
```

## Note legali

IcoNVader 3.0 è © 2004-2006 Daedale. Questo repository non è affiliato a Daedale né da essa
approvato. È un progetto didattico di conservazione di un software non più distribuito né
mantenuto: il binario e le icone incluse sono quelli del pacchetto originale e restano di
proprietà dei rispettivi titolari. Il codice della ricostruzione (versione web, salvaschermo per
macOS e strumenti) è scritto da zero e non contiene codice dell'originale.

## Licenza

Il codice e la documentazione della ricostruzione sono distribuiti con licenza **MIT**
(vedi [`LICENSE`](LICENSE)). La licenza **non** si applica al materiale originale di Daedale: il
bundle `IcoNVader.saver`, il binario, le icone e le immagini, comprese le loro copie e conversioni
(`web/iconvader/icons/` e le icone incluse nel salvaschermo compilato).
