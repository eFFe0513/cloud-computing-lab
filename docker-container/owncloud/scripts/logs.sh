#!/bin/bash
# Script per visualizzare i log di OwnCloud

# Naviga nella directory dello script
cd "$(dirname "$0")/.." || exit 1

echo "📋 Log dello stack OwnCloud"
echo "Premi CTRL+C per uscire"
echo ""

# Visualizza i log in tempo reale
docker-compose logs -f
