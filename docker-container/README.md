# Docker Container Examples – Cloud Computing Lab

Raccolta di esempi pratici per imparare a creare, avviare e gestire container Docker. Ogni sottocartella contiene un'applicazione di esempio pronta per essere containerizzata.

---

## Struttura del progetto

```
docker-container/
├── nodejs/        # Dashboard Node.js con statistiche del container (questo esempio)
├── java-spring/   # Applicazione Java Spring Boot
├── lamp/          # Stack LAMP (Linux, Apache, MySQL, PHP)
└── owncloud/      # Istanza ownCloud
```

---

## Concetti fondamentali di Docker

### Cos'è un container?
Un **container** è un'unità software leggera e isolata che racchiude un'applicazione insieme a tutte le sue dipendenze (librerie, runtime, file di configurazione). A differenza di una macchina virtuale, un container condivide il kernel del sistema operativo host, risultando molto più leggero e veloce da avviare.

```
┌─────────────────────────────────────┐
│           Applicazione              │
│         Dipendenze / Librerie       │
│            Runtime (Node, JVM…)     │
├─────────────────────────────────────┤
│          Container Engine (Docker)  │
├─────────────────────────────────────┤
│         Sistema Operativo Host      │
│              Hardware               │
└─────────────────────────────────────┘
```

### Dockerfile
Il **Dockerfile** è un file di testo con le istruzioni per costruire un'**immagine** Docker. Le istruzioni più comuni sono:

| Istruzione | Significato |
|------------|-------------|
| `FROM`     | Immagine base di partenza |
| `WORKDIR`  | Directory di lavoro all'interno del container |
| `COPY`     | Copia file dall'host nel container |
| `RUN`      | Esegue un comando durante la build |
| `EXPOSE`   | Dichiara la porta su cui l'app è in ascolto |
| `CMD`      | Comando eseguito all'avvio del container |

### Immagine vs Container
- **Immagine**: snapshot immutabile (come un template o una classe)
- **Container**: istanza in esecuzione di un'immagine (come un oggetto istanziato)

---

## Esempio: Node.js Container Dashboard

L'applicazione nella cartella `nodejs/` è una **dashboard web** che mostra in tempo reale le statistiche del container in esecuzione: CPU, memoria, rete, processi e informazioni sull'ambiente.

### Dockerfile spiegato

```dockerfile
FROM node:20-alpine        # Usa Node.js 20 su Alpine Linux (immagine minimale ~50MB)
WORKDIR /app               # Imposta /app come directory di lavoro
COPY package*.json ./      # Copia i file di dipendenze (ottimizza la cache di Docker)
RUN npm install            # Installa le dipendenze Node.js
COPY . .                   # Copia il resto del codice sorgente
EXPOSE 3000                # Documenta che l'app usa la porta 3000
CMD ["npm", "start"]       # Comando di avvio del container
```

> **Perché copiare `package*.json` prima del resto del codice?**  
> Docker costruisce l'immagine a strati (*layers*). Copiando prima solo i file delle dipendenze, se il codice cambia ma le dipendenze no, Docker riusa il layer già costruito con `npm install`, velocizzando notevolmente la build.

### Endpoint API

| Endpoint       | Descrizione |
|----------------|-------------|
| `GET /`        | Dashboard HTML con grafici real-time |
| `GET /api/info`    | Informazioni statiche su container, OS, CPU, memoria |
| `GET /api/metrics` | Metriche real-time: carico CPU, RAM, rete, disco |

---

## Guida pratica: Build, Run, Manage

### 1. Costruire l'immagine

```bash
cd docker-container/nodejs

# Build dell'immagine con tag
docker build -t container-dashboard:1.0 .

# Verifica che l'immagine sia stata creata
docker images
```

### 2. Avviare il container

```bash
# Avvio interattivo (il log viene stampato nel terminale, Ctrl+C per fermare)
docker run -p 3000:3000 container-dashboard:1.0

# Avvio in background (detached mode)
docker run -d -p 3000:3000 --name my-dashboard container-dashboard:1.0

# Con variabile d'ambiente personalizzata
docker run -d -p 8080:3000 --name my-dashboard \
  -e NODE_ENV=production \
  container-dashboard:1.0
```

Apri il browser su **http://localhost:3000** per vedere la dashboard.

### 3. Gestire il container

```bash
# Elenco dei container in esecuzione
docker ps

# Elenco di tutti i container (inclusi quelli fermi)
docker ps -a

# Fermare il container
docker stop my-dashboard

# Riavviare il container
docker restart my-dashboard

# Rimuovere il container (deve essere fermo)
docker rm my-dashboard

# Fermare e rimuovere in un solo comando
docker rm -f my-dashboard
```

### 4. Ispezionare il container

