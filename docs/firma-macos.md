# Firma e notarizzazione del salvaschermo

Un salvaschermo scaricato da Internet viene bloccato da Gatekeeper se non è **firmato con un
certificato Developer ID** e **notarizzato** da Apple. Il workflow **Compila salvaschermo macOS**
fa entrambe le cose, e anche lo *staple* (allega al bundle il ticket di notarizzazione), se nel
repository ci sono i secret descritti qui sotto. Senza secret il bundle resta con la firma ad-hoc e
va sbloccato a mano (vedi il README).

## Come funziona, in breve

- **Il certificato** è la coppia formata da una **chiave privata**, che resta a chi firma, e da un
  certificato che Apple rilascia per quella chiave. Chi ha la chiave privata può firmare a nome del
  tuo team: è l'unica parte davvero da proteggere.
- **Tipi diversi per usi diversi.** *Apple Development* serve per sviluppare, *Apple Distribution*
  per App Store e TestFlight, *Developer ID Application* per distribuire fuori dall'App Store, come
  qui. Il certificato Developer ID non tocca le app su TestFlight.
- **Più certificati dello stesso tipo.** Un team può avere più certificati Developer ID Application
  attivi, ognuno con la sua chiave (Apple ne permette pochi, in genere fino a 5). Conviene crearne
  uno **solo per GitHub**, con una chiave che non passa mai dal Portachiavi né da Xcode. Se un
  giorno fosse compromesso, si revoca solo quello: i certificati del portatile e le app su
  TestFlight restano intatti. Revocarlo può però invalidare quello che è stato firmato con lui,
  cioè le release di questo progetto.
- **La notarizzazione** usa una chiave API di App Store Connect, separata dal certificato.
  Anche questa va creata apposta per GitHub, in modo da poterla revocare da sola.
- **Cosa resta in comune:** il team. Tutte le firme mostrano lo stesso nome
  *Developer ID Application: Nome (TEAMID)*; per separare anche quello servirebbe un secondo
  account sviluppatore.

## 1. Certificato dedicato a GitHub (senza Portachiavi né Xcode)

Si lavora in una cartella temporanea, con `openssl` (già presente su macOS).

```bash
mkdir -p ~/iconvader-firma && cd ~/iconvader-firma
```

Genera la chiave privata e la richiesta di certificato (CSR):

```bash
openssl req -new -newkey rsa:2048 -nodes -keyout developer-id.key -out developer-id.csr -subj "/CN=IcoNVader GitHub/C=IT"
```

