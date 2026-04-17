#!/bin/bash
# Script per avviare lo stack OwnCloud

echo "🚀 Avvio dello stack OwnCloud..."

# Naviga nella directory dello script
cd "$(dirname "$0")/.." || exit 1

# Verifica che i file necessari esistano
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Errore: file docker-compose.yml non trovato"
    exit 1
fi

if [ ! -f "owncloud-server.env" ]; then
    echo "❌ Errore: file owncloud-server.env non trovato"
    exit 1
fi

# Verifica che la rete nginx-proxy-network esista
if ! docker network ls | grep -q "nginx-proxy-network"; then
    echo "⚠️  Rete nginx-proxy-network non trovata. Creazione in corso..."
    docker network create nginx-proxy-network
fi

# Avvia lo stack
docker-compose --env-file owncloud-server.env up -d

# Attendi qualche secondo
echo "⏳ Attendo l'avvio dei container..."
sleep 5

# Verifica lo stato
echo ""
echo "📊 Stato dei container:"
docker-compose -f owncloud-docker-compose.yml ps

echo ""
echo "✅ Stack avviato!"
echo "🌐 Accedi a: http://localhost:8081"
echo ""
echo "Per visualizzare i log: docker-compose -f owncloud-docker-compose.yml logs -f"
