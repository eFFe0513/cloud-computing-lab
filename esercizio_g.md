# 🔐 Esercizio E: WireGuard VPN Server con Web UI

## Obiettivo

Creare un **WireGuard VPN server** con interfaccia web di gestione, protetto da **Nginx Proxy Manager** con SSL/TLS. Gli studenti impareranno a configurare una VPN self-hosted, gestire client, e implementare networking sicuro nel cloud.

## ⚠️ Importante: Limitazioni GitHub Codespaces

**WireGuard richiede kernel capabilities** (`NET_ADMIN`, `SYS_MODULE`) che **NON sono disponibili** in GitHub Codespaces standard per motivi di sicurezza.

### Soluzioni Alternative:

1. **VPS Cloud** (Consigliato per produzione)
   - AWS EC2, DigitalOcean Droplet, Linode, Hetzner
   - Ubuntu 22.04+ con kernel 5.6+
   - Accesso root/sudo

2. **VM Locale** (Per sviluppo)
   - VirtualBox/VMware con Ubuntu
   - Docker Desktop (macOS/Windows con WSL2)
   - Accesso privilegiato

3. **Alternativa Didattica** (Solo per test)
   - Simulare configurazione in Codespaces
   - Deploy reale su VPS per test finale

**Questo esercizio guiderà il setup su VPS, con note per adattamento locale.**

---

## Architettura

```
┌────────────────────────────────────────────────────────────┐
│                         INTERNET                           │
└───────────┬──────────────────────────────┬─────────────────┘
            │                              │
      UDP :51820                      HTTPS :443
     (VPN Traffic)                   (Web GUI)
            │                              │
┌───────────▼──────────────────────────────▼─────────────────┐
│                     VPS / VM (Ubuntu)                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Docker Network: nginx-proxy-network     │  │
│  │                                                      │  │
│  │  ┌─────────────────┐          ┌──────────────────┐   │  │
│  │  │   WG-Easy       │          │ Nginx Proxy Mgr  │   │  │
│  │  │                 │          │                  │   │  │
│  │  │ :51820/udp ←────┼──────────┤ :443/tcp         │   │  │
│  │  │ :51821 (GUI) ←──┼──────────┤ (reverse proxy)  │   │  │
│  │  │                 │          │                  │   │  │
│  │  │ WireGuard VPN   │          │ Let's Encrypt    │   │  │
│  │  │ Server          │          │ SSL/TLS          │   │  │
│  │  └─────────────────┘          └──────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
           ▲                              ▲
           │                              │
    ┌──────┴──────┐              ┌────────┴────────┐
    │ VPN Clients │              │  Admin Browser  │
    │ (Mobile/PC) │              │  (Manage users) │
    └─────────────┘              └─────────────────┘
```

**Flusso:**
1. **Admin** accede GUI via HTTPS → Nginx Proxy → WG-Easy :51821
2. **Admin** crea client VPN (scarica config/QR)
3. **Client** si connette VPN via UDP :51820 → WG-Easy
4. **Client** può navigare tramite VPN tunnel

---

## Parte 1: Prerequisiti e Setup VPS

### Step 1.1: Scelta VPS Provider

**Opzioni consigliate** (da ~$5/mese):

| Provider | Piano Base | Note |
|----------|------------|------|
| **DigitalOcean** | Droplet $6/mo | 1GB RAM, 1 vCPU, facile setup |
| **Hetzner** | CX11 €4.15/mo | Ottimo rapporto qualità/prezzo |
| **Linode** | Nanode $5/mo | Buona documentazione |
| **Vultr** | Regular $5/mo | Molte location |
| **AWS** | t2.micro (Free tier) | 750h/mese gratis 12 mesi |

**Specifiche minime**:
- CPU: 1 vCPU
- RAM: 1 GB
- Storage: 25 GB SSD
- OS: **Ubuntu 22.04 LTS**
- Network: 1 Gbps, traffico illimitato

### Step 1.2: Setup Iniziale VPS

