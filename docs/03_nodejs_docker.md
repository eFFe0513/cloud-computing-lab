# Node.js in Docker: Best Practices

## Dockerfile Base per Node.js

### Versione Semplice (Development)

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

### Versione Ottimizzata (Production)

```dockerfile
# Multi-stage build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER node
EXPOSE 3000
CMD ["node", "server.js"]
```

---

## Best Practices Node.js + Docker

### 1. Usa `.dockerignore`

```
node_modules
npm-debug.log
.env
.git
.vscode
coverage
dist
*.md
```

### 2. Security: Non Usare Root User

```dockerfile
# ❌ BAD: App gira come root
CMD ["node", "server.js"]

# ✅ GOOD: App gira come user "node"
USER node
CMD ["node", "server.js"]
```

### 3. Gestione Segnali (Graceful Shutdown)

```javascript
// server.js
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({ message: 'Hello from Node.js!' });
});

const server = app.listen(3000, () => {
  console.log('✅ Server running on port 3000');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, closing server...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});
```

### 4. Health Check

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
USER node
EXPOSE 3000

# Health check every 30s
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

CMD ["node", "server.js"]
```

```javascript
// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});
```

---

## Esempio Completo: Express REST API

### package.json

```json
{
  "name": "nodejs-docker-app",
  "version": "1.0.0",
  "description": "Node.js app in Docker",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  }
}
```

### server.js

```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Routes
app.get('/', (req, res) => {
  res.json({ 
    message: 'Node.js API running in Docker',
    version: process.env.npm_package_version 
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});

app.get('/api/users', (req, res) => {
  res.json([
    { id: 1, name: 'Alice' },
    { id: 2, name: 'Bob' }
  ]);
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`✅ Server running on http://localhost:${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM signal received');
  server.close(() => {
    console.log('✅ HTTP server closed');
    process.exit(0);
  });
});
```

### Dockerfile

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY server.js package.json ./
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"
CMD ["node", "server.js"]
```

---

## Build e Run

```bash
# Build immagine
docker build -t nodejs-api:1.0 .

# Run container
docker run -d -p 3000:3000 --name nodejs-api nodejs-api:1.0

# Test
curl http://localhost:3000
curl http://localhost:3000/api/users

# Logs
docker logs -f nodejs-api

# Stop
docker stop nodejs-api
docker rm nodejs-api
```

---

## Docker Compose per Development

```yaml
version: '3.8'
services:
  nodejs-app:
    build: ./nodejs-app
    ports:
      - "3000:3000"
    volumes:
      - ./nodejs-app:/app
      - /app/node_modules  # Persist node_modules
    environment:
      - NODE_ENV=development
    command: npm run dev
```

```bash
# Start in dev mode
docker-compose up

# Rebuild after package.json changes
docker-compose up --build
```

---

## Ottimizzazione Dimensione Immagine

| Tecnica | Dimensione Risparmiata |
|---------|------------------------|
| Usa `alpine` invece di `node:20` | ~600 MB |
| Multi-stage build | ~300 MB |
| `npm ci` invece di `npm install` | ~50 MB |
| `.dockerignore` | ~100 MB |

```bash
# Confronto dimensioni
docker images | grep nodejs-api
# nodejs-api:basic     1.2 GB
# nodejs-api:optimized 180 MB
```

---

## 📚 Risorse

- [Node.js Docker Best Practices](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md)
- [Express.js Production Best Practices](https://expressjs.com/en/advanced/best-practice-performance.html)
