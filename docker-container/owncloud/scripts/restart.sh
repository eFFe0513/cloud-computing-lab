#!/bin/bash
# Script per riavviare lo stack OwnCloud

echo "🔄 Riavvio dello stack OwnCloud..."

# Naviga nella directory dello script
cd "$(dirname "$0")/.." || exit 1

# Riavvia lo stack
docker-compose restart

# Attendi qualche secondo
echo "⏳ Attendo il riavvio dei container..."
sleep 5

# Verifica lo stato
echo ""
echo "📊 Stato dei container:"
docker-compose -f owncloud-docker-compose.yml ps

echo ""
echo "✅ Stack riavviato!"
