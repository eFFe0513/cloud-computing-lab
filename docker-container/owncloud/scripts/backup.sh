#!/bin/bash
# Script per il backup di OwnCloud

echo "💾 Backup OwnCloud in corso..."

# Naviga nella directory dello script
cd "$(dirname "$0")/.." || exit 1

# Crea la directory backup se non esiste
mkdir -p backup

# Data corrente per il nome del file
DATE=$(date +%Y%m%d_%H%M%S)

echo "📦 Backup del database..."
docker exec owncloud_mariadb mysqldump -u owncloud --password=owncloud owncloud > backup/owncloud-db-${DATE}.sql

if [ $? -eq 0 ]; then
    echo "✅ Backup database completato: backup/owncloud-db-${DATE}.sql"
else
    echo "❌ Errore nel backup del database"
    exit 1
fi

echo ""
echo "📦 Backup dei file (volume files)..."
docker run --rm -v owncloud_files:/data -v $(pwd)/backup:/backup ubuntu tar czf /backup/owncloud-files-${DATE}.tar.gz -C /data .

if [ $? -eq 0 ]; then
    echo "✅ Backup files completato: backup/owncloud-files-${DATE}.tar.gz"
else
    echo "❌ Errore nel backup dei files"
    exit 1
fi

echo ""
echo "📦 Backup di Redis (volume redis)..."
docker run --rm -v owncloud_redis:/data -v $(pwd)/backup:/backup ubuntu tar czf /backup/owncloud-redis-${DATE}.tar.gz -C /data .

if [ $? -eq 0 ]; then
    echo "✅ Backup Redis completato: backup/owncloud-redis-${DATE}.tar.gz"
else
    echo "❌ Errore nel backup di Redis"
    exit 1
fi

echo ""
echo "✅ Backup completato con successo!"
echo "📂 I file di backup sono in: backup/"
echo ""
ls -lh backup/*${DATE}*