```bash
# SSH nel VPS
ssh root@YOUR_VPS_IP

# Update sistema
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
apt install docker-compose -y

# Verifica installazione
docker --version
docker-compose --version

# Firewall (ufw)
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP (Nginx)
ufw allow 443/tcp     # HTTPS (Nginx)
ufw allow 51820/udp   # WireGuard VPN
ufw enable
ufw status
```

### Step 1.3: Setup DNS (Importante!)

**Necessario per SSL/TLS con Let's Encrypt**:

1. Compra dominio (es. Namecheap, Cloudflare, Google Domains)
2. Crea record DNS:
   - **A record**: `vpn.tuodominio.com` → `YOUR_VPS_IP`
   - **A record**: `npm.tuodominio.com` → `YOUR_VPS_IP` (opzionale, per Nginx GUI)

**Verifica DNS propagation**:
```bash
dig vpn.tuodominio.com +short
# Deve ritornare: YOUR_VPS_IP
```

---

## Parte 2: Repository e Struttura Progetto

### Step 2.1: Crea Repository GitHub

**Opzione A: Repository Pubblico (senza secrets)**
```bash
# Locale
mkdir wireguard-vpn-server
cd wireguard-vpn-server
git init
```

**Opzione B: Repository Privato** (consigliato, contiene .env)

### Step 2.2: Struttura Directory

```
wireguard-vpn-server/
├── docker-compose.yml
├── .env.example
├── .env                    # Git-ignored! Contiene password
├── .gitignore
├── volumes/
│   ├── wireguard/          # Dati WireGuard (git-ignored)
│   ├── nginx-proxy/        # Dati Nginx Proxy Manager
│   ├── nginx-letsencrypt/  # Certificati SSL
│   └── nginx-db/           # Database Nginx (SQLite)
├── scripts/
│   ├── setup.sh            # Script setup automatico
│   ├── backup.sh           # Backup configurazioni
│   └── generate-hash.sh    # Genera password hash
├── docs/
│   ├── SETUP.md            # Guida setup dettagliata
│   └── CLIENTS.md          # Guida configurazione client
└── README.md
```

### Step 2.3: Crea `.gitignore`

```gitignore
# Environment variables
.env

# Volumes (dati sensibili)
volumes/wireguard/*
volumes/nginx-proxy/*
volumes/nginx-letsencrypt/*
volumes/nginx-db/*

# Keep directory structure
!volumes/.gitkeep
!volumes/wireguard/.gitkeep
!volumes/nginx-proxy/.gitkeep
!volumes/nginx-letsencrypt/.gitkeep
!volumes/nginx-db/.gitkeep

# Logs
*.log

# macOS
.DS_Store

# Editor
.vscode/
.idea/
```

---

## Parte 3: Configurazione Docker Compose

### Step 3.1: Crea `.env.example`

```bash
# =============================================================================
# WireGuard VPN + Nginx Proxy Manager - Environment Variables
# =============================================================================
# ISTRUZIONI:
#   1. Copia questo file: cp .env.example .env
#   2. Modifica .env con i tuoi valori
#   3. NON committare .env nel repository!
# =============================================================================

# -----------------------------------------------------------------------------
# WIREGUARD CONFIGURATION
# -----------------------------------------------------------------------------
# OBBLIGATORIO: IP pubblico del VPS o hostname (usato nei QR code client)
WG_HOST=vpn.tuodominio.com

# Password admin GUI WireGuard (genera hash con script/generate-hash.sh)
WG_PASSWORD_HASH=

# Porta VPN (default 51820)
WG_PORT=51820

# Range IP client VPN (10.8.0.x dove x = 2-254)
WG_DEFAULT_ADDRESS=10.8.0.x

# DNS per client VPN (Cloudflare + Google)
WG_DNS=1.1.1.1,8.8.8.8

# Traffico instradato tramite VPN (0.0.0.0/0 = tutto)
WG_ALLOWED_IPS=0.0.0.0/0,::/0

# Keepalive per NAT traversal (secondi)
WG_KEEPALIVE=25

# Lingua GUI (it, en, de, fr, es, etc.)
WG_LANG=it

# Tipo grafico statistiche (0=off, 1=line, 2=area, 3=bar)
UI_CHART_TYPE=1

# -----------------------------------------------------------------------------
# NGINX PROXY MANAGER CONFIGURATION
# -----------------------------------------------------------------------------
# Email per Let's Encrypt (riceverai notifiche scadenza certificati)
NPM_EMAIL=tua-email@example.com

# Database MySQL per Nginx Proxy Manager
NPM_MYSQL_ROOT_PASSWORD=strong_root_password_here
NPM_MYSQL_DATABASE=npm_db
NPM_MYSQL_USER=npm_user
NPM_MYSQL_PASSWORD=strong_npm_password_here
```

