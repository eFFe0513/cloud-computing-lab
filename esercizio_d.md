# 🛠️ Esercizio D: Crea il tuo Container Docker

> **Prerequisito**: completare [Esercizio B](esercizio_b.md) (gestione container esistenti).

## Obiettivo

Costruire **da zero** un container Docker con una REST API Node.js per la gestione di una
rubrica contatti. A differenza dell'Esercizio B (dove i container erano già pronti), qui
scrivi tu il codice, il `Dockerfile` e i test.

## Competenze

✅ Scrivere un `Dockerfile` da zero  
✅ Costruire un'immagine con `docker build`  
✅ Avviare e testare un container con `docker run`  
✅ Testare una REST API con `curl`  
✅ Ottimizzare un'immagine con `.dockerignore`  

## Struttura finale

```
docker-container/my-api/
├── Dockerfile          ← da scrivere
├── .dockerignore       ← da scrivere
├── package.json        ← da creare con npm init
├── server.js           ← da scrivere
└── test.sh             ← da scrivere
```

---

## Parte 1: Setup del progetto

### Step 1.1: Crea la cartella

```bash
mkdir -p docker-container/my-api
cd docker-container/my-api
```

### Step 1.2: Inizializza il progetto Node.js

```bash
npm init -y
npm install express
```

Verifica che `package.json` sia stato creato con:

```bash
cat package.json
```

---

## Parte 2: Scrivi l'applicazione

### Step 2.1: Crea `server.js`

Crea il file `server.js` con il seguente contenuto:

```js
const express = require('express');
const app = express();
app.use(express.json());

// Dati in memoria (array — non persistenti)
let contatti = [
  { id: 1, nome: 'Mario Rossi',   email: 'mario@example.com',   tel: '333-111' },
  { id: 2, nome: 'Lucia Verdi',   email: 'lucia@example.com',   tel: '333-222' },
  { id: 3, nome: 'Paolo Neri',    email: 'paolo@example.com',   tel: '333-333' },
];
let nextId = 4;

// GET /ping — health check
app.get('/ping', (req, res) => {
  res.json({ status: 'ok', contatti: contatti.length });
});

// GET /contatti — lista tutti i contatti
app.get('/contatti', (req, res) => {
  res.json(contatti);
});

// GET /contatti/:id — ottieni un contatto
app.get('/contatti/:id', (req, res) => {
  const c = contatti.find(x => x.id === Number(req.params.id));
  if (!c) return res.status(404).json({ error: 'Non trovato' });
  res.json(c);
});

// POST /contatti — crea contatto
app.post('/contatti', (req, res) => {
  const { nome, email, tel } = req.body;
  if (!nome || !email) return res.status(400).json({ error: 'nome e email sono obbligatori' });
  const nuovo = { id: nextId++, nome, email, tel: tel ?? '' };
  contatti.push(nuovo);
  res.status(201).json(nuovo);
});

// PUT /contatti/:id — aggiorna contatto
app.put('/contatti/:id', (req, res) => {
  const idx = contatti.findIndex(x => x.id === Number(req.params.id));
  if (idx === -1) return res.status(404).json({ error: 'Non trovato' });
  contatti[idx] = { ...contatti[idx], ...req.body, id: contatti[idx].id };
  res.json(contatti[idx]);
});

// DELETE /contatti/:id — elimina contatto
app.delete('/contatti/:id', (req, res) => {
  const idx = contatti.findIndex(x => x.id === Number(req.params.id));
  if (idx === -1) return res.status(404).json({ error: 'Non trovato' });
  contatti.splice(idx, 1);
  res.status(204).send();
});

const PORT = process.env.PORT ?? 3000;
app.listen(PORT, () => console.log(`API rubrica in ascolto su http://localhost:${PORT}`));
```

### Step 2.2: Aggiungi lo script di avvio a `package.json`

Modifica `package.json` aggiungendo la sezione `scripts`:

```json
"scripts": {
  "start": "node server.js"
}
```

### Step 2.3: Test in locale (senza Docker)

```bash
npm start
```

In un secondo terminale:

```bash
curl http://localhost:3000/ping
# {"status":"ok","contatti":3}
```

Ferma il server con `Ctrl+C`.

---

## Parte 3: Scrivi il Dockerfile

### Step 3.1: Crea `Dockerfile`

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]
```

> **Perché `COPY package*.json` prima di `COPY . .`?**
> Docker costruisce l'immagine a layer. Se cambia solo `server.js` (non le dipendenze),
> il layer `npm install` viene recuperato dalla **cache** — il build è molto più veloce.

### Step 3.2: Crea `.dockerignore`

```
node_modules/
npm-debug.log
*.sh
.git/
```

> `.dockerignore` impedisce di copiare `node_modules/` nell'immagine (già installati da
> `npm install` nel Dockerfile). Riduce le dimensioni e il tempo di build.

---

## Parte 4: Build e avvio

### Step 4.1: Costruisci l'immagine

```bash
docker build -t my-api:1.0 .
```

Osserva l'output: i layer vengono costruiti in sequenza. Riesegui il comando — questa
volta i layer **senza modifiche** appaiono come `CACHED`.

```bash
# Verifica che l'immagine sia stata creata
docker images my-api
```

Output atteso:

