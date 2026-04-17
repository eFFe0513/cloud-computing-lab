# 🧩 Esercizio C: Microservizi con Docker

> **Prerequisito**: completare [Esercizio B](esercizio_b.md) (gestione container esistenti).

## Obiettivo

Prendere dimestichezza con Docker costruendo un'architettura a **microservizi**:

1. **`products-service`** — API REST Node.js che gestisce un catalogo prodotti (porta 3001)
2. **`orders-service`** — API REST Node.js che gestisce gli ordini e **chiama** `products-service`
   per recuperare i dettagli dei prodotti (porta 3002)

I due servizi comunicano tra loro attraverso una **rete Docker interna**, senza esporre
`products-service` direttamente all'esterno.

## Competenze

✅ Scrivere un `Dockerfile` per un servizio Node.js  
✅ Costruire e avviare più container con `docker compose`  
✅ Fare comunicare container sulla stessa rete Docker  
✅ Consumare un'API REST da un altro container con `fetch`  
✅ Testare l'intera architettura con `curl`  

## Architettura finale

```
                        rete Docker: micro_network
                ┌─────────────────────────────────────────┐
                │                                         │
  host:3001 ───►│  products-service:3001                  │
                │  (catalogo prodotti)                    │
                │                         ▲               │
  host:3002 ───►│  orders-service:3002    │ fetch HTTP    │
                │  (gestione ordini)  ────┘               │
                │                                         │
                └─────────────────────────────────────────┘
```

> `orders-service` raggiunge `products-service` usando il nome del container come
> hostname (`http://products-service:3001`) — DNS interno di Docker.

## Struttura del repository

```
docker-container/microservices/
├── docker-compose.yml
├── products-service/
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
└── orders-service/
    ├── Dockerfile
    ├── package.json
    └── server.js
```

---

## Parte 1: Setup

### Step 1.1: Crea le cartelle

```bash
mkdir -p docker-container/microservices/products-service
mkdir -p docker-container/microservices/orders-service
cd docker-container/microservices
```

---

## Parte 2: Products Service

### Step 2.1: `products-service/package.json`

```json
{
  "name": "products-service",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.18.0" }
}
```

### Step 2.2: `products-service/server.js`

```js
const express = require('express');
const app = express();
app.use(express.json());

const products = [
  { id: 1, nome: 'Laptop',    prezzo: 999.99, disponibile: true  },
  { id: 2, nome: 'Mouse',     prezzo:  29.99, disponibile: true  },
  { id: 3, nome: 'Monitor',   prezzo: 349.99, disponibile: false },
  { id: 4, nome: 'Tastiera',  prezzo:  59.99, disponibile: true  },
];

// GET /ping
app.get('/ping', (req, res) => {
  res.json({ service: 'products-service', status: 'ok', prodotti: products.length });
});

// GET /products — lista tutti i prodotti
app.get('/products', (req, res) => {
  res.json(products);
});

// GET /products/:id — singolo prodotto
app.get('/products/:id', (req, res) => {
  const p = products.find(x => x.id === Number(req.params.id));
  if (!p) return res.status(404).json({ error: 'Prodotto non trovato' });
  res.json(p);
});

const PORT = process.env.PORT ?? 3001;
app.listen(PORT, () =>
  console.log(`[products-service] in ascolto su http://localhost:${PORT}`)
);
```

### Step 2.3: `products-service/Dockerfile`

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY server.js ./

EXPOSE 3001

CMD ["node", "server.js"]
```

---

## Parte 3: Orders Service

`orders-service` riceve gli ordini dall'utente e **contatta `products-service`** per
verificare che il prodotto esista e sia disponibile prima di confermare l'ordine.

### Step 3.1: `orders-service/package.json`

```json
{
  "name": "orders-service",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.18.0" }
}
```

### Step 3.2: `orders-service/server.js`