### Step 3.2: Crea `docker-compose.yml`

```yaml
version: '3.8'

# =============================================================================
# RETI
# =============================================================================
networks:
  nginx-proxy-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

# =============================================================================
# VOLUMI
# =============================================================================
volumes:
  wireguard_data:
    driver: local
  nginx_data:
    driver: local
  nginx_letsencrypt:
    driver: local
  nginx_db:
    driver: local

# =============================================================================
# SERVIZI
# =============================================================================
services:

  # ---------------------------------------------------------------------------
  # NGINX PROXY MANAGER - Reverse Proxy + SSL/TLS
  # ---------------------------------------------------------------------------
  nginx-proxy:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    
    ports:
      - "80:80"       # HTTP
      - "443:443"     # HTTPS
      - "81:81"       # Admin GUI
    
    environment:
      # Database connection
      DB_MYSQL_HOST: nginx-db
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: ${NPM_MYSQL_USER}
      DB_MYSQL_PASSWORD: ${NPM_MYSQL_PASSWORD}
      DB_MYSQL_NAME: ${NPM_MYSQL_DATABASE}
      
      # Disable IPv6 (opzionale)
      DISABLE_IPV6: 'true'
    
    volumes:
      - nginx_data:/data
      - nginx_letsencrypt:/etc/letsencrypt
    
    networks:
      - nginx-proxy-network
    
    depends_on:
      - nginx-db
    
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:81"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    
    labels:
      - "com.docker.compose.project=wireguard-vpn"
      - "com.docker.compose.service=nginx-proxy-manager"
      - "category=proxy"

  # ---------------------------------------------------------------------------
  # MYSQL DATABASE - Per Nginx Proxy Manager
  # ---------------------------------------------------------------------------
  nginx-db:
    image: mariadb:11.2
    container_name: nginx-proxy-db
    restart: unless-stopped
    
    environment:
      MYSQL_ROOT_PASSWORD: ${NPM_MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${NPM_MYSQL_DATABASE}
      MYSQL_USER: ${NPM_MYSQL_USER}
      MYSQL_PASSWORD: ${NPM_MYSQL_PASSWORD}
    
    volumes:
      - nginx_db:/var/lib/mysql
    
    networks:
      - nginx-proxy-network
    
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${NPM_MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ---------------------------------------------------------------------------
  # WG-EASY - WireGuard VPN + Web UI
  # ---------------------------------------------------------------------------
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    restart: unless-stopped
    
    environment:
      # Lingua interfaccia
      - LANG=${WG_LANG:-it}
      
      # OBBLIGATORIO: Hostname pubblico
      - WG_HOST=${WG_HOST}
      
      # Password admin (hash bcrypt)
      - PASSWORD_HASH=${WG_PASSWORD_HASH}
      
      # Porta GUI interna
      - PORT=51821
      
      # Porta VPN
      - WG_PORT=${WG_PORT:-51820}
      
      # Range IP client
      - WG_DEFAULT_ADDRESS=${WG_DEFAULT_ADDRESS:-10.8.0.x}
      
      # DNS client
      - WG_DEFAULT_DNS=${WG_DNS:-1.1.1.1,8.8.8.8}
      
      # Traffico instradato
      - WG_ALLOWED_IPS=${WG_ALLOWED_IPS:-0.0.0.0/0,::/0}
      
      # Keepalive
      - WG_PERSISTENT_KEEPALIVE=${WG_KEEPALIVE:-25}
      
      # Statistiche traffico
      - UI_TRAFFIC_STATS=true
      - UI_CHART_TYPE=${UI_CHART_TYPE:-1}
    
    volumes:
      - wireguard_data:/etc/wireguard
    
    ports:
      # Porta VPN (UDP) - esposta pubblicamente
      - "${WG_PORT:-51820}:51820/udp"
      # GUI NON esposta - solo via Nginx Proxy
    
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
    
    networks:
      - nginx-proxy-network
    
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:51821/ >/dev/null 2>&1 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    
    labels:
      - "com.docker.compose.project=wireguard-vpn"
      - "com.docker.compose.service=wg-easy"
      - "category=vpn"
      - "backup.enable=true"
```