```
REPOSITORY   TAG   IMAGE ID       CREATED         SIZE
my-api       1.0   <id>           X seconds ago   ~75MB
```

### Step 4.2: Avvia il container

```bash
docker run -d --name rubrica -p 3000:3000 my-api:1.0
```

| Flag | Significato |
|------|-------------|
| `-d` | Detached: il container gira in background |
| `--name rubrica` | Nome leggibile per i comandi successivi |
| `-p 3000:3000` | Porta host 3000 → porta container 3000 |

### Step 4.3: Verifica che il container sia attivo

```bash
docker ps
docker logs rubrica
```

---

## Parte 5: Test con curl

### Step 5.1: Crea `test.sh`

```bash
#!/bin/bash
BASE="http://localhost:3000"

echo "=== Health check ==="
curl -s $BASE/ping | jq .

echo ""
echo "=== Lista contatti ==="
curl -s $BASE/contatti | jq .

echo ""
echo "=== Crea contatto ==="
NEW=$(curl -s -X POST $BASE/contatti \
  -H "Content-Type: application/json" \
  -d '{"nome":"Anna Bianchi","email":"anna@example.com","tel":"333-444"}')
echo $NEW | jq .
ID=$(echo $NEW | jq .id)

echo ""
echo "=== Leggi contatto $ID ==="
curl -s $BASE/contatti/$ID | jq .

echo ""
echo "=== Aggiorna contatto $ID ==="
curl -s -X PUT $BASE/contatti/$ID \
  -H "Content-Type: application/json" \
  -d '{"tel":"333-999"}' | jq .

echo ""
echo "=== Elimina contatto $ID ==="
curl -s -o /dev/null -w "HTTP status: %{http_code}\n" \
  -X DELETE $BASE/contatti/$ID

echo ""
echo "=== Lista finale ==="
curl -s $BASE/contatti | jq length
echo "contatti rimasti"
```

### Step 5.2: Esegui i test

```bash
chmod +x test.sh
./test.sh
```

Output atteso (riassunto):

```
=== Health check ===
{ "status": "ok", "contatti": 3 }

=== Lista contatti ===
[ ... 3 contatti ... ]

=== Crea contatto ===
{ "id": 4, "nome": "Anna Bianchi", ... }

=== Aggiorna contatto 4 ===
{ "id": 4, "tel": "333-999", ... }

=== Elimina contatto 4 ===
HTTP status: 204

=== Lista finale ===
3 contatti rimasti
```

### Step 5.3: Test manuale dei casi d'errore

```bash
# Crea contatto senza nome (deve restituire 400)
curl -s -X POST http://localhost:3000/contatti \
  -H "Content-Type: application/json" \
  -d '{"email":"x@x.com"}' | jq .

# Contatto inesistente (deve restituire 404)
curl -s http://localhost:3000/contatti/999 | jq .
```

---

## Parte 6: Ottimizzazione e osservazioni

### Step 6.1: Confronta le dimensioni

```bash
# Immagine Alpine (usata nel Dockerfile)
docker images my-api:1.0

# Prova a costruire con immagine non-Alpine per confronto
docker build -f - -t my-api:node-full . <<'EOF'
FROM node:20
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
EOF

docker images | grep my-api
```

| Immagine base | Dimensione approssimativa |
|---------------|--------------------------|
| `node:20-alpine` | ~75 MB |
| `node:20` | ~1.1 GB |

> **Alpine Linux** è una distribuzione ultra-leggera (~5 MB) pensata per container.
> Per applicazioni di produzione è la scelta standard.

### Step 6.2: Verifica il layer cache

Modifica una riga di `server.js` (es. cambia il messaggio di avvio), poi riesegui:

```bash
docker build -t my-api:1.0 .
```

Osserva quali layer usano la `CACHE` e quale viene ricostruito. Questo dimostra
l'efficacia della strategia `COPY package*.json → npm install → COPY . .`.

---

## Parte 7: Cleanup

```bash
# Ferma e rimuovi il container
docker stop rubrica
docker rm rubrica

# Rimuovi le immagini
docker rmi my-api:1.0 my-api:node-full
```

---

## Checklist C

- [ ] `server.js` con i 5 endpoint (ping, GET list, GET id, POST, PUT, DELETE)
- [ ] `Dockerfile` con strategia di cache per `package.json`
- [ ] `.dockerignore` creato
- [ ] Immagine buildabile con `docker build`
- [ ] Container avviato sulla porta 3000
- [ ] `test.sh` eseguito senza errori
- [ ] Test dei casi d'errore (400, 404)
- [ ] Confronto dimensioni `alpine` vs `node:20` documentato

## Screenshots richiesti

1. Output di `docker build` con almeno un layer `CACHED` (secondo build)
2. Output completo di `./test.sh`
3. Output di `docker images | grep my-api` con il confronto dimensioni

---

## Domande di riflessione

1. Perché i dati si perdono quando il container viene riavviato? Come si potrebbe
   aggiungere **persistenza** (suggerimento: bind mount + file JSON, o un container DB)?
2. Cosa succede se avvii due istanze del container sulla stessa porta?
3. Come cambieresti il `Dockerfile` per supportare variabili d'ambiente (es. `PORT`)?

---

## Prossimi passi

➡️ Aggiungere un secondo container `mongodb` con `docker compose` per rendere i dati
persistenti — vedi **Esercizio E** (in arrivo).
