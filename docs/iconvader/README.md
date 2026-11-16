# IcoNVader 3.0 — reverse engineering e ricostruzione

Esperimento didattico di reversing e restauro di un software abandonware: il salvaschermo
**IcoNVader 3.0** (Daedale, 2004-2006, `com.daedale.IcoNVader`). L'originale non funziona più sui
Mac recenti: il binario contiene solo codice PowerPC e i386 a 32 bit, che macOS non carica più
da Catalina (10.15) in poi. Qui il comportamento è stato ricostruito dal binario e reimplementato
come pagina web (`web/iconvader/`).

## 1. Il binario

| | |
|---|---|
| File | `IcoNVader.saver/Contents/MacOS/IcoNVader` |
| Formato | Mach-O universale: `ppc` (offset 0x1000) + `i386` (offset 0x1A000) |
| Linguaggio | Objective-C 1 (runtime "legacy"), codice PIC |
| Classe principale | `IVScreenView` (sottoclasse di `ScreenSaverView`) |
| Simboli | **presenti**: tutti i nomi di classi, metodi e ivar sono leggibili |

La presenza dei simboli rende il lavoro molto più semplice: per ogni metodo si conosce il nome
(`-[DNAHelix moveInsideBounds:]`) e, dai metadati Objective-C, il layout esatto degli ivar.
L'analisi è stata fatta sulla slice **i386**: x86 è più semplice da leggere di PowerPC, e le
costanti in virgola mobile stanno in sezioni separate (`__literal4`, `__literal8`).

### Metodo e strumenti

```bash
tools/reversing/disassembla.sh            # output in build/reversing/
```

Lo script estrae la slice i386 dall'intestazione fat e usa `llvm-objdump` per produrre i metadati
Objective-C, l'elenco delle sezioni e il disassemblato. Poi `tools/reversing/annota.py` risolve i
riferimenti PIC.

Il codice i386 di Mac OS X accede ai dati in modo relativo al program counter:
`call ___i686.get_pc_thunk.bx` carica in `%ebx` l'indirizzo dell'istruzione successiva, e ogni
accesso del tipo `0x4990(%ebx)` punta a un selettore, a una classe, a una costante o a una stringa.
L'annotatore tiene traccia del valore di `%ebx`/`%ecx` in ogni funzione e aggiunge un commento
leggibile:

```
movl  0x4990(%ebx), %eax    ; @sel(waveAction)
mulsd 0x34e0(%ebx), %xmm0   ; f64=3.141592653589793
divsd 0x34e8(%ebx), %xmm0   ; f64=180.0
```

Il risultato viene infine diviso per classe (`build/reversing/cls/<Classe>.s`) e affiancato al file
`ivars.txt` con gli offset dei campi. Con questi due file ogni metodo si traduce quasi riga per riga
in pseudocodice.

Le opzioni del pannello (limiti degli slider, voci dei menu) sono state lette dal nib
`IVPreferences.nib/objects.nib`, che è in formato *typedstream* NeXT, e confermate dai controlli di
validità presenti in `IVPreferences`.

## 2. Architettura dell'originale

```
IVScreenView (ScreenSaverView)
 ├─ IVPreferences      ← NSUserDefaults del dominio com.daedale.IcoNVader + DefaultPreferences.plist
 ├─ IVBehavior         ← uno dei 6 comportamenti: muove gli attori a ogni fotogramma
 │    └─ [IVActor]     ← location, angle, scale, opacity, image
 └─ IVRenderer         ← QuartzRenderer o OpenGLRenderer: disegna gli attori
```

**Ciclo di vita** (`-[IVScreenView startAnimation]`):
1. Se `RandomBehavior` è attivo, sceglie un comportamento a caso (`random() % count`) e programma un
   `NSTimer` che dopo `RandomBehaviorChangeInterval` secondi richiama `startAnimation`.
2. Imposta l'intervallo di animazione a `1 / AnimationSpeed` secondi.
3. Carica tutti i file `.icns` del set di icone scelto.
4. Crea il comportamento con `initWithBounds:icons:density:lifeExpectancy:scaleFactor:` e il renderer
   con il colore di sfondo.

**A ogni fotogramma** (`animateOneFrame`) il comportamento aggiorna gli attori e il renderer li disegna
nell'ordine dell'array: quelli disegnati per ultimi stanno sopra. Molti comportamenti riordinano
l'array con `compareDepth:`, che di base mette prima gli attori più opachi.

**Rendering di un attore** (identico in Quartz e OpenGL): trasla in `location`, ruota di `angle`
gradi (in senso antiorario), trasla di `−dimensione·scale/2`, scala di `scale` e disegna l'immagine
128×128 con opacità `opacity`. Le coordinate sono quelle di Cocoa: origine in basso a sinistra,
y verso l'alto.

**Una caratteristica comune**: tutte le velocità e le durate sono espresse **in fotogrammi**, non in
secondi. Cambiare `AnimationSpeed` accelera o rallenta l'intera animazione.

### Preferenze