```js
const express = require('express');
const app = express();
app.use(express.json());

// URL del products-service: usa il nome del container come hostname
const PRODUCTS_URL = process.env.PRODUCTS_URL ?? 'http://products-service:3001';

let orders = [];
let nextId = 1;

// GET /ping
app.get('/ping', (req, res) => {
  res.json({ service: 'orders-service', status: 'ok', ordini: orders.length });
});

// GET /orders — lista tutti gli ordini
app.get('/orders', (req, res) => {
  res.json(orders);
});

// GET /orders/:id — singolo ordine
app.get('/orders/:id', (req, res) => {
  const o = orders.find(x => x.id === Number(req.params.id));
  if (!o) return res.status(404).json({ error: 'Ordine non trovato' });
  res.json(o);
});

// POST /orders — crea un ordine
// Body: { "product_id": 1, "quantita": 2, "cliente": "Mario Rossi" }
app.post('/orders', async (req, res) => {
  const { product_id, quantita, cliente } = req.body;

  if (!product_id || !quantita || !cliente) {
    return res.status(400).json({ error: 'product_id, quantita e cliente sono obbligatori' });
  }

  // ── Chiama products-service per verificare il prodotto ──
  let prodotto;
  try {
    const response = await fetch(`${PRODUCTS_URL}/products/${product_id}`);
    if (!response.ok) {
      return res.status(404).json({ error: `Prodotto ${product_id} non trovato` });
    }
    prodotto = await response.json();
  } catch (err) {
    return res.status(503).json({
      error: 'products-service non raggiungibile',
      detail: err.message,
    });
  }

  if (!prodotto.disponibile) {
    return res.status(409).json({ error: `Prodotto "${prodotto.nome}" non disponibile` });
  }

  const ordine = {
    id: nextId++,
    product_id: prodotto.id,
    nome_prodotto: prodotto.nome,
    prezzo_unitario: prodotto.prezzo,
    totale: +(prodotto.prezzo * quantita).toFixed(2),
    quantita,
    cliente,
    stato: 'confermato',
    creato_il: new Date().toISOString(),
  };

  orders.push(ordine);
  res.status(201).json(ordine);
});

// DELETE /orders/:id — cancella un ordine
app.delete('/orders/:id', (req, res) => {
  const idx = orders.findIndex(x => x.id === Number(req.params.id));
  if (idx === -1) return res.status(404).json({ error: 'Ordine non trovato' });
  orders.splice(idx, 1);
  res.status(204).send();
});

const PORT = process.env.PORT ?? 3002;
app.listen(PORT, () =>
  console.log(`[orders-service] in ascolto su http://localhost:${PORT}`)
);
```

> **Punti chiave di `orders-service`:**
>
> - Usa `fetch()` nativo di Node.js 18+ per chiamare `products-service`
> - Il nome host `products-service` viene risolto dal **DNS interno di Docker**
>   (corrisponde al nome del servizio nel `docker-compose.yml`)
> - Gestisce il caso in cui `products-service` sia irraggiungibile (errore 503)
> - Verifica che il prodotto sia `disponibile` prima di accettare l'ordine (errore 409)

### Step 3.3: `orders-service/Dockerfile`

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY server.js ./

EXPOSE 3002

CMD ["node", "server.js"]
```

---

## Parte 4: docker-compose.yml

### Step 4.1: Crea `docker-compose.yml`

```yaml
services:

  products-service:
    build: ./products-service
    image: micro_products:latest
    container_name: products-service
    networks:
      - micro_network
    ports:
      - "3001:3001"
    restart: unless-stopped

  orders-service:
    build: ./orders-service
    image: micro_orders:latest
    container_name: orders-service
    depends_on:
      - products-service
    environment:
      PRODUCTS_URL: http://products-service:3001
    networks:
      - micro_network
    ports:
      - "3002:3002"
    restart: unless-stopped

networks:
  micro_network:
    driver: bridge
```

> **Come funziona la comunicazione tra container:**
>
> | Proprietà | Valore | Spiegazione |
> |-----------|--------|-------------|
> | `networks: micro_network` | stesso valore su entrambi i servizi | li mette sulla stessa rete virtuale |
> | `PRODUCTS_URL` | `http://products-service:3001` | Docker risolve `products-service` con l'IP del container |
> | `depends_on` | `products-service` | `orders-service` parte solo dopo `products-service` |
> | `ports` | `"3001:3001"` / `"3002:3002"` | espone le porte sull'host per il testing |

### Step 4.2: Avvia i servizi

```bash
docker compose up -d --build
```

Verifica che entrambi i container siano attivi:

```bash
docker compose ps
```

Output atteso:

```
NAME                SERVICE             STATUS    PORTS
orders-service      orders-service      running   0.0.0.0:3002->3002/tcp
products-service    products-service    running   0.0.0.0:3001->3001/tcp
```

Controlla i log:

```bash
docker compose logs
```

---

## Parte 5: Test

### Step 5.1: Health check di entrambi i servizi

```bash
curl http://localhost:3001/ping | jq .
# {"service":"products-service","status":"ok","prodotti":4}

curl http://localhost:3002/ping | jq .
# {"service":"orders-service","status":"ok","ordini":0}
```

### Step 5.2: Lista prodotti disponibili

```bash
curl http://localhost:3001/products | jq .
```

### Step 5.3: Crea un ordine (prodotto disponibile)

```bash
curl -s -X POST http://localhost:3002/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "quantita": 2, "cliente": "Mario Rossi"}' | jq .
```

Output atteso:

```json
{
  "id": 1,
  "product_id": 1,
  "nome_prodotto": "Laptop",
  "prezzo_unitario": 999.99,
  "totale": 1999.98,
  "quantita": 2,
  "cliente": "Mario Rossi",
  "stato": "confermato",
  "creato_il": "2026-04-17T..."
}
```

