#!/bin/bash
# Script per testare il setup OwnCloud con nginx-proxy

echo "🧪 Test Setup OwnCloud con nginx-proxy"
echo "========================================"
echo ""

cd "$(dirname "$0")/.." || exit 1

# Colori
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contatore test
PASSED=0
FAILED=0

# Funzione per test
test_check() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $2"
        ((FAILED++))
        return 1
    fi
}

echo "1️⃣  Verifica File di Configurazione"
echo "-----------------------------------"

# Test file docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    test_check 0 "File docker-compose.yml presente"
else
    test_check 1 "File docker-compose.yml presente"
fi

# Test file .env
if [ -f "owncloud-server.env" ]; then
    test_check 0 "File owncloud-server.env presente"
else
    test_check 1 "File owncloud-server.env presente"
fi

echo ""
echo "2️⃣  Verifica Rete Docker"
echo "----------------------"

# Test rete nginx-proxy-network
if docker network ls | grep -q "nginx-proxy-network"; then
    test_check 0 "Rete nginx-proxy-network esiste"
else
    test_check 1 "Rete nginx-proxy-network esiste"
    echo -e "${YELLOW}  → Crea con: docker network create nginx-proxy-network${NC}"
fi

echo ""
echo "3️⃣  Verifica Container nginx-proxy"
echo "----------------------------------"

# Test nginx-proxy in esecuzione
if docker ps | grep -q "nginx-proxy"; then
    test_check 0 "Container nginx-proxy in esecuzione"
else
    test_check 1 "Container nginx-proxy in esecuzione"
    echo -e "${YELLOW}  → nginx-proxy deve essere attivo${NC}"
fi

# Test letsencrypt companion
if docker ps | grep -q "letsencrypt"; then
    test_check 0 "Let's Encrypt companion in esecuzione"
else
    test_check 1 "Let's Encrypt companion in esecuzione"
    echo -e "${YELLOW}  → letsencrypt-companion deve essere attivo${NC}"
fi

echo ""
echo "4️⃣  Verifica DNS"
echo "---------------"

# Test risoluzione DNS
if nslookup owncloud.filippobilardo.it >/dev/null 2>&1; then
    IP=$(nslookup owncloud.filippobilardo.it | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    test_check 0 "DNS owncloud.filippobilardo.it risolve a $IP"
else
    test_check 1 "DNS owncloud.filippobilardo.it risolve"
    echo -e "${YELLOW}  → Verifica configurazione DNS${NC}"
fi

echo ""
echo "5️⃣  Verifica Container OwnCloud"
echo "------------------------------"

# Test container owncloud
if docker ps | grep -q "owncloud_server"; then
    test_check 0 "Container owncloud_server in esecuzione"
    
    # Test health
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' owncloud_server 2>/dev/null)
    if [ "$HEALTH" = "healthy" ]; then
        test_check 0 "Container owncloud_server healthy"
    else
        test_check 1 "Container owncloud_server healthy (stato: $HEALTH)"
    fi
else
    test_check 1 "Container owncloud_server in esecuzione"
    echo -e "${YELLOW}  → Avvia con: make start${NC}"
fi

# Test container mariadb
if docker ps | grep -q "owncloud_mariadb"; then
    test_check 0 "Container owncloud_mariadb in esecuzione"
else
    test_check 1 "Container owncloud_mariadb in esecuzione"
fi

# Test container redis
if docker ps | grep -q "owncloud_redis"; then
    test_check 0 "Container owncloud_redis in esecuzione"
else
    test_check 1 "Container owncloud_redis in esecuzione"
fi

echo ""
echo "6️⃣  Verifica Configurazione"
echo "--------------------------"

# Test variabili d'ambiente
if grep -q "owncloud.filippobilardo.it" owncloud-server.env; then
    test_check 0 "Dominio configurato correttamente"
else
    test_check 1 "Dominio configurato correttamente"
fi

if grep -q "LETSENCRYPT_EMAIL" owncloud-server.env; then
    test_check 0 "Email Let's Encrypt configurata"
else
    test_check 1 "Email Let's Encrypt configurata"
fi

echo ""
echo "7️⃣  Test Connettività (se container attivo)"
echo "------------------------------------------"

if docker ps | grep -q "owncloud_server"; then
    # Test connessione HTTPS
    if curl -s -o /dev/null -w "%{http_code}" https://owncloud.filippobilardo.it 2>/dev/null | grep -q "200\|301\|302"; then
        test_check 0 "HTTPS risponde (owncloud.filippobilardo.it)"
    else
        test_check 1 "HTTPS risponde (owncloud.filippobilardo.it)"
        echo -e "${YELLOW}  → Attendi 1-2 minuti per certificato Let's Encrypt${NC}"
    fi
    
    # Test rete container
    if docker inspect owncloud_server | grep -q "nginx-proxy-network"; then
        test_check 0 "Container sulla rete nginx-proxy-network"
    else
        test_check 1 "Container sulla rete nginx-proxy-network"
    fi
else
    echo -e "${YELLOW}⊘ Container non attivo - test connettività saltati${NC}"
fi

echo ""
echo "========================================"
echo "📊 Risultati Test"
echo "========================================"
echo -e "${GREEN}Passati: $PASSED${NC}"
echo -e "${RED}Falliti: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ Tutti i test passati! Setup corretto.${NC}"
    echo ""
    echo "🌐 Accedi a: https://owncloud.filippobilardo.it"
    exit 0
else
    echo -e "${YELLOW}⚠️  Alcuni test falliti. Verifica la configurazione.${NC}"
    echo ""
    echo "📚 Documentazione:"
    echo "  - NGINX_PROXY_SETUP.md - Setup dettagliato"
    echo "  - QUICKSTART_NGINX_PROXY.md - Guida rapida"
    exit 1
fi
