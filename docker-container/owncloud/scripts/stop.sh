#!/bin/bash
# Script per fermare lo stack OwnCloud

echo "🛑 Arresto dello stack OwnCloud..."

# Naviga nella directory dello script
cd "$(dirname "$0")/.." || exit 1

# Ferma lo stack
docker-compose down

echo "✅ Stack fermato!"