---

## Parte 4: Script Utility

### Step 4.1: `scripts/generate-hash.sh`

```bash
#!/bin/bash
# Generate bcrypt password hash for WG-Easy

echo "==================================="
echo "WG-Easy Password Hash Generator"
echo "==================================="
echo ""
read -sp "Enter password for WG-Easy admin: " PASSWORD
echo ""
echo ""

# Generate hash using Docker
HASH=$(docker run --rm -it ghcr.io/wg-easy/wg-easy wgpw "$PASSWORD" | tr -d '\r')

echo "==================================="
echo "Generated Password Hash:"
echo "==================================="
echo "$HASH"
echo ""
echo "Add this to your .env file:"
echo "WG_PASSWORD_HASH='$HASH'"
echo "==================================="
```

```bash
chmod +x scripts/generate-hash.sh
```

### Step 4.2: `scripts/setup.sh`

```bash
#!/bin/bash
# Automated setup script for WireGuard VPN server

set -e

echo "=========================================="
echo "WireGuard VPN Server - Automated Setup"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Please run as root (sudo ./scripts/setup.sh)"
  exit 1
fi

# Check .env file
if [ ! -f .env ]; then
  echo "❌ .env file not found!"
  echo "   Run: cp .env.example .env"
  echo "   Then edit .env with your configuration"
  exit 1
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$WG_HOST" ]; then
  echo "❌ WG_HOST not set in .env"
  exit 1
fi

if [ -z "$WG_PASSWORD_HASH" ]; then
  echo "❌ WG_PASSWORD_HASH not set in .env"
  echo "   Generate with: ./scripts/generate-hash.sh"
  exit 1
fi

# Create volume directories
echo "📁 Creating volume directories..."
mkdir -p volumes/{wireguard,nginx-proxy,nginx-letsencrypt,nginx-db}
touch volumes/{wireguard,nginx-proxy,nginx-letsencrypt,nginx-db}/.gitkeep

# Set permissions
chmod 700 volumes/wireguard
chmod 700 volumes/nginx-letsencrypt

# Start services
echo "🚀 Starting Docker services..."
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 20

# Show status
echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
docker-compose ps
echo ""
echo "Next steps:"
echo "1. Configure Nginx Proxy Manager:"
echo "   → http://YOUR_VPS_IP:81"
echo "   → Default: admin@example.com / changeme"
echo ""
echo "2. Add Proxy Host for WG-Easy:"
echo "   → Domain: ${WG_HOST}"
echo "   → Forward to: wg-easy:51821"
echo "   → Enable SSL with Let's Encrypt"
echo ""
echo "3. Access WG-Easy GUI:"
echo "   → https://${WG_HOST}"
echo ""
echo "=========================================="
```

```bash
chmod +x scripts/setup.sh
```

### Step 4.3: `scripts/backup.sh`

