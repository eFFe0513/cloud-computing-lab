# 🤖 Esercizio E: Agente AI con Agno, Mistral e Telegram

> **Prerequisito**: completare [Esercizio B](esercizio_b.md) (gestione container esistenti).

## Obiettivo

Costruire e avviare un agente AI completo nel container `FbClaw`, già presente nel
repository, composto da:

| Componente | Tecnologia | Ruolo |
|------------|-----------|-------|
| **Framework agente** | [Agno](https://github.com/agno-agi/agno) | Orchestrazione LLM + memoria conversazione |
| **LLM** | Mistral (`mistral-large-latest`) | Generazione risposte intelligenti |
| **Trascrizione audio** | Groq Whisper (`whisper-large-v3`) | Audio → testo in millisecondi |
| **Bot Telegram** | python-telegram-bot | Interfaccia via chat Telegram |
| **Web interface** | FastAPI + HTML/JS | Chat da browser |

## Architettura

```
                    ┌─────────────────────────────────────────┐
                    │         Container: fbclaw:8000          │
                    │                                         │
  Browser  ────────►│  FastAPI (main.py)                      │
                    │   ├── GET  /                (web UI)    │
  Telegram ────────►│   ├── POST /api/chat        (testo)     │──► Mistral API
                    │   ├── POST /api/voice       (audio)     │──► Groq Whisper API
                    │   └── POST /api/transcribe  (solo ASR)  │
                    │                                         │
                    │  Agno Agent (agent.py)                  │
                    │   └── cronologia per session_id         │
                    │                                         │
                    │  Telegram Bot (telegram_bot.py)         │
                    │   └── thread daemon in background       │
                    └─────────────────────────────────────────┘
```

## Struttura del container

```
docker-container/FbClaw/
├── Dockerfile              ← python:3.11-slim + ffmpeg
├── docker-compose.yml
├── .env.example            ← template credenziali
├── .dockerignore
├── requirements.txt        ← agno, mistralai, groq, python-telegram-bot, fastapi
├── agent.py                ← sessioni Agno in memoria
├── main.py                 ← FastAPI + avvio bot Telegram
├── telegram_bot.py         ← handler testo + note vocali
└── static/
    ├── index.html          ← interfaccia chat web
    └── app.js              ← logica client (fetch + MediaRecorder)
```

---

## Parte 1: Ottieni le API key

### Step 1.1: Mistral API key

1. Vai su [console.mistral.ai](https://console.mistral.ai)
2. Registrati (o accedi) → **API Keys** → **Create new key**
3. Copia la chiave (inizia con `...`)

> Mistral offre crediti gratuiti per i nuovi account. Il modello `mistral-large-latest`
> è il più capace; per risparmiare crediti usa `mistral-small-latest`.

### Step 1.2: Groq API key (per la trascrizione audio)

1. Vai su [console.groq.com](https://console.groq.com)
2. Registrati → **API Keys** → **Create API Key**
3. Copia la chiave (inizia con `gsk_...`)

> Groq offre un tier gratuito generoso. Whisper `large-v3` trascrive ~1 min di audio
> in meno di 1 secondo.

### Step 1.3: Token Telegram Bot (opzionale)

1. Apri Telegram e cerca **@BotFather**
2. Invia `/newbot` → scegli nome e username (es. `fbclaw_tuonome_bot`)
3. Copia il token (es. `7123456789:AAF...`)

> Il bot Telegram è opzionale: se lasci `TELEGRAM_BOT_TOKEN=` vuoto nel `.env`,
> il container si avvia ugualmente con solo l'interfaccia web.

---

## Parte 2: Configurazione

### Step 2.1: Vai nella cartella del container

```bash
cd docker-container/FbClaw
```

### Step 2.2: Crea il file `.env`

```bash
cp .env.example .env
```

Apri `.env` e inserisci le tue chiavi:

```bash
# Linux/Codespace
nano .env
# oppure
code .env
```

```env
MISTRAL_API_KEY=la_tua_chiave_mistral
MISTRAL_MODEL=mistral-large-latest

GROQ_API_KEY=gsk_la_tua_chiave_groq

TELEGRAM_BOT_TOKEN=123456789:AAF...   # opzionale, lascia vuoto se non configurato
```

> **Sicurezza**: `.env` è nel `.gitignore` — le chiavi non vengono mai committate.

---

## Parte 3: Analisi del codice

Prima di avviare il container, esplora i file per capire come funziona.

### Step 3.1: `agent.py` — Gestione sessioni Agno

```python
# Ogni conversazione è identificata da un session_id
# L'Agent mantiene la cronologia degli ultimi 10 scambi in memoria

agent = Agent(
    model=MistralChat(id="mistral-large-latest"),
    add_history_to_messages=True,  # passa la cronologia a ogni chiamata
    num_history_responses=10,
)
response = agent.run("Ciao!")
print(response.content)            # risposta testuale
```

> **Cosa fa Agno**: wrappa la chiamata all'API Mistral aggiungendo automaticamente
> il contesto della conversazione precedente. Senza Agno, dovresti gestire tu
> l'array dei messaggi.

### Step 3.2: `main.py` — API REST con FastAPI

Tre endpoint principali:

| Endpoint | Metodo | Input | Output |
|----------|--------|-------|--------|
| `/api/chat` | POST | `{message, session_id}` | `{response}` |
| `/api/voice` | POST | `audio file + session_id` | `{transcription, response}` |
| `/api/transcribe` | POST | `audio file` | `{text}` |

### Step 3.3: `telegram_bot.py` — Bot Telegram

Il bot gira come **thread daemon** nella stessa istanza del server FastAPI.
Ogni utente Telegram ha il proprio `session_id` (`tg-<user_id>`), separato
dal session_id web.

Pipeline nota vocale Telegram:
```
Utente invia nota vocale
  → Telegram serve il file OGG
  → download_as_bytearray()
  → groq_client.audio.transcriptions.create(file=("voice.ogg", bytes))
  → agent.run(f"[Nota vocale]: {transcription}")
  → reply_text(response.content)
```

### Step 3.4: `static/app.js` — Registrazione audio nel browser

Il browser usa la **Web API MediaRecorder** per registrare l'audio:

```javascript
const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
const mediaRecorder = new MediaRecorder(stream, { mimeType: 'audio/webm' });

mediaRecorder.onstop = async () => {
    const blob = new Blob(audioChunks, { type: 'audio/webm' });
    // Invia come FormData a /api/voice
};
mediaRecorder.start();
```

---

## Parte 4: Build e avvio

### Step 4.1: Costruisci e avvia il container

```bash
docker compose up -d --build
```

Output atteso:

```
[+] Building ...
 ✔ fbclaw  Built
[+] Running 1/1
 ✔ Container fbclaw  Started
```

### Step 4.2: Controlla i log

```bash
docker compose logs -f
```

Dovresti vedere:

```
fbclaw  | [FbClaw] Bot Telegram avviato in background     ← se token configurato
fbclaw  | [Telegram] Bot avviato, in attesa di messaggi...
fbclaw  | INFO:     Started server process
fbclaw  | INFO:     Uvicorn running on http://0.0.0.0:8000
```

### Step 4.3: Verifica lo stato

```bash
curl http://localhost:8000/api/status | jq .
```

Output atteso:

```json
{
  "status": "ok",
  "model": "mistral-large-latest",
  "telegram_enabled": true,
  "active_sessions": 0
}
```

---

## Parte 5: Test dell'interfaccia web

### Step 5.1: Apri il browser

In GitHub Codespaces, il port forwarding si apre automaticamente. Altrimenti:

```
http://localhost:8000
```

### Step 5.2: Invia un messaggio di testo

1. Scrivi nella casella di testo: `Ciao! Puoi spiegarmi cosa sono i container Docker?`
2. Premi **Invio** o clicca **↑**
3. Attendi la risposta dell'agente (indicatore di typing animato)

### Step 5.3: Usa le quick chip

Clicca sulle chip nella schermata iniziale (es. **🐳 Dockerfile**) — invia messaggi
precompilati per testare rapidamente.

### Step 5.4: Testa la memoria della conversazione

```
Tu:    Che linguaggio di programmazione preferisci?
AI:    [risposta]
Tu:    Perché hai scelto proprio quello?
AI:    [risposta contestuale — deve ricordare la risposta precedente]
```

> Se l'agente ricorda il contesto, la cronologia funziona correttamente.

### Step 5.5: Nuova chat

Clicca su **+ Nuova chat** — il server azzera la sessione e l'agente
dimentica la conversazione precedente.

---

## Parte 6: Test della trascrizione vocale

### Step 6.1: Registra una nota vocale nel browser

1. Clicca sul pulsante 🎙️ nella barra di input
2. Parla chiaramente: *"Spiegami come funziona Docker Compose"*
3. Clicca ⏹️ per fermare la registrazione
4. Attendi: prima appare il testo trascritto, poi la risposta dell'agente

### Step 6.2: Test con `curl` (file audio)

Crea un file audio di test (o usa uno qualsiasi in formato MP3/WAV/WebM):

```bash
# Solo trascrizione (senza inviare all'agente)
curl -s -X POST http://localhost:8000/api/transcribe \
  -F "audio=@/percorso/al/file.mp3" | jq .

# Trascrizione + risposta agente
curl -s -X POST http://localhost:8000/api/voice \
  -F "audio=@/percorso/al/file.mp3" \
  -F "session_id=test-curl" | jq .
```

---

## Parte 7: Test del bot Telegram

> Salta questa parte se non hai configurato `TELEGRAM_BOT_TOKEN`.

### Step 7.1: Avvia il bot

1. Apri Telegram sul tuo telefono o desktop
2. Cerca il tuo bot per username (es. `@fbclaw_tuonome_bot`)
3. Premi **Start** o invia `/start`

### Step 7.2: Invia messaggi

```
/start         → messaggio di benvenuto
Ciao!          → risposta dell'agente
/info          → modello e configurazione
```

### Step 7.3: Invia una nota vocale

1. Tieni premuto il pulsante 🎙️ in Telegram
2. Parla brevemente
3. Rilascia per inviare
4. Il bot risponde con il testo trascritto + risposta dell'agente

### Step 7.4: Reset conversazione

```
/reset         → azzera la cronologia (solo per il tuo utente)
```

---

## Parte 8: Esplora e modifica

### Step 8.1: Cambia il modello Mistral

Modifica `.env`:

```env
MISTRAL_MODEL=mistral-small-latest
```

Poi riavvia:

```bash
docker compose restart
```

Confronta la qualità delle risposte tra `mistral-large-latest` e `mistral-small-latest`.

### Step 8.2: Modifica la personalità dell'agente

Apri `agent.py` e modifica il campo `description` o le `instructions`:

```python
description="Sei FbClaw, un assistente sarcastico ma utile...",
instructions=[
    "Rispondi sempre in rima.",
    ...
],
```

Ricostruisci l'immagine:

```bash
docker compose up -d --build
```

### Step 8.3: Aggiungi un endpoint personalizzato

Aggiungi a `main.py` un endpoint `/api/summary` che chiede all'agente
di riassumere la conversazione corrente:

```python
@app.post("/api/summary")
async def summary(req: ResetRequest):
    agent = get_or_create_agent(req.session_id)
    response = agent.run("Fai un riassunto in 3 punti della nostra conversazione.", stream=False)
    return {"summary": response.content}
```

---

## Parte 9: Cleanup

```bash
docker compose down

# Rimuovi l'immagine
docker rmi fbclaw:latest
```

---

## Checklist E

- [ ] `.env` creato con chiavi Mistral e Groq valide
- [ ] Container avviato senza errori (`docker compose up -d --build`)
- [ ] `GET /api/status` restituisce `"status": "ok"`
- [ ] Chat testuale funzionante via browser
- [ ] Memoria della conversazione verificata (multi-turn)
- [ ] Nota vocale registrata dal browser e trascritta correttamente
- [ ] (Opzionale) Bot Telegram risponde a testo e note vocali
- [ ] Step 8.1: confronto modelli documentato
- [ ] Step 8.2 o 8.3: una modifica al codice implementata e testata

## Screenshots richiesti

1. `docker compose logs` con il server avviato e (se configurato) il bot Telegram
2. Output di `curl /api/status`
3. Conversazione multi-turn nel browser (almeno 4 scambi)
4. Una nota vocale trascritta — mostra il testo della trascrizione e la risposta
5. (Opzionale) Screenshot della chat Telegram con una nota vocale

---

## Domande di riflessione

1. Perché i dati delle sessioni si perdono al riavvio del container? Come
   si potrebbe aggiungere **persistenza** (suggerimento: Agno supporta
   `SqliteAgentStorage` per salvare le sessioni su file)?

2. Il bot Telegram e il server FastAPI girano nello **stesso processo Python**.
   Quali problemi potrebbe causare questa scelta in produzione? Come si separa
   in due container distinti?

3. Cosa succede se `GROQ_API_KEY` non è configurata e un utente invia una nota
   vocale? Come miglioreresti la gestione dell'errore?

4. Come implementeresti l'**autenticazione** per il bot Telegram, limitandone
   l'accesso solo a certi `user_id`?

---

## Prossimi passi

- Aggiungere **tools** all'agente Agno (ricerca web, calcolatrice, accesso a database)
- Sostituire la memoria in-memory con **SQLite persistente** via `SqliteAgentStorage`
- Aggiungere **streaming** della risposta per visualizzare il testo parola per parola
- Deploy su cloud (es. Azure Container Apps, Fly.io)