Su [developer.apple.com → Certificates](https://developer.apple.com/account/resources/certificates/list)
premi **+**, scegli **Developer ID Application** (G2 Sub-CA), carica `developer-id.csr` e scarica il
certificato (`developerID_application.cer`) nella stessa cartella. Serve il ruolo di titolare
dell'account (*Account Holder*).

Unisci chiave e certificato in un `.p12` con una password casuale:

```bash
openssl x509 -inform DER -in developerID_application.cer -out developer-id.pem
```

```bash
openssl rand -hex 24 > p12-password.txt
```

```bash
openssl pkcs12 -export -inkey developer-id.key -in developer-id.pem -name "IcoNVader GitHub" -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 -passout file:p12-password.txt -out developer-id.p12
```

(La cifratura 3DES/SHA1 è quella che `security import` legge senza problemi sui runner macOS.)

## 2. Chiave API dedicata per la notarizzazione

In [App Store Connect](https://appstoreconnect.apple.com/) → **Utenti e accessi → Integrazioni →
App Store Connect API → Chiavi del team**, genera una chiave chiamata per esempio
*IcoNVader GitHub* con ruolo **Developer**, il minimo che consente la notarizzazione. Annota
l'**ID chiave** e l'**ID emittente** e scarica `AuthKey_XXXXXXXXXX.p8` nella cartella di prima
(si scarica una sola volta).

Una chiave del team con ruolo Developer vede anche le app del team in App Store Connect. Per
limitarla ancora di più si può invitare un utente dedicato con ruolo Developer, con accesso
ristretto ad app specifiche, e usare una sua chiave individuale.

## 3. Secret su GitHub

Con [GitHub CLI](https://cli.github.com/) (`brew install gh && gh auth login`), dalla cartella di
prima:

```bash
base64 -i developer-id.p12 | gh secret set MACOS_CERT_P12_BASE64 -R RobertoD91/IcoNVader-rebuild
```

```bash
gh secret set MACOS_CERT_PASSWORD -R RobertoD91/IcoNVader-rebuild --body "$(cat p12-password.txt)"
```

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set APP_STORE_CONNECT_API_KEY_BASE64 -R RobertoD91/IcoNVader-rebuild
```

```bash
gh secret set APP_STORE_CONNECT_KEY_ID -R RobertoD91/IcoNVader-rebuild --body "XXXXXXXXXX"
```

```bash
gh secret set APP_STORE_CONNECT_ISSUER_ID -R RobertoD91/IcoNVader-rebuild --body "ID-EMITTENTE"
```

In alternativa: **Settings → Secrets and variables → Actions → New repository secret**.

I nomi sono gli stessi usati da PicaSim per la firma macOS (`RELEASE_SIGNING.md` di quel
repository): se i due progetti usano lo stesso certificato e la stessa chiave, basta ripetere
questi comandi con `-R RobertoD91/PicaSim`. La chiave API di PicaSim ha ruolo App Manager, che
include anche la notarizzazione.

| Secret | Contenuto |
|---|---|
| `MACOS_CERT_P12_BASE64` | `developer-id.p12` in base64 |
| `MACOS_CERT_PASSWORD` | la password in `p12-password.txt` |
| `APP_STORE_CONNECT_API_KEY_BASE64` | il file `.p8` in base64 |
| `APP_STORE_CONNECT_KEY_ID` | l'ID chiave |
| `APP_STORE_CONNECT_ISSUER_ID` | l'ID emittente |

Poi cancella la cartella, oppure conservala su un supporto cifrato se vuoi poter ricreare i secret
senza generare un nuovo certificato:

```bash
rm -rf ~/iconvader-firma
```

Con i primi due secret il bundle viene firmato; con tutti e cinque viene anche notarizzato. Le
note della release indicano quale dei tre casi si è verificato.

## Chi può usare i secret

Il repository è pubblico, ma i secret non sono esposti: il workflow di compilazione parte solo a
mano (**Run workflow**), cosa che può fare solo chi ha accesso in scrittura al repository, e GitHub
non passa i secret ai workflow avviati da pull request di altri. Nei log i valori vengono mascherati.

## Cosa fa il workflow

Il workflow è diviso in tre job, così il certificato non passa mai da un job che usa strumenti
esterni:

- **build** compila e collauda il salvaschermo. Installa XcodeGen da Homebrew, quindi **non riceve
  alcun secret**. Passa al job successivo il bundle con la firma ad-hoc.
- **sign** è l'unico job che riceve i secret. Usa solo gli strumenti di Apple preinstallati sui
  runner e le azioni `actions/*` mantenute da GitHub:
  1. crea un portachiavi temporaneo, importa il `.p12` e cerca l'identità *Developer ID Application*;
  2. firma il bundle con `codesign --timestamp --options runtime` (*hardened runtime*, richiesto per
     la notarizzazione);
  3. invia lo zip al servizio di notarizzazione con `xcrun notarytool submit --wait`; se viene
     rifiutato, stampa il registro di Apple con il motivo;
  4. allega il ticket con `xcrun stapler staple`, così il controllo funziona anche senza connessione;
  5. cancella il portachiavi, ricollauda il bundle firmato e produce lo zip finale.
- **release** (solo se richiesto) pubblica la release con `gh`. È l'unico job con il permesso di
  scrittura sul repository e non riceve i secret di firma.

## Se qualcosa va storto

- **"A required agreement is missing or has expired" (errore 403):** Apple ha pubblicato un accordo
  aggiornato che il titolare dell'account deve accettare. Accedi a
  [developer.apple.com/account](https://developer.apple.com/account) e accetta l'accordo proposto
  (*Apple Developer Program License Agreement*); controlla anche
  [App Store Connect → Business](https://appstoreconnect.apple.com/business) per eventuali accordi
  in sospeso. Poi rilancia il workflow.
- **"The user name or passphrase you entered is not correct":** `MACOS_CERT_PASSWORD` non è la
  password di `MACOS_CERT_P12_BASE64`. Ricaricali insieme.

- **Certificato compromesso:** revocalo da developer.apple.com → Certificates, creane un altro con
  il passo 1 e aggiorna i due secret `MACOS_CERT_*`.
- **Chiave API compromessa:** revocala da App Store Connect → Integrazioni, generane un'altra e
  aggiorna i tre secret `APP_STORE_CONNECT_*`.
