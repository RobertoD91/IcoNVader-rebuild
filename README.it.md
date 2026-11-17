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

## Installazione su macOS

1. Scarica `IcoNVader-saver.zip` dall'[ultima release](https://github.com/RobertoD91/IcoNVader-rebuild/releases/latest).
2. Estrai lo zip e fai doppio clic su `IcoNVader.saver`.
3. Sceglilo in **Impostazioni di Sistema → Salvaschermo**. Il pulsante **Opzioni** apre il pannello
   delle impostazioni.

Funziona da macOS 11 in poi, su Apple Silicon e Intel, ed è firmato e notarizzato da Apple. Se
aggiorni da una versione precedente, chiudi Impostazioni di Sistema ed esegui
`killall legacyScreenSaver`, altrimenti macOS continua a usare quella vecchia.

**Con [Homebrew](https://brew.sh):**

```bash
brew install --cask robertod91/tap/iconvader
```

Si aggiorna con `brew upgrade --cask iconvader` e si rimuove con
`brew uninstall --cask --zap iconvader`.

**Icone personalizzate:** come nell'originale, metti una cartella di file `.icns` o `.png` in
`~/Library/Application Support/IcoNVader/Icon Sets/` e comparirà nel menu **Icone**.

## Versione web

https://robertodisanto.it/IcoNVader-rebuild/ — **P** apre le opzioni, **F** passa a schermo intero,
**Spazio** riavvia l'animazione. Si può anche aprire in locale `web/iconvader/index.html`.

## Come è stato ricostruito

- Il binario originale è stato disassemblato e letto classe per classe: ognuna delle sei
  animazioni (**Comets**, **Fireworks**, **Game Of Life**, **Hypnosis**, **DNA**, **Jumpers**) usa
  le stesse formule, gli stessi tempi e perfino le piccole stranezze dell'originale.
- È stato riscritto due volte, come pagina web (JavaScript) e come salvaschermo per macOS (Swift).
  Con gli stessi numeri casuali le due versioni producono esattamente la stessa animazione,
  fotogramma per fotogramma.
- Il pannello delle opzioni è ricostruito dal file d'interfaccia originale: stesse schede,
  controlli e testi, in inglese e francese come l'originale, più l'italiano.

I dettagli sono in [`docs/iconvader/README.md`](docs/iconvader/README.md).

## Per sviluppatori

```bash
cd macos && xcodegen generate && open IcoNVader.xcodeproj
```

```bash
macos/Tests/compare.sh
```

Il primo comando apre il salvaschermo in Xcode (serve `brew install xcodegen`); il secondo
controlla che le versioni Swift e JavaScript restino identiche. Il workflow **Compila salvaschermo
macOS** compila, collauda, firma, notarizza e, se richiesto, pubblica una release; la firma è
descritta in [`docs/firma-macos.md`](docs/firma-macos.md).

## Licenza

Il codice di questa ricostruzione è distribuito con [licenza MIT](LICENSE). La licenza non copre il
materiale originale di Daedale (il bundle `IcoNVader.saver`, il binario, le icone e le loro
conversioni), che resta di proprietà dei rispettivi titolari. IcoNVader 3.0 è © 2004-2006 Daedale;
questo progetto non è affiliato a Daedale né da essa approvato.
