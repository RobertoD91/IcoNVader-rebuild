# Firma e notarizzazione del salvaschermo

Un salvaschermo scaricato da Internet viene bloccato da Gatekeeper se non è **firmato con un
certificato Developer ID** e **notarizzato** da Apple. Il workflow **Compila salvaschermo macOS**
fa entrambe le cose, e anche lo *staple* (il ticket di notarizzazione viene allegato al bundle), se
nel repository ci sono i secret descritti qui sotto. Senza secret il bundle resta con la firma
ad-hoc e va sbloccato a mano (vedi il README).

Serve un account Apple Developer a pagamento. Il certificato Developer ID lo può creare solo il
titolare dell'account (*Account Holder*).

## 1. Certificato "Developer ID Application"

1. In Xcode: **Settings → Accounts**, seleziona il tuo Apple ID e il team, poi **Manage
   Certificates… → + → Developer ID Application**. In alternativa si crea da
   [developer.apple.com → Certificates](https://developer.apple.com/account/resources/certificates/list).
2. Apri **Accesso Portachiavi**, categoria **I miei certificati**, trova
   *Developer ID Application: Nome (TEAMID)*, aprilo con la freccia per vedere che c'è la chiave
   privata, selezionali entrambi e scegli **Esporta 2 elementi…** in formato `.p12`, con una password.
3. Converti il file in base64 e copialo negli appunti:

```bash
base64 -i Certificati.p12 | pbcopy
```

## 2. Chiave API di App Store Connect (per la notarizzazione)

1. In [App Store Connect](https://appstoreconnect.apple.com/) vai su **Utenti e accessi →
   Integrazioni → App Store Connect API → Chiavi del team** e genera una chiave con ruolo
   **Developer**.
2. Annota l'**ID chiave** e l'**ID emittente** (Issuer ID) mostrati nella pagina.
3. Scarica `AuthKey_XXXXXXXXXX.p8` (si può scaricare una sola volta) e convertilo in base64:

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

## 3. Secret su GitHub

Nel repository: **Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Contenuto |
|---|---|
| `MACOS_CERTIFICATE_P12` | il `.p12` in base64 (passo 1) |
| `MACOS_CERTIFICATE_PASSWORD` | la password scelta all'esportazione del `.p12` |
| `NOTARY_API_KEY` | il file `.p8` in base64 (passo 2) |
| `NOTARY_API_KEY_ID` | l'ID chiave |
| `NOTARY_API_ISSUER_ID` | l'ID emittente |

Con i primi due il bundle viene firmato; con tutti e cinque viene anche notarizzato. Le note della
release indicano quale dei tre casi si è verificato.

## Cosa fa il workflow

1. Crea un portachiavi temporaneo, importa il `.p12` e cerca l'identità *Developer ID Application*.
2. Firma il bundle con `codesign --timestamp --options runtime` (*hardened runtime*, richiesto
   per la notarizzazione).
3. Invia lo zip al servizio di notarizzazione con `xcrun notarytool submit --wait`; se viene
   rifiutato, stampa il registro di Apple con il motivo.
4. Allega il ticket con `xcrun stapler staple`, così il controllo funziona anche senza connessione.
5. Esegue il collaudo sul bundle firmato e alla fine cancella il portachiavi temporaneo.

I secret non finiscono mai nei log e i file temporanei (`.p12`, `.p8`) vengono cancellati subito
dopo l'uso.
