# Cloud Computing Lab — Lab guidato: Container nodejs con GitHub Codespaces

Repository per lo studio pratico di **Docker**, **Docker Compose** e applicazioni containerizzate.
In questo laboratorio vedremo come creare un container Docker per una semplice app Node.js, come avviarlo, testarlo e gestirne il ciclo di vita. Useremo GitHub Codespaces per lavorare in un ambiente di sviluppo già configurato con Docker.

## Obiettivo

Capire cos'è un **Dev Container**, come si configura da zero e come si usa in GitHub Codespaces.

---

## Competenze

✅ Creare un repository Git e configurare un Dev Container  
✅ Usare le *features* di Dev Container (Node, Docker-in-Docker)  
✅ Aprire il progetto in VS Code con "Reopen in Container"  
✅ Fare commit e push su GitHub  

---

## Struttura del repository

```
cloud-computing-lab/
├── .devcontainer/
│   └── devcontainer.json          ← Ambiente Codespace (Node 24 + Docker-in-Docker)
├── nodejs-app/                    ← App Node.js standalone (avvio diretto con npm)
│   ├── server.js
│   └── package.json
└── docker-container/              ← Container Docker pronti all'uso
```
---

## Parte 1: Creare un Dev Container da zero

**cos'è un Dev Container e come si costruisce**.

### Cos'è un Dev Container?

Un **Dev Container** è un container Docker usato come ambiente di sviluppo.
Invece di installare Node, Java, Docker ecc. sul tuo PC, VS Code (o Codespaces) avvia
un container con tutto il necessario già dentro, e ti ci connette automaticamente.

```
Il tuo PC / Codespaces
│
└── VS Code
      │
      └── si connette a ──► Container (Debian + Node + Docker)
                                │
                                └── qui esegui tutto il codice
```

La configurazione è in una sola cartella:

```
progetto/
└── .devcontainer/
    └── devcontainer.json   ← tutto qui
```

### Step 1.1: Crea Repository su GitHub

