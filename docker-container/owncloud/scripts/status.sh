#!/bin/bash
# Script per verificare lo stato di OwnCloud

echo "🔍 Verifica dello stack OwnCloud"
echo ""

# Naviga nella directory dello script
cd "$(dirname "$0")/.." || exit 1

echo "📊 Stato dei container:"
docker-compose ps

echo ""
echo "💚 Health check:"
echo -n "OwnCloud Server: "
docker inspect --format='{{.State.Health.Status}}' owncloud_server 2>/dev/null || echo "non disponibile"
echo -n "MariaDB: "
docker inspect --format='{{.State.Health.Status}}' owncloud_mariadb 2>/dev/null || echo "non disponibile"
echo -n "Redis: "
docker inspect --format='{{.State.Health.Status}}' owncloud_redis 2>/dev/null || echo "non disponibile"

echo ""
echo "💾 Volumi:"
docker volume ls | grep owncloud

echo ""
echo "📈 Utilizzo risorse:"
docker stats --no-stream owncloud_server owncloud_mariadb owncloud_redis 2>/dev/null || echo "Container non in esecuzione"

echo ""
echo "🌐 URL di accesso:"
echo "- HTTPS: https://owncloud.filippobilardo.it"
echo "- Certificato: Let's Encrypt (automatico)"