> **Cosa sta succedendo dietro le quinte:**
> `orders-service` ha chiamato `http://products-service:3001/products/1` attraverso la
> rete Docker, ha verificato che il prodotto esiste e sia disponibile, poi ha creato
> l'ordine con i dati arricchiti (nome, prezzo) provenienti dal catalogo.

### Step 5.4: Tenta un ordine su prodotto non disponibile (Monitor — id 3)

```bash
curl -s -X POST http://localhost:3002/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id": 3, "quantita": 1, "cliente": "Lucia Verdi"}' | jq .
```

Output atteso (errore 409):

```json
{
  "error": "Prodotto \"Monitor\" non disponibile"
}
```

### Step 5.5: Tenta un ordine su prodotto inesistente

```bash
curl -s -X POST http://localhost:3002/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id": 99, "quantita": 1, "cliente": "Paolo Neri"}' | jq .
```

Output atteso (errore 404):

```json
{
  "error": "Prodotto 99 non trovato"
}
```

### Step 5.6: Lista ordini

```bash
curl http://localhost:3002/orders | jq .
```

### Step 5.7: Script di test automatico

Crea `test.sh` nella cartella `microservices/`:

```bash
#!/bin/bash
set -e
P="http://localhost:3001"
O="http://localhost:3002"

echo "=== [1] Health check ==="
curl -sf $P/ping | jq .name
curl -sf $O/ping | jq .name

echo ""
echo "=== [2] Prodotti disponibili ==="
curl -sf $P/products | jq '[.[] | select(.disponibile==true) | .nome]'

echo ""
echo "=== [3] Ordine su prodotto disponibile (Laptop) ==="
curl -sf -X POST $O/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id":1,"quantita":2,"cliente":"Test User"}' | jq '{id, nome_prodotto, totale, stato}'

echo ""
echo "=== [4] Ordine su prodotto NON disponibile (Monitor) ==="
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST $O/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id":3,"quantita":1,"cliente":"Test User"}'

echo ""
echo "=== [5] Ordine su prodotto INESISTENTE ==="
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST $O/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id":99,"quantita":1,"cliente":"Test User"}'

echo ""
echo "=== [6] Lista ordini ==="
curl -sf $O/orders | jq 'length'
echo "ordini creati"

echo ""
echo "✅ Tutti i test superati"
```

```bash
chmod +x test.sh
./test.sh
```

---

## Parte 6: Osservazioni sull'architettura

### Step 6.1: Ispeziona la rete Docker

```bash
# Visualizza la rete creata da docker compose
docker network ls | grep micro

# Dettagli: vedi i container collegati e i loro IP
docker network inspect microservices_micro_network
```

### Step 6.2: Verifica il DNS interno

Entra nel container `orders-service` e verifica che riesca a raggiungere
`products-service` per nome:

```bash
docker exec -it orders-service sh
# Dentro il container:
wget -qO- http://products-service:3001/ping
exit
```

### Step 6.3: Simula il crash di products-service

```bash
# Ferma solo products-service
docker compose stop products-service

# Prova a creare un ordine
curl -s -X POST http://localhost:3002/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id":1,"quantita":1,"cliente":"Test"}' | jq .
# Atteso: {"error":"products-service non raggiungibile",...}

# Ripristina
docker compose start products-service
```

> Questo dimostra la necessità di **circuit breaker** e **retry logic** nelle architetture
> a microservizi reali.

---

## Parte 7: Cleanup

```bash
docker compose down

# Rimuovi anche le immagini
docker rmi micro_products:latest micro_orders:latest
```

---

## Checklist C

- [ ] `products-service/server.js` con endpoint GET `/ping`, `/products`, `/products/:id`
- [ ] `orders-service/server.js` che chiama `products-service` via HTTP
- [ ] Gestione errori: prodotto non trovato (404), non disponibile (409), servizio down (503)
- [ ] `docker-compose.yml` con rete condivisa e `depends_on`
- [ ] Entrambi i container avviati con `docker compose up -d --build`
- [ ] `./test.sh` eseguito con successo
- [ ] Step 6.3 (crash simulation) eseguito e risultato documentato

## Screenshots richiesti

1. Output di `docker compose ps` con entrambi i servizi `running`
2. Output di `./test.sh` completo
3. Output di `docker network inspect` con i due container collegati
4. Risposta HTTP 503 ottenuta fermando `products-service` (Step 6.3)

---

## Domande di riflessione

1. Perché `orders-service` usa il nome `products-service` come hostname invece di
   `localhost` o un indirizzo IP?
2. Cosa succederebbe se avviassimo più istanze di `products-service`? Come cambierebbe
   il `docker-compose.yml`?
3. Qual è il vantaggio di avere due servizi separati rispetto a un'unica applicazione
   monolitica?
4. Come si potrebbe aggiungere la **persistenza** agli ordini senza modificare
   `products-service`?

---

## Prossimi passi

➡️ [Esercizio D](esercizio_d.md) — costruire il proprio container da zero con Dockerfile
personalizzato e ottimizzazione delle immagini.