1. Vai su [github.com](https://github.com) e accedi
2. Click su **New repository** (pulsante verde)
3. Compila i campi:
   - **Repository name:** `cloud-computing-lab`
   - **Description:** `Node.js Docker lab`
   - **Public** ✅
   - **Initialize with README** ✅
4. Click **Create repository**

### Step 1.2: Crea la struttura di base

Partendo da una cartella vuota:

```bash
mkdir il-mio-lab
cd il-mio-lab
git init
mkdir .devcontainer
```

### Step 1.3: Crea `devcontainer.json` — versione minimale

```bash
cat > .devcontainer/devcontainer.json << 'EOF'
{
  "name": "Il mio Lab",
  "image": "mcr.microsoft.com/devcontainers/base:debian"
}
EOF
```

Questo è il minimo indispensabile: un nome e un'immagine base.
Apri la cartella in VS Code → compare il popup **"Reopen in Container"** → click per entrare.

### Step 1.4: Aggiungi le **features** (Node + Docker)

Le *features* sono pacchetti preconfigurati che si installano sull'immagine base.
Non devi scrivere un Dockerfile: bastano poche righe:

```jsonc
{
  "name": "Il mio Lab",
  "image": "mcr.microsoft.com/devcontainers/base:debian",

  "features": {
    // Installa Node.js versione 24
    "ghcr.io/devcontainers/features/node:1": { "version": "24" },

    // Installa Docker-in-Docker (per usare docker dentro il container)
    "ghcr.io/devcontainers/features/docker-in-docker:2": { "moby": false }
  }
}
```

> 💡 `"moby": false` dice di installare il client Docker ufficiale invece di Moby
> (necessario su immagini Debian recenti come `trixie`).

### Step 1.5: Aggiungi `postCreateCommand` e `forwardPorts`

```jsonc
{
  "name": "Il mio Lab",
  "image": "mcr.microsoft.com/devcontainers/base:debian",

  "features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "24" },
    "ghcr.io/devcontainers/features/docker-in-docker:2": { "moby": false }
  },

  // Comando eseguito UNA VOLTA dopo la creazione del container
  "postCreateCommand": "docker --version && node --version",

  // Porte da esporre automaticamente verso il browser
  "forwardPorts": [3000, 8080, 8888]
}
```

| Chiave | Cosa fa |
|--------|---------|
| `image` | Immagine Docker da usare come base dell'ambiente |
| `features` | Pacchetti aggiuntivi da installare (node, docker, git, ecc.) |
| `postCreateCommand` | Script eseguito dopo il build, una volta sola |
| `forwardPorts` | Porte del container esposte come se fossero sul tuo `localhost` |

### Step 1.6: Commit

```bash
git add .devcontainer/devcontainer.json
git commit -m "feat: add devcontainer configuration"
```

Fatto. Quando apri questo repository in Codespaces (o in VS Code con l'estensione
*Dev Containers*), ottieni un ambiente già pronto con Node 24 e Docker disponibili.

## Parte 2: Analizzare un Dev Container esistente

Apri il file `.devcontainer/devcontainer.json` del repository `cloud-computing-lab` e confrontalo con quello creato da zero:

```jsonc
{
  "name": "Node.js Lab",
  "image": "mcr.microsoft.com/devcontainers/base:debian",

  "features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "24" },
    "ghcr.io/devcontainers/features/docker-in-docker:2": { "moby": false }
  },

  "postCreateCommand": "docker --version && node --version",

  "customizations": {
    "vscode": {
      "extensions": [
        "dbaeumer.vscode-eslint",
        "ms-azuretools.vscode-docker"
      ]
    }
  },

  "forwardPorts": [3000, 8080, 8888]
}
```

> 📝 La sezione `customizations.vscode.extensions` installa automaticamente le estensioni
> VS Code nel container. `forwardPorts` espone le porte 3000, 8080 e 8888.

### Step 2.1: Apri il Codespace

1. Vai su [github.com/filippo-bilardo/cloud-computing-lab](https://github.com/filippo-bilardo/cloud-computing-lab)
2. Click su **Code** (verde) → tab **Codespaces** → **Create codespace on main**
3. Attendi 1–2 minuti → VS Code si apre nel browser

### Step 2.2: Verifica l'ambiente

```bash
node --version    # v24.x
docker --version  # Docker 27.x
```

---

## Parte 3: Creare e avviare la `nodejs-app`

Una volta aperto il Codespace (o il Dev Container), crea una semplice app Node.js
che gira **direttamente nell'ambiente**, senza Docker.

### Step 3.1: Crea la cartella e inizializza il progetto

```bash
mkdir nodejs-app
cd nodejs-app
npm init -y
```

`npm init -y` genera un `package.json` con i valori predefiniti.

### Step 3.2: Installa Express

```bash
npm install express
```

Questo aggiunge Express come dipendenza in `package.json` e crea la cartella `node_modules/`.

### Step 3.3: Crea `server.js`

```bash
cat > server.js << 'EOF'
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from Node.js!',
    service: 'nodejs-api'
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ Node.js app running on port ${PORT}`);
});
EOF
```

### Step 3.4: Aggiungi lo script `start` a `package.json`

Apri `package.json` e assicurati che la sezione `scripts` contenga:

```json
"scripts": {
  "start": "node server.js"
}
```

### Step 3.5: Avvia l'app

```bash
npm start
# Output: ✅ Node.js app running on port 3000
```

### Step 3.6: Testa l'app

Apri un **secondo terminale** (senza fermare il server) e lancia:

```bash
curl http://localhost:3000/
# Output: {"message":"Hello from Node.js!","service":"nodejs-api"}

curl http://localhost:3000/health
# Output: {"status":"ok"}
```

In Codespaces appare la notifica **"Port 3000 is available"** → click per aprire nel browser.

### Step 3.7: Aggiungi `.gitignore`

```bash
echo "node_modules/" > .gitignore
```

Esclude la cartella `node_modules/` dal repository (le dipendenze si riscaricanno con `npm install`).

### Step 3.8: Commit

```bash
cd ..   # torna alla root del progetto
git add nodejs-app/
git commit -m "feat: add nodejs-app standalone"
```

> 💡 **Differenza rispetto al container Docker**: questa app usa Node.js installato
> nel Dev Container tramite la *feature*. Nell'[Esercizio B](esercizio_b.md)
> la stessa app girerà dentro un container Docker isolato.

---

## ✅ Verifica completamento Esercizio A

- [ ] Cartella `.devcontainer/` creata con `devcontainer.json` minimale
- [ ] Features Node e Docker-in-Docker aggiunte
- [ ] `postCreateCommand` e `forwardPorts` configurati
- [ ] Commit effettuato con messaggio descrittivo
- [ ] Codespace aperto e `node --version` / `docker --version` verificati

---

## 📸 Screenshot da consegnare (Esercizio A)

1. File `devcontainer.json` completo (Step 1.4)
2. Terminale Codespace: output di `node --version` e `docker --version`

---

## 🎯 Prossimi passi

- Completa **[Esercizio B](esercizio_b.md)** — Fork del repository e gestione container Docker (Node.js, Java Spring Boot, LAMP)
- Modifica `docker-container/nodejs/server.js` e fai rebuild per vedere le variazioni
- Aggiungi un endpoint `/info` alla Spring Boot app che restituisce la versione Java
- Aggiungi un campo `categoria` alla Kanban Board e filtra per categoria

