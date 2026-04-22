# Docker Multi-Stage Build

## Cos'è un Multi-Stage Build?

Il **multi-stage build** è una tecnica Docker che permette di usare **più immagini base** nello stesso Dockerfile, copiando solo gli artifact necessari tra gli stage. Questo riduce drasticamente la dimensione finale dell'immagine.

### Problema: Immagini Docker Troppo Grandi

```dockerfile
# ❌ BAD: Immagine finale include build tools (Maven, npm, compiler)
FROM maven:3.9-eclipse-temurin-21
WORKDIR /app
COPY . .
RUN mvn package
CMD ["java", "-jar", "target/app.jar"]
```

**Risultato**: Immagine finale **800 MB+** (include Maven, cache, source code)

### Soluzione: Multi-Stage Build

```dockerfile
# ✅ GOOD: Build stage separato da runtime stage
# STAGE 1: Build
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn package -DskipTests

# STAGE 2: Runtime
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/app.jar app.jar
CMD ["java", "-jar", "app.jar"]
```

**Risultato**: Immagine finale **180 MB** (solo JRE + JAR)

---

## Vantaggi Multi-Stage Build

✅ **Immagini più piccole** → Deploy più veloci  
✅ **Meno superficie di attacco** → Più sicuro (no build tools in produzione)  
✅ **Build riproducibili** → Stessa versione build tools ovunque  
✅ **Separazione build/runtime** → Architettura più pulita  

---

## Esempio Completo: Node.js + Java

### Dockerfile Multi-Runtime

```dockerfile
#───────────────────────────────────────────────────────────
# STAGE 1: Node.js Build
#───────────────────────────────────────────────────────────
FROM node:20-alpine AS node-builder
WORKDIR /app/nodejs
COPY nodejs-app/package*.json ./
RUN npm ci --only=production
COPY nodejs-app/ ./
RUN npm run build  # Se hai un build step (es. TypeScript)

#───────────────────────────────────────────────────────────
# STAGE 2: Java Build
#───────────────────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-21 AS java-builder
WORKDIR /app/java
COPY java-app/pom.xml ./
# Download dependencies (cachable layer)
RUN mvn dependency:go-offline
COPY java-app/src ./src
RUN mvn package -DskipTests

#───────────────────────────────────────────────────────────
# STAGE 3: Runtime Multi-Runtime
#───────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-jammy

# Install Node.js in the JRE image
RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Node.js app
WORKDIR /app/nodejs
COPY --from=node-builder /app/nodejs ./

# Copy Java app
WORKDIR /app/java
COPY --from=java-builder /app/java/target/*.jar app.jar

# Default working directory
WORKDIR /app

# Expose ports
EXPOSE 3000 8080

# Start script (run both apps)
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh
CMD ["/app/start.sh"]
```

### start.sh

```bash
#!/bin/bash
set -e

echo "🚀 Starting multi-runtime container..."

# Start Java app in background
echo "▶️  Starting Java app (port 8080)..."
java -jar /app/java/app.jar &

# Start Node.js app in foreground
echo "▶️  Starting Node.js app (port 3000)..."
cd /app/nodejs
node server.js
```

---

## Best Practices Multi-Stage Build

### 1. Ordina i Comandi per Layer Caching

```dockerfile
# ✅ GOOD: Files che cambiano raramente prima
COPY package*.json ./      # Cambia solo se aggiungi dipendenze
RUN npm ci
COPY src/ ./src/           # Cambia spesso (codice)
```

```dockerfile
# ❌ BAD: Ogni modifica al codice invalida cache dipendenze
COPY . .
RUN npm install
```

### 2. Usa Immagini Alpine per Runtime

```dockerfile
# ❌ BAD: 1.5 GB
FROM node:20

# ✅ GOOD: 180 MB
FROM node:20-alpine
```

### 3. Multi-Platform Build

```dockerfile
# Build per AMD64 e ARM64 (Apple Silicon, Raspberry Pi)
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest .
```

### 4. Named Stages per Testing

```dockerfile
FROM node:20-alpine AS development
# ...dev dependencies...

FROM node:20-alpine AS test
COPY --from=development /app /app
RUN npm test

FROM node:20-alpine AS production
COPY --from=development /app/dist /app
# ...only production files...
```

---

## Confronto: Single-Stage vs Multi-Stage

| Aspetto | Single-Stage | Multi-Stage |
|---------|--------------|-------------|
| **Dimensione** | 800 MB+ | 180 MB |
| **Sicurezza** | Build tools in prod ❌ | Solo runtime ✅ |
| **Build time** | Più veloce (1 stage) | Più lento (cache aiuta) |
| **Complessità** | Semplice | Moderata |
| **Use case** | Dev/test rapidi | Production |

---

## Esercizio Pratico

Crea un Dockerfile multi-stage per questa app Node.js:

```dockerfile
# TODO: Completa il Dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
# ... inserisci comandi build ...

FROM node:20-alpine
WORKDIR /app
# ... inserisci comandi runtime ...
CMD ["node", "server.js"]
```

**Requisiti**:
- Stage 1: Installa dipendenze e builda (se hai TypeScript)
- Stage 2: Copia solo `node_modules` (production) e file compilati
- Immagine finale < 200 MB

---

## Debugging Multi-Stage Build

```bash
# Build fino a uno stage specifico
docker build --target builder -t myapp:builder .

# Entra nel builder stage per debug
docker run -it myapp:builder sh

# Verifica dimensione ogni stage
docker images | grep myapp
```

---

## 📚 Risorse

- [Docker Multi-Stage Build Docs](https://docs.docker.com/build/building/multi-stage/)
- [Node.js Docker Best Practices](https://snyk.io/blog/10-best-practices-to-containerize-nodejs-web-applications-with-docker/)
- [Java Docker Best Practices](https://www.docker.com/blog/9-tips-for-containerizing-your-spring-boot-code/)