```bash
#!/bin/bash
# Backup WireGuard configurations

BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="wireguard_backup_${DATE}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "🗂️  Creating backup: $BACKUP_FILE"

tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" \
  volumes/wireguard \
  .env \
  docker-compose.yml

echo "✅ Backup created: ${BACKUP_DIR}/${BACKUP_FILE}"
echo "📦 Size: $(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)"
```

```bash
chmod +x scripts/backup.sh
```

---

## Parte 5: Deploy e Configurazione

### Step 5.1: Deploy su VPS

```bash
# Sul VPS
cd /opt
git clone https://github.com/tuousername/wireguard-vpn-server.git
cd wireguard-vpn-server

# Setup .env
cp .env.example .env
nano .env
# → Compila tutte le variabili!

# Genera password hash
./scripts/generate-hash.sh
# → Copia hash in .env (WG_PASSWORD_HASH)

# Run setup
sudo ./scripts/setup.sh
```

### Step 5.2: Configurare Nginx Proxy Manager

```bash
# Apri browser
http://YOUR_VPS_IP:81

# Login iniziale
Email: admin@example.com
Password: changeme

# IMPORTANTE: Cambia subito email e password!
```

**Aggiungi Proxy Host per WG-Easy**:

1. **Proxy Hosts** → **Add Proxy Host**
2. **Details**:
   - Domain Names: `vpn.tuodominio.com`
   - Scheme: `http`
   - Forward Hostname/IP: `wg-easy`
   - Forward Port: `51821`
   - ✅ Cache Assets
   - ✅ Block Common Exploits
   - ✅ Websockets Support

3. **SSL**:
   - ✅ Force SSL
   - ✅ HTTP/2 Support
   - ✅ HSTS Enabled
   - SSL Certificate: **Request a new SSL Certificate**
   - Email: tua-email@example.com
   - ✅ I Agree to Let's Encrypt TOS

4. **Save**

### Step 5.3: Accesso WG-Easy GUI

```bash
# Browser
https://vpn.tuodominio.com

# Login con password impostata in .env
```

---

## Parte 6: Gestione Client VPN

### Step 6.1: Creazione Client

1. GUI WG-Easy → **New Client**
2. Nome: `ClientMobile` (o PC, Tablet, etc.)
3. **Create**
4. **Download** config o **Show QR Code**

### Step 6.2: Installazione Client

