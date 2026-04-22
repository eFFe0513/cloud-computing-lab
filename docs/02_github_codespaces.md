# GitHub Codespaces e Dev Containers

## Cos'è GitHub Codespaces?

**GitHub Codespaces** è un ambiente di sviluppo completo **nel cloud**, basato su **VS Code**, che gira in un **container Docker** configurabile.

### Vantaggi

✅ **Zero setup locale** → Funziona da browser o VS Code  
✅ **Ambiente riproducibile** → Stesso setup per tutto il team  
✅ **Potenza nel cloud** → Fino a 32-core, 64 GB RAM  
✅ **60h/mese gratis** → Sufficiente per studenti  
✅ **Pre-commit hooks** → Quality checks automatici  

---

## Dev Container: `.devcontainer/devcontainer.json`

Il file **devcontainer.json** definisce l'ambiente di sviluppo:

```json
{
  "name": "Node.js + Java Multi-Runtime",
  "image": "mcr.microsoft.com/devcontainers/universal:2",
  
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "20"
    },
    "ghcr.io/devcontainers/features/java:1": {
      "version": "21",
      "installMaven": true
    },
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  
  "customizations": {
    "vscode": {
      "extensions": [
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "redhat.java",
        "vscjava.vscode-spring-boot-dashboard",
        "ms-azuretools.vscode-docker"
      ],
      "settings": {
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "esbenp.prettier-vscode"
      }
    }
  },
  
  "forwardPorts": [3000, 8080],
  
  "postCreateCommand": "echo '✅ Dev Container ready!'",
  
  "remoteUser": "codespace"
}
```

---

## Configurazione Completa Repository

### Struttura Repository

```
cloud-computing-lab/
├── .devcontainer/
│   ├── devcontainer.json       ← Configurazione Codespaces
│   └── Dockerfile              ← (Opzionale) Custom image
│
├── nodejs-app/
│   ├── package.json
│   ├── server.js
│   └── Dockerfile
│
├── java-app/
│   ├── pom.xml
│   ├── src/main/java/...
│   └── Dockerfile
│
├── docker-compose.yml
└── README.md
```

### `.devcontainer/devcontainer.json` Minimalista

```json
{
  "name": "Cloud Computing Lab",
  "image": "mcr.microsoft.com/devcontainers/universal:2",
  
  "features": {
    "ghcr.io/devcontainers/features/node:1": {"version": "20"},
    "ghcr.io/devcontainers/features/java:1": {"version": "21", "installMaven": true}
  },
  
  "forwardPorts": [3000, 8080],
  "postCreateCommand": "npm install --prefix nodejs-app"
}
```

### `.devcontainer/Dockerfile` Custom (Avanzato)

Se hai bisogni specifici:

```dockerfile
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Install Java 21
RUN apt-get update && apt-get install -y \
    openjdk-21-jdk \
    maven && \
    apt-get clean

# Install Docker CLI (per docker-compose)
RUN apt-get install -y docker.io

# Global npm packages
RUN npm install -g nodemon typescript ts-node

USER vscode
```

Poi in `devcontainer.json`:

```json
{
  "build": {
    "dockerfile": "Dockerfile"
  }
}
```

---

## Setup Repository per Codespaces

### Step 1: Crea Repository GitHub

```bash
# Localmente (se hai Git)
mkdir cloud-computing-lab
cd cloud-computing-lab
git init
```

### Step 2: Crea Struttura

```bash
mkdir -p .devcontainer nodejs-app java-app
```

### Step 3: Crea `.devcontainer/devcontainer.json`

```json
{
  "name": "Node.js + Java Lab",
  "image": "mcr.microsoft.com/devcontainers/universal:2",
  "features": {
    "ghcr.io/devcontainers/features/node:1": {"version": "20"},
    "ghcr.io/devcontainers/features/java:1": {"version": "21"}
  },
  "forwardPorts": [3000, 8080]
}
```

### Step 4: Push su GitHub

```bash
git add .
git commit -m "Initial setup"
git branch -M main
git remote add origin https://github.com/tuousername/cloud-computing-lab.git
git push -u origin main
```

### Step 5: Apri in Codespaces

1. Vai su GitHub → tuo repository
2. Click **Code** (verde) → **Codespaces** tab
3. Click **Create codespace on main**
4. Attendi 1-2 minuti → VS Code nel browser!

---

## Comandi Utili in Codespaces

### Verifica Setup

```bash
# Check versioni
node --version    # v20.x
npm --version     # 10.x
java --version    # OpenJDK 21
mvn --version     # Maven 3.9.x

# Check Docker (se hai "docker-in-docker" feature)
docker --version
docker ps
```

### Port Forwarding

Codespaces forward automaticamente le porte in `forwardPorts`:

```bash
# Start Node.js app
cd nodejs-app
npm start
# → VS Code mostra notifica "Porta 3000 disponibile"
# → Click per aprire nel browser
```

URL formato: `https://<codespace-name>-3000.preview.app.github.dev`

### Terminal Multipli

- **Ctrl+Shift+`** → Nuovo terminal
- Utile per Node.js in un tab, Java in un altro

---

## Workflow Tipico

```bash
# 1. Apri Codespace (browser o VS Code locale)

# 2. Terminal 1: Node.js app
cd nodejs-app
npm install
npm run dev    # nodemon auto-reload

# 3. Terminal 2: Java app
cd java-app
mvn spring-boot:run

# 4. Terminal 3: Docker build
docker build -t myapp nodejs-app
docker run -p 3000:3000 myapp

# 5. Commit e push
git add .
git commit -m "Add feature X"
git push
```

---

## Estensioni VS Code Utili

Aggiungi in `devcontainer.json`:

```json
"customizations": {
  "vscode": {
    "extensions": [
      // JavaScript/Node.js
      "dbaeumer.vscode-eslint",
      "esbenp.prettier-vscode",
      
      // Java
      "redhat.java",
      "vscjava.vscode-java-pack",
      "vmware.vscode-spring-boot",
      
      // Docker
      "ms-azuretools.vscode-docker",
      
      // Git
      "eamodio.gitlens",
      
      // REST API testing
      "humao.rest-client"
    ]
  }
}
```

---

## Limitazioni e Costi

### Piano Gratuito

- **60 ore/mese** di runtime (2-core machine)
- **15 GB storage** (per Codespaces)
- **120 core-hours/mese** (es. 30h su 4-core machine)

### Ottimizzazione Costi

✅ **Stop quando non usi** → Auto-stop dopo 30 min inattività  
✅ **Delete old codespaces** → Settings → Codespaces  
✅ **Usa 2-core machine** per sviluppo normale  

### Alternative Gratuite

- **Gitpod** → 50h/mese gratuiti
- **Replit** → IDE browser, runtime gratis (limitato)
- **Docker Desktop locale** → Illimitato, richiede installazione

---

## Debugging in Codespaces

### Node.js Debug

`.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Node.js",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/nodejs-app/server.js",
      "console": "integratedTerminal"
    }
  ]
}
```

### Java Debug

Auto-configurato con estensione Java. F5 per debug.

---

## 📚 Risorse

- [GitHub Codespaces Docs](https://docs.github.com/en/codespaces)
- [Dev Container Specification](https://containers.dev/)
- [Dev Containers Features](https://containers.dev/features)
- [VS Code Remote Development](https://code.visualstudio.com/docs/remote/remote-overview)
