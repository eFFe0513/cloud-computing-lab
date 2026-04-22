# 📖 Esercizio C: Verifica Teorica

## Domande Aperte

### 1. Docker e Containerizzazione

**a)** Spiega la differenza tra **immagine Docker** e **container Docker**. Quando viene creato ciascuno?

**b)** Perché è importante usare **immagini Alpine** (es. `node:20-alpine`) invece di immagini standard?

**c)** Cosa accade quando esegui `docker build` e nel Dockerfile c'è un errore al layer 5 su 10? Devi rifare tutto da capo?

---

### 2. Multi-Stage Build

**a)** Spiega il vantaggio principale del **multi-stage build**. Perché riduce la dimensione dell'immagine finale?

**b)** In questo Dockerfile, cosa viene copiato nell'immagine finale?

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/server.js"]
```

---

### 3. GitHub Codespaces e Dev Containers

**a)** Qual è il vantaggio principale di usare **GitHub Codespaces** invece di installare Node.js e Java localmente?

**b)** Come fa GitHub Codespaces a sapere quali tool installare (Node.js, Java, Maven)? Dove lo configuri?

**c)** Cosa succede se chiudi il browser con un Codespace aperto? Perdi tutto il lavoro?

---

### 4. Docker Compose

**a)** Cosa fa il comando `docker-compose up --build`?

**b)** In questo `docker-compose.yml`, spiega cosa fa `depends_on`:

```yaml
services:
  gateway:
    build: ./gateway
    depends_on:
      - users-service
      - products-service
```

**c)** Perché i servizi possono comunicare con `http://users-service:3001` invece di `http://localhost:3001`?

---

### 5. Best Practices

**a)** Perché è importante **non eseguire container come root**? Come si imposta un utente non-root?

**b)** Qual è lo scopo del file `.dockerignore`? Fai 3 esempi di file da escludere.

**c)** Cosa fa questo comando nel Dockerfile?

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --spider http://localhost:8080/health || exit 1
```

---

## Domande a Risposta Multipla

### 6. Quale comando Docker rimuove **tutti** i container fermi?

- [ ] A. `docker stop $(docker ps -q)`
- [ ] B. `docker rm $(docker ps -aq)`
- [ ] C. `docker container prune`
- [ ] D. B e C

---

### 7. In un Dockerfile, quale layer viene cachato più a lungo?

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./    # Layer 1
RUN npm install          # Layer 2
COPY . .                 # Layer 3
CMD ["node", "server.js"]
```

- [ ] A. Layer 1 (COPY package.json)
- [ ] B. Layer 2 (RUN npm install)
- [ ] C. Layer 3 (COPY tutto il codice)
- [ ] D. Nessuno, cache sempre invalidata

---

### 8. Quale immagine base è più piccola per produzione Java?

- [ ] A. `openjdk:21`
- [ ] B. `maven:3.9-eclipse-temurin-21`
- [ ] C. `eclipse-temurin:21-jre-alpine`
- [ ] D. `eclipse-temurin:21-jdk`

---

### 9. In docker-compose, cosa fa questa configurazione?

```yaml
volumes:
  - ./src:/app/src
  - /app/node_modules
```

- [ ] A. Monta `src` locale e preserva `node_modules` del container
- [ ] B. Copia `src` e `node_modules` nell'immagine
- [ ] C. Crea un volume Docker per entrambi
- [ ] D. Errore di sintassi

---

### 10. Qual è il vantaggio di `npm ci` rispetto a `npm install` nel Dockerfile?

- [ ] A. Più veloce
- [ ] B. Usa esattamente le versioni di `package-lock.json`
- [ ] C. Installa solo dipendenze di produzione
- [ ] D. A e B

---

## Esercizi Pratici

### 11. Debugging Container

Un container Java non si avvia. Come lo debuggi?

```bash
# Il container esce subito
docker ps -a
# CONTAINER ID   STATUS    EXITED (1)
```

**Comandi da usare** (ordina in sequenza logica):

- [ ] `docker logs <container_id>`
- [ ] `docker inspect <container_id>`
- [ ] `docker exec -it <container_id> sh`
- [ ] `docker build --no-cache -t myapp .`

---

### 12. Scrivi Dockerfile

Crea un Dockerfile multi-stage per app Python Flask:

**Requisiti**:
- Build stage: Python 3.11, installa dipendenze da `requirements.txt`
- Runtime stage: Python 3.11-slim, copia solo il necessario
- Porta 5000
- User non-root (`flaskuser`)
- Health check su `/health`

```dockerfile
# TODO: scrivi qui
```

---

### 13. docker-compose per Database

Estendi il docker-compose dell'Esercizio B aggiungendo:
- PostgreSQL (porta 5432)
- Collegato alla rete `app-network`
- Volume per persistenza dati
- Variabili d'ambiente per username/password

```yaml
# TODO: aggiungi servizio postgres
```

---

## Scenario di Troubleshooting

### 14. Problema: "Port already in use"

```
Error starting userland proxy: listen tcp 0.0.0.0:3000: bind: address already in use
```

**a)** Quali comandi usi per identificare cosa occupa la porta 3000?

**b)** Come risolvi senza killare il processo?

---

### 15. Problema: Immagine Docker 2 GB

La tua immagine Node.js pesa 2 GB invece di 200 MB.

**Possibili cause** (segna tutte quelle corrette):

- [ ] A. Non usi Alpine
- [ ] B. `node_modules` copiato nell'immagine
- [ ] C. Nessun `.dockerignore`
- [ ] D. Non usi multi-stage build
- [ ] E. File `.git` incluso

---

## Progettazione Architettura

### 16. Design Microservizi

Devi progettare un sistema e-commerce con:
- Frontend (React)
- Backend API (Node.js)
- Database (PostgreSQL)
- Cache (Redis)
- Worker per email (Python)

**a)** Disegna l'architettura con tutti i servizi e le porte

**b)** Scrivi il `docker-compose.yml` completo

**c)** Quali servizi hanno `depends_on`?

**d)** Come gestiresti i secrets (DB password)?

---

## ✅ Criteri di Valutazione

| Sezione | Punteggio |
|---------|-----------|
| Domande aperte (1-5) | 30 punti (6 pt ciascuna) |
| Multiple choice (6-10) | 15 punti (3 pt ciascuna) |
| Pratici (11-13) | 25 punti |
| Troubleshooting (14-15) | 15 punti |
| Progettazione (16) | 15 punti |
| **TOTALE** | **100 punti** |

**Sufficienza**: 60/100

---

## 📚 Risorse per Studiare

- [Docker Docs](https://docs.docker.com/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Docker Compose Docs](https://docs.docker.com/compose/)
- Materiale del corso (docs/01-04)