**Mobile (iOS/Android)**:
1. Install [WireGuard app](https://www.wireguard.com/install/)
2. Scan QR code da GUI WG-Easy
3. Attiva VPN

**Desktop (Windows/macOS/Linux)**:
1. Install [WireGuard](https://www.wireguard.com/install/)
2. Download file `.conf` da GUI
3. Import → Activate

### Step 6.3: Test VPN

```bash
# Prima della connessione VPN
curl ifconfig.me
# → Mostra tuo IP pubblico

# Dopo connessione VPN
curl ifconfig.me
# → Mostra IP del VPS!

# Test DNS leak
https://dnsleaktest.com
# → Dovrebbe mostrare DNS configurati (1.1.1.1, 8.8.8.8)
```

---

## Parte 7: Security Best Practices

### 7.1: Firewall Rules

```bash
# Sul VPS - solo porte necessarie
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw allow 51820/udp   # WireGuard
ufw enable
```

### 7.2: SSH Hardening

```bash
# Disable root login + password auth
nano /etc/ssh/sshd_config

# Modifica:
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes

# Restart SSH
systemctl restart sshd
```

### 7.3: Fail2Ban (Anti-Bruteforce)

```bash
apt install fail2ban -y

# Configurazione Nginx
cat > /etc/fail2ban/jail.d/nginx.conf << 'EOF'
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-botsearch]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

systemctl restart fail2ban
```

### 7.4: Auto-Updates

```bash
# Unattended upgrades (security patches)
apt install unattended-upgrades -y
dpkg-reconfigure -plow unattended-upgrades
```

---

## Parte 8: Monitoring e Troubleshooting

### 8.1: Check Logs

```bash
# Tutti i container
docker-compose logs -f

# Solo WireGuard
docker-compose logs -f wg-easy

# Solo Nginx
docker-compose logs -f nginx-proxy
```

### 8.2: Verificare Connettività

```bash
# Test porta VPN aperta
nc -zvu YOUR_VPS_IP 51820
# → Should succeed

# Test GUI HTTPS
curl -I https://vpn.tuodominio.com
# → Should return 200 OK
```

### 8.3: Container Status

```bash
docker-compose ps
# Tutti "Up" e "healthy"
```

### 8.4: Problemi Comuni

**Problema: "Connection refused" GUI**
```bash
# Check Nginx proxy host configurato correttamente
docker exec nginx-proxy-manager cat /data/nginx/proxy_host/1.conf
```

**Problema: VPN non si connette**
```bash
# Check firewall VPS
ufw status
# Deve permettere 51820/udp

# Check IP forwarding
sysctl net.ipv4.ip_forward
# Deve essere = 1
```

**Problema: DNS non funziona in VPN**
```bash
# In WG-Easy GUI, verifica WG_DEFAULT_DNS
# Prova: 1.1.1.1,8.8.8.8
```

---

## ✅ Checklist Completamento

- [ ] VPS Ubuntu 22.04 attivo
- [ ] Docker e Docker Compose installati
- [ ] DNS record configurato (vpn.tuodominio.com)
- [ ] Repository Git creato
- [ ] File .env compilato con tutti i valori
- [ ] Password hash generato
- [ ] `docker-compose up -d` eseguito con successo
- [ ] Nginx Proxy Manager configurato
- [ ] Proxy host per WG-Easy con SSL
- [ ] GUI WG-Easy accessibile via HTTPS
- [ ] Client VPN creato e testato
- [ ] Connessione VPN funzionante
- [ ] IP pubblico mascherato tramite VPN
- [ ] Firewall configurato
- [ ] Backup creato

---

## 📸 Consegna

1. **Repository GitHub** con:
   - `docker-compose.yml`
   - `.env.example`
   - Scripts (`setup.sh`, `generate-hash.sh`, `backup.sh`)
   - Documentazione (`README.md`, `SETUP.md`)

2. **Screenshot**:
   - Nginx Proxy Manager dashboard
   - WG-Easy GUI con client attivi
   - `docker-compose ps` (containers running)
   - Test connessione VPN (curl ifconfig.me)
   - DNS leak test

3. **File RELAZIONE.md**:
   - Architettura spiegata
   - Scelte di configurazione
   - Security hardening implementato
   - Test effettuati
   - Problemi risolti

---

## 🎯 Bonus

- [ ] Configurare 2FA su Nginx Proxy Manager
- [ ] Monitoring con Prometheus + Grafana
- [ ] Alert su Telegram/Discord per nuove connessioni VPN
- [ ] Split tunneling (solo traffico specifico in VPN)
- [ ] Multi-region VPN (più VPS, load balancing)
- [ ] Wireguard kernel module (invece userspace)
- [ ] IPv6 support

---

## 📚 Risorse

- [WireGuard Docs](https://www.wireguard.com/)
- [WG-Easy GitHub](https://github.com/wg-easy/wg-easy)
- [Nginx Proxy Manager](https://nginxproxymanager.com/)
- [Let's Encrypt](https://letsencrypt.org/)
- [DigitalOcean VPN Tutorial](https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-ubuntu-22-04)

---

## 🚀 Deployment Alternatives

### Cloud Providers con VPN Template:

- **AWS Lightsail** VPN Blueprint ($5/mo)
- **Azure** con WireGuard template
- **Google Cloud** Compute Engine
- **Oracle Cloud** Free tier (2 micro instances gratis!)

### Self-Hosted Options:

- **Raspberry Pi** a casa (con DDNS)
- **Old laptop** con Ubuntu Server
- **Proxmox VE** container LXC

---

**Complimenti!** Hai deployato un VPN server self-hosted sicuro e scalabile! 🎉🔐