```bash
# Log dell'applicazione
docker logs my-dashboard

# Log in tempo reale (segue l'output)
docker logs -f my-dashboard

# Statistiche di CPU e memoria in tempo reale
docker stats my-dashboard

# Aprire una shell bash all'interno del container
docker exec -it my-dashboard sh

# Ispezionare la configurazione completa del container
docker inspect my-dashboard
```

### 5. Pulizia delle risorse

```bash
# Rimuovere l'immagine
docker rmi container-dashboard:1.0

# Rimuovere tutti i container fermi, immagini non usate, volumi orfani
docker system prune -a
```

---

## Ciclo di vita di un container

```
  docker build
       │
       ▼
  [IMMAGINE] ──── docker run ────► [RUNNING]
                                      │    ▲
                              docker stop  docker start
                                      │    │
                                      ▼    │
                                   [STOPPED]
                                      │
                                 docker rm
                                      │
                                      ▼
                                  [RIMOSSO]
```

---

## Troubleshooting

| Problema | Causa probabile | Soluzione |
|----------|-----------------|-----------|
| `port is already allocated` | La porta 3000 è già usata | Usa `-p 3001:3000` per mappare su un'altra porta host |
| `Cannot find module` | `npm install` non eseguito | Ricostruire l'immagine con `docker build` |
| Container si ferma subito | Errore nell'app | Controllare i log con `docker logs <nome>` |
| Build lenta | Layer cache invalidata | Verificare l'ordine delle istruzioni nel Dockerfile |

---

---

## Esempio: Java Spring Boot Container Dashboard

L'applicazione nella cartella `java-spring/` è una **dashboard web a tema terminale** (sfondo verde-su-nero, stile hacker) che mostra metriche JVM e di sistema in tempo reale grazie alla libreria [OSHI](https://github.com/oshi/oshi).

### Funzionalità esclusive rispetto alla dashboard Node.js

| Metrica | Descrizione |
|---------|-------------|
| **JVM Heap %** | Percentuale di heap Java usata (gauge + grafico storico) |
| **Non-Heap** | Memoria metaspace/code-cache della JVM |
| **GC Collectors** | Nome dei Garbage Collector attivi (G1, ZGC…) |
| **GC Collections** | Numero totale di collezioni GC e tempo cumulativo |
| **Thread peak** | Massimo thread live registrato dalla JVM |
| **Thread daemon** | Thread di servizio attivi |
| **Thread totali avviati** | Contatore storico |
| **Load avg** | Media del carico di sistema a 1 / 5 / 15 minuti |

### Dockerfile spiegato (multi-stage build)

```dockerfile
# Stage 1 – build: Maven + JDK compilano l'applicazione
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline          # scarica le dipendenze una volta sola
COPY src ./src
RUN mvn package -DskipTests            # produce target/*.jar

# Stage 2 – runtime: solo JRE Alpine (immagine finale ~180 MB vs ~600 MB con JDK)
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
```

> **Multi-stage build**: il codice sorgente e Maven rimangono nello stage di build; l'immagine finale contiene solo il JAR e il JRE, riducendo drasticamente la dimensione e la superficie d'attacco.

### Endpoint API

| Endpoint           | Descrizione |
|--------------------|-------------|
| `GET /`            | Dashboard HTML terminale con ApexCharts |
| `GET /api/info`    | Info statiche: hostname, Java/JVM, CPU, OS, GC collectors |
| `GET /api/metrics` | Metriche live: CPU load, Heap%, RAM, thread, GC, rete, disco |
| `GET /actuator/health` | Health check Spring Actuator |

### Avvio rapido

```bash
cd docker-container/java-spring

# Build (richiede ~3 min la prima volta per scaricare le dipendenze Maven)
docker build -t spring-dashboard:1.0 .

# Avvio
docker run -d -p 8080:8080 --name spring-dashboard spring-dashboard:1.0

# Log
docker logs -f spring-dashboard
```

Apri il browser su **http://localhost:8080** per vedere la dashboard.

### Differenze visive rispetto alla dashboard Node.js

| | Node.js Dashboard | Spring Boot Dashboard |
|---|---|---|
| **Tema** | Dark blue/purple | Terminal verde (stile hacker) |
| **Libreria grafici** | Chart.js 4 | ApexCharts 3 |
| **Metriche JVM** | No | Sì (Heap, GC, Threads) |
| **Porta default** | 3000 | 8080 |
| **Aggiornamento** | ogni 2 s | ogni 3 s |

---

## Riferimenti

- [Documentazione ufficiale Docker](https://docs.docker.com/)
- [Docker Hub – node](https://hub.docker.com/_/node)
- [Docker Hub – eclipse-temurin](https://hub.docker.com/_/eclipse-temurin)
- [Spring Boot](https://spring.io/projects/spring-boot)
- [OSHI – OS & Hardware Info for Java](https://github.com/oshi/oshi)
- [Best practices per Dockerfile](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