| Chiave | Pannello | Intervallo | Predefinito | Uso |
|---|---|---|---|---|
| `AnimationSpeed` | Speed (Slow–Fast) | 10–60 | 30 | fotogrammi al secondo |
| `Density` | Invasion Level (Scattered Remains–Rampant) | 0–100 | 50 | numero di icone o frequenza degli eventi |
| `LifeExpectancy` | Life expectancy (Born Dead–Ancient) | 100–5000 | 1200 | durata della vita, in fotogrammi |
| `ScaleFactor` | Icons size (Small–Large) | 0.1–1.0 | 0.6 | scala delle icone 128×128 |
| `RandomBehavior` | voce "Random" del menu | sì/no | sì | comportamento casuale |
| `RandomBehaviorChangeInterval` | Random behavior every | 10 s, 1 min, 5, 10, 30 min, 1 h, mai | 300 | secondi |
| `Behavior` | Icons Behavior | identificatore | primo della lista | comportamento fisso |
| `IconSetName` | Icons | nome cartella | `Christmas` | set di icone |
| `ShadingColor` | Background color | colore | nero | sfondo |
| `Renderer` | Render through | `Quartz` / `OpenGL` | primo della lista | motore di disegno |

I set di icone vengono cercati nelle risorse del bundle (`Icon Sets/`), in
`/Library/Application Support/IcoNVader/Icon Sets/` e in
`~/Library/Application Support/IcoNVader/Icon Sets/` (`FSFindFolder` con `kLocalDomain` e
`kUserDomain`, tipo `'asup'`): ogni set è una cartella di file `.icns`.

## 3. I sei comportamenti

L'ordine è quello della lista originale. Le note tecniche complete (in inglese), con pseudocodice,
costanti e casi limite, sono in [`comportamenti/`](comportamenti/). I percorsi `cls/<Classe>.s`
citati nelle note si riferiscono all'output di `tools/reversing/disassembla.sh`.

| Comportamento | Cosa si vede | Usa |
|---|---|---|
| [Comets](comportamenti/Comets.md) | Le icone entrano dai bordi in linea retta (3–12 px/fotogramma), rimpiccioliscono e svaniscono, poi rinascono da un bordo a caso. | densità, vita, scala |
| [Fireworks](comportamenti/Fireworks.md) | Razzi lanciati dal fondo che rallentano per gravità, si gonfiano in cima e scoppiano in 8 copie nelle direzioni della rosa dei venti. | densità (frequenza), vita (scintille), scala |
| [Game Of Life](comportamenti/GameOfLife.md) | Gioco della vita di Conway (B3/S23, bordi morti) su una griglia di icone, con nascite e morti animate. Ricomincia quando si blocca o ripete uno degli ultimi 10 stati. | densità (riempimento), vita (tempi), scala (celle) |
| [Hypnosis](comportamenti/Hypnosis.md) | Anelli concentrici di icone con la cima verso l'esterno, che ruotano in direzioni alterne e più velocemente verso l'esterno. | solo le dimensioni dello schermo |
| [DNA](comportamenti/DNA.md) | Doppie eliche verticali di icone (20 gradini, 30° di torsione) che ruotano sul proprio asse e scorrono in alto e in basso. Le icone più vicine sono più grandi. | scala |
| [Jumpers](comportamenti/Jumpers.md) | Le icone compaiono, rimbalzano sul fondo senza perdere energia (a volte con una capriola), poi esplodono ingrandendosi e rinascono altrove. | densità, vita, scala |

Le "figure che ruotano lungo una serie di vie" corrispondono a **DNA** (eliche rotanti che scorrono)
e, in parte, a **Hypnosis** (anelli rotanti).

Per Comets e Jumpers il numero di icone è `⌊larghezza/128 · (densità+3)/10⌋`: 59 a 1440 px con i
valori predefiniti.

## 4. La ricostruzione web

```
web/iconvader/
├─ index.html            pagina a schermo intero + pannello opzioni
├─ icons/<Set>/*.png      icone convertite da .icns (tools/converti_icone.py)
└─ js/
   ├─ core.js            Actor, Behavior, Renderer (Canvas 2D), ScreenSaver, preferenze
   ├─ app.js             pannello opzioni, tastiera, parametri URL
   └─ behaviors/*.js     un file per comportamento
```

Si apre direttamente `web/iconvader/index.html` nel browser: script classici, nessuna build e nessun
server necessari. Comandi: **P** apre le opzioni, **F** attiva lo schermo intero, **Spazio** o **N**
riavvia l'animazione (con il comportamento casuale ne estrae uno nuovo). Parametri URL: `?behavior=DNA&icons=Daedale`.

Il codice mantiene i nomi e la struttura dell'originale (`resetActor`, `moveActor`, `blowFactor`…)
in modo che ogni funzione si possa confrontare con il disassemblato. Le coordinate interne restano
quelle di Cocoa; solo il renderer le converte per il canvas.

### Differenze volute rispetto all'originale

- **Ridimensionamento**: Game Of Life ricostruisce la griglia quando la finestra cambia dimensione.
  L'originale la calcolava solo all'avvio, ma lì la finestra di un salvaschermo non cambiava mai.
