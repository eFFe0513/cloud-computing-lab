FROM python:3.11-slim

# ffmpeg: conversione audio per Groq Whisper
# curl: healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Layer cache: installa dipendenze prima di copiare il codice
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copia il codice applicativo
COPY . .

# Crea cartella per dati persistenti (storage opzionale)
RUN mkdir -p data

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:8000/api/status || exit 1

CMD ["python", "main.py"]
