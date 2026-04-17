# 🔬 Esercizio B: Gestione di container Docker

> **Prerequisito**: completare [Esercizio A](README.md#-esercizio-a-dev-container--configurazione-dellambiente-di-sviluppo) (configurazione Dev Container).

## Obiettivo

Fare il fork e clonare il repository `cloud-computing-lab`, avviare container Docker con applicazioni
Node.js, Java e PHP/MariaDB e testarle dall'interno del Codespace.

## Competenze

✅ Fare il fork e clonare un repository GitHub  
✅ Avviare container con `docker run` e `docker compose`  
✅ Testare API REST con il browser e `curl`  
✅ Aprire il progetto in GitHub Codespaces  

## Struttura del repository

```
cloud-computing-lab/
├── .devcontainer/
│   └── devcontainer.json          ← Ambiente Codespace (Node 24 + Docker-in-Docker)
├── nodejs-app/                    ← App Node.js standalone (avvio diretto con npm)
└── docker-container/              ← Container Docker pronti all'uso
    ├── nodejs/                    ← Node.js + Express (Dockerfile + docker run)
    ├── java-spring/               ← Spring Boot (Dockerfile multi-stage, porta 8080)
    └── lamp/                      ← PHP 8.2 + Apache + MariaDB (docker-compose, porta 8888)
```

## Container disponibili

| Container | Stack | Porta | Avvio |
|-----------|-------|-------|-------|
| `nodejs/` | Node.js 20 + Express | 3000 | `docker run` |
| `java-spring/` | Java 21 + Spring Boot | 8080 | `docker run` |
| `lamp/` | PHP 8.2 + Apache + MariaDB 10.11 | 8888 | `docker compose` |

---

## Parte 1: Fork e Clone del Repository

### Step 1.1: Fork del repository

1. Apri [github.com/filippo-bilardo/cloud-computing-lab](https://github.com/filippo-bilardo/cloud-computing-lab)
2. Click su **Fork** (in alto a destra)
3. Seleziona il tuo account → **Create fork**

### Step 1.2: Clone in locale (opzionale)

```bash
git clone https://github.com/TUO_USERNAME/cloud-computing-lab.git
cd cloud-computing-lab
```

> ⚠️ Puoi anche lavorare direttamente nel browser usando GitHub Codespaces (→ Parte 5).

---

## Parte 2: Container Node.js

### Step 2.1: Esplora il codice

```bash
cat docker-container/nodejs/server.js
```

Il container espone un'API Express su porta 3000 con endpoint `/` e `/health`.

### Step 2.2: Esplora il Dockerfile

```bash
cat docker-container/nodejs/Dockerfile
```

Il file contiene 7 istruzioni, ognuna crea un **layer** dell'immagine:

```dockerfile
FROM node:20-alpine
```
**Immagine base**: Node.js 20 su Alpine Linux (~5 MB).  
Alpine è una distribuzione Linux minimale, ideale per container perché riduce le dimensioni
dell'immagine finale rispetto a Debian/Ubuntu (~50 MB vs ~900 MB).

```dockerfile
WORKDIR /app
```
**Directory di lavoro** dentro il container. Tutti i comandi successivi (`COPY`, `RUN`, `CMD`)
vengono eseguiti in `/app`. Se la cartella non esiste, Docker la crea automaticamente.

```dockerfile
COPY package*.json ./
RUN npm install
```
**Strategia di cache a due passi**: prima si copiano solo i file `package.json` e
`package-lock.json`, poi si installa. In questo modo, se il codice sorgente cambia ma
le dipendenze rimangono le stesse, Docker riusa il layer di `npm install` dalla cache
(build molto più veloci).

```dockerfile
COPY . .
```
Copia tutto il resto del codice sorgente nel container (escluso ciò che è in `.dockerignore`).
Viene fatto **dopo** `npm install` appositamente per sfruttare la cache.

```dockerfile
EXPOSE 3000
```
**Documenta** la porta su cui il container ascolta. Non apre la porta da sola — è solo
metadata; l'apertura vera avviene con `-p 3000:3000` nel comando `docker run`.

```dockerfile
CMD ["npm", "start"]
```
**Comando di avvio**: eseguito quando il container parte. Usa la forma array (exec form)
per evitare una shell intermedia — il processo Node.js diventa direttamente il PID 1
del container, così riceve correttamente i segnali di stop (`SIGTERM`).

---

**Riepilogo del flusso**:

```
docker build
  └── FROM node:20-alpine          ← scarica l'immagine base
  └── WORKDIR /app                 ← crea /app
  └── COPY package*.json ./        ← copia manifest dipendenze
  └── RUN npm install              ← installa dipendenze (layer cachato)
  └── COPY . .                     ← copia il codice sorgente
  └── EXPOSE 3000                  ← documenta la porta
        ↓
      Immagine pronta

docker run -p 3000:3000
  └── CMD ["npm", "start"]         ← avvia il server Express
```

### Step 2.3: Build dell'immagine

```bash
cd docker-container/nodejs
docker build -t nodejs-api:1.0 .
```

### Step 2.4: Avvio del container

```bash
docker run -d -p 3000:3000 --name nodejs-api nodejs-api:1.0
```

### Step 2.5: Test

```bash
curl http://localhost:3000/
# Output: {"message":"Hello from Node.js!","service":"nodejs-api", ...}

curl http://localhost:3000/health
# Output: {"status":"ok"}
```

VS Code mostra la notifica **"Port 3000 is available"** → click per aprire nel browser.

### Output atteso nel browser:
![alt text](assets/image-nodejs-app.png)

### Step 2.6: Cleanup

```bash
docker stop nodejs-api && docker rm nodejs-api
```

---

## Parte 3: Container Java Spring Boot

### Step 3.1: Esplora il codice

```bash
cat docker-container/java-spring/Dockerfile
# → Dockerfile multi-stage: Maven build + JRE runtime (immagine finale ~70 MB)
```

Il Dockerfile usa un build a due stadi:
1. **Build stage** (`maven:3.9`) — compila il JAR con `mvn package`
2. **Runtime stage** (`eclipse-temurin:21-jre-alpine`) — esegue solo il JAR

### Step 3.2: Build dell'immagine

```bash
cd docker-container/java-spring
docker build -t spring-dashboard:1.0 .
# Richiede ~2-3 minuti al primo build (scarica dipendenze Maven)
```

### Step 3.3: Avvio del container

```bash
docker run -d -p 8080:8080 --name spring-dashboard spring-dashboard:1.0
```

### Step 3.4: Verifica startup

```bash
# Attendi ~15 secondi, poi:
docker logs spring-dashboard | tail -5
# Cerca: "Started Application in X.XXX seconds"
```

### Step 3.5: Test

```bash
curl http://localhost:8080/
# Output: {"message":"Hello from Java!","service":"spring-dashboard", ...}

curl http://localhost:8080/health
# Output: {"status":"ok"}
```

### Step 3.6: Cleanup

```bash
docker stop spring-dashboard && docker rm spring-dashboard
```

---

## Parte 4: Stack LAMP (PHP + MariaDB)

Lo stack LAMP usa **Docker Compose** per orchestrare due container: webserver PHP e database MariaDB.
L'applicazione è una **Kanban Board** moderna con persistenza su MariaDB.

### Step 4.1: Configurazione

```bash
cd docker-container/lamp
cp .env.example .env
# Modifica .env se vuoi cambiare le credenziali (opzionale)
```

### Step 4.2: Avvio dello stack

```bash
docker compose up -d
```

Docker Compose:
1. Crea la rete `lamp_network`
2. Avvia `lamp_mariadb` (MariaDB 10.11) e attende l'healthcheck
3. Avvia `lamp_webserver` (PHP 8.2 + Apache)
4. Al primo accesso, `db.php` crea il DB `taskmanager`, la tabella e i task iniziali

### Step 4.3: Verifica stato

```bash
docker compose ps
# Entrambi i container devono essere "Up (healthy)"
```

### Step 4.4: Test

```bash
# Health check API
curl http://localhost:8888/api.php?action=ping
# Output: {"status":"ok","db":"taskmanager","php":"8.2.x"}

# Lista task
curl http://localhost:8888/api.php?action=list
```

Apri `http://localhost:8888` nel browser per vedere la **Kanban Board** con i task dell'esercitazione.

### Step 4.5: Operazioni CRUD

Testa la Kanban Board nell'interfaccia grafica:

| Azione | Come farlo |
|--------|-----------|
| Aggiungi task | Click su **＋ Nuovo Task** (in alto a destra) |
| Modifica task | Hover sulla card → click ✏️ |
| Sposta task | Trascina la card in un'altra colonna |
| Elimina task | Hover sulla card → click 🗑️ → conferma |

### Step 4.6: Cleanup

```bash
docker compose down
# I dati rimangono nel volume mysql_data
# Per eliminare anche i dati: docker compose down -v
```

---

## Parte 5: Aprire in GitHub Codespaces

### Step 5.1: Crea il Codespace

1. Vai sul tuo fork GitHub
2. Click su **Code** (verde) → tab **Codespaces**
3. Click **Create codespace on main**
4. Attendi 1–2 minuti → VS Code si apre nel browser

### Step 5.2: Verifica installazioni

```bash
node --version    # v24.x
docker --version  # Docker 27.x (Docker-in-Docker)
```

### Step 5.3: Crea la rete Docker condivisa

```bash
docker network create nginx_proxy_network
# Necessaria per lo stack LAMP
```

### Step 5.4: Testa tutti i container nel Codespace

```bash
# Node.js
cd docker-container/nodejs
docker build -t nodejs-api:1.0 . && docker run -d -p 3000:3000 --name nodejs-api nodejs-api:1.0
curl http://localhost:3000/

# Java Spring
cd ../java-spring
docker build -t spring-dashboard:1.0 . && docker run -d -p 8080:8080 --name spring-dashboard spring-dashboard:1.0
# attendi ~15s
curl http://localhost:8080/

# LAMP
cd ../lamp
cp .env.example .env
docker compose up -d
curl http://localhost:8888/api.php?action=ping
```

VS Code mostra le notifiche per ogni porta aperta → click per aprire nel browser integrato.

---

## Parte 6: App Node.js standalone (senza Docker)

Il repository include anche `nodejs-app/` — una versione dell'app Node.js che gira
direttamente nell'ambiente Codespace, **senza Docker**.

```bash
cd nodejs-app
npm install
npm start
# Output: ✅ Node.js app running on port 3000
```

Utile per confrontare:
- **Con Docker** (`docker-container/nodejs/`): app isolata, riproducibile ovunque
- **Senza Docker** (`nodejs-app/`): avvio diretto, dipende dall'ambiente host

---

## ✅ Verifica completamento

- [ ] Repository forkato e clonato
- [ ] Container Node.js avviato e testato (`curl http://localhost:3000/`)
- [ ] Container Java Spring avviato e testato (`curl http://localhost:8080/`)
- [ ] Stack LAMP avviato (`docker compose up -d`) e testato (ping API)
- [ ] Kanban Board aperta nel browser su porta 8888
- [ ] Operazioni CRUD eseguite sulla Kanban Board
- [ ] Codespace aperto e stack testato
- [ ] Commit e push effettuati

---

## 📸 Screenshot da consegnare

1. Terminale: output di `docker ps` con tutti i container in esecuzione
2. Browser: Kanban Board (`http://localhost:8888`) con i task nelle tre colonne
3. Browser o terminale: risposta JSON di `/api.php?action=ping`
4. Browser o terminale: risposta JSON di Node.js API (`http://localhost:3000/`)
5. Browser o terminale: risposta JSON di Spring Boot API (`http://localhost:8080/`)
6. Codespace aperto (screenshot di VS Code nel browser con il terminale visibile)

---

## ⚠️ Troubleshooting

### Problema: "Cannot connect to the Docker daemon"

**Causa**: Docker daemon non ancora pronto nel Codespace (prime fasi di setup).  
**Soluzione**: Attendi 30 secondi e riprova. Verifica che `devcontainer.json` abbia la feature `docker-in-docker:2` con `"moby": false`.

### Problema: `lamp_webserver` in stato `Exit` o `Restarting`

```bash
docker compose logs webserver
```

Se l'errore riguarda MariaDB non ancora pronto, attendi ~40 secondi e:
```bash
docker compose up -d
```

### Problema: Rete `nginx_proxy_network` non trovata

```bash
docker network create nginx_proxy_network
docker compose up -d
```

### Problema: Port forwarding non funziona

1. Tab **Ports** in VS Code → **Add Port** → inserisci `3000`, `8080` o `8888`
2. Click sull'icona 🌐 per aprire nel browser
3. Verifica che `forwardPorts` in `devcontainer.json` includa le porte necessarie

### Problema: Spring Boot impiega troppo a partire

Il primo `docker build` di Java scarica ~200 MB di dipendenze Maven.  
Le build successive usano la cache Docker e impiegano < 30 secondi.

```bash
docker logs spring-dashboard -f
# Attendi la riga: "Started Application in X.XXX seconds"
```