- **Liste modificate durante l'iterazione**: in Fireworks e Game Of Life l'originale rimuove elementi
  dall'array che sta scorrendo con un `NSEnumerator`, un comportamento non definito. Qui si itera
  su una copia; al massimo cambia di un fotogramma il momento in cui un'icona si aggiorna.
- **Divisioni per zero**: alcuni divisori (`maxSpeed` in Fireworks, `LifeExpectancy/100` in
  Game Of Life…) sono limitati a un minimo di 1. Con i limiti del pannello non si arrivava mai a zero,
  tranne che per schermi alti meno di 127 punti.
- **Renderer unico**: Quartz e OpenGL producevano la stessa immagine, quindi c'è un solo motore di
  disegno: Canvas 2D sul web, Core Graphics (cioè Quartz 2D) su macOS. Il menu "Render through" della
  scheda Avanzate mostra solo quello.
- **Preferenze** salvate nel `localStorage` del browser invece che in `NSUserDefaults`.
- **Numeri casuali**: `Math.random()` al posto di `random()` della libc. La sequenza è diversa, ma la
  distribuzione è la stessa.

### Stranezze dell'originale mantenute

- **Comets**: la componente laterale della direzione è `random() % 2`, cioè 0 o 1 e mai −1. Le
  comete diagonali vanno quindi solo verso destra o verso l'alto.
- **Jumpers**: dopo la rinascita un'icona non azzera la capriola in corso e a volte ricompare
  capovolta per mezzo salto. Il bordo destro è calcolato come `larghezza − origine.x`.
- **Hypnosis**: il passo angolare è `360 / n` con divisione intera, quindi l'ultima icona di ogni
  anello si sovrappone in parte alla prima.
- **DNA**: il rettangolo usato per capire se un'elica è uscita dallo schermo è più stretto
  dell'elica stessa.
- **Game Of Life**: dopo ogni passo viene ordinata la lista delle nascite o delle morti, non quella
  disegnata.

## 5. Il salvaschermo per macOS moderni

`macos/` contiene una seconda reimplementazione, in Swift, installabile come salvaschermo su
macOS 11 o successivo (Apple Silicon e Intel). È divisa in due parti:

- `Sources/Core/`: i sei comportamenti tradotti riga per riga dalla versione web, usando solo
  Foundation. Si compila anche su Linux.
- `Sources/Saver/`: la vista `ScreenSaverView` (classe `IcoNVaderRestoredView`), il disegno con
  Core Graphics (la stessa trasformazione di `QuartzRenderer`), le preferenze con `ScreenSaverDefaults`
  e il pannello opzioni (vedi sotto). Come l'originale, cerca i set di icone anche in
  `/Library/Application Support/IcoNVader/Icon Sets/` e `~/Library/Application Support/IcoNVader/Icon Sets/`.

Le icone sono i file `.icns` originali, copiati nel bundle senza conversioni.

**Verifica di equivalenza.** `macos/Tests/compare.sh` esegue ogni comportamento sia in Swift sia in
JavaScript (Node) con lo stesso generatore casuale con seme (mulberry32) e confronta lo stato di
tutti gli attori dopo 600 fotogrammi: posizione, angolo, scala, opacità e icona devono coincidere
fino alla sesta cifra decimale. Il controllo copre 2 risoluzioni e 3 semi per comportamento.

## 6. Il pannello opzioni e le lingue

Il pannello è ricostruito dal nib originale `IVPreferences.nib`. Il file `objects.nib` è in formato
*typedstream* (NSArchiver) e si decodifica con il pacchetto Python `pytypedstream`:

```bash
python -m typedstream decode IcoNVader.saver/Contents/Resources/English.lproj/IVPreferences.nib/objects.nib
```

Ne escono l'albero delle viste con classe, posizione e testo di ogni controllo e i collegamenti con
`IVPreferencesController` (outlet e azioni). La finestra è di 456×357 punti e contiene una vista a
schede con tre pagine:

| Scheda | Controlli |
|---|---|
| **Appearance** | set di icone, striscia con le icone del set (`oIconTable`: una riga, una colonna per icona), dimensione delle icone, colore di sfondo |
| **Animation** | livello d'invasione, aspettativa di vita, velocità, comportamento, intervallo del cambio casuale |
| **Advanced** | motore di disegno (Quartz/OpenGL) con il suo logo, riga di copyright cliccabile verso `http://www.daedale.com/` (`IVLinkTextField`) |

L'originale aveva un nib per lingua (inglese e francese) con posizioni diverse per far stare i
testi francesi, più lunghi. Il salvaschermo per macOS usa le coordinate di entrambi; per l'italiano
usa quelle francesi. I testi originali delle due lingue, presi dai nib e da `Localizable.strings`,
sono raccolti con la traduzione italiana in `i18n/stringhe.json`, da cui
`tools/genera_traduzioni.py` genera i file per macOS e per il web.

Differenze rispetto all'originale: il link in basso porta al repository della ricostruzione invece
che al sito di Daedale, che non esiste più nella forma di allora; sul web il pannello si adatta agli
schermi stretti e la scheda Avanzate permette di scegliere la lingua.
