# Vylepšený Coder Template pro HAS Orchestration

## 🎯 Co bylo vylepšeno

### 1. ✅ Robustní Error Handling
**Před:**
```bash
sudo usermod -aG docker coder 2>/dev/null || true
```

**Po vylepšení:**
```bash
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "[ERROR] $*" >&2; }

if ! groups | grep -q docker; then
  log "Adding user to docker group..."
  sudo usermod -aG docker coder 2>/dev/null || true
fi
```

### 2. 🏥 Health Check Script
**Nové:** Přidán `coder_script` pro kontrolu zdraví služeb:
- Kontroluje běžící kontejnery
- Verifikuje PostgreSQL, Redis, RabbitMQ
- Spouštitelný kdykoliv z Coder UI

### 3. 📊 Rozšířené Monitoring Metadata
**Nové metriky:**
- **Services Running** - počet běžících docker-compose služeb
- **Docker Containers** - celkový počet kontejnerů
- Vylepšené CPU/RAM/Disk metriky

### 4. 🌐 Kompletní Coder Apps
**Přidáno:**
- ✅ **PostgreSQL CLI** - přímý přístup k databázi
- ✅ **Redis CLI** - redis-cli v terminálu
- ✅ **Prometheus** - monitoring dashboard (port 9090)
- ✅ **Grafana** - vizualizace metrik (port 3000)
- ✅ **RabbitMQ Management** - rozšířeno o healthcheck

Každá app má:
- ✓ Správnou ikonu
- ✓ Healthcheck (kde aplikováno)
- ✓ Subdomain support
- ✓ Správná autorizace (owner/authenticated)

### 5. 🔧 Vylepšený Setup Script
**Přidáno:**
- ✅ Validace `docker-compose.yml` před spuštěním
- ✅ Automatické vytvoření data složek (`data/postgres`, `data/redis`, atd.)
- ✅ Kontrola Docker dostupnosti s retry logikou
- ✅ Git pull pokud repo už existuje
- ✅ Barevný výstup pro lepší čitelnost
- ✅ Instalace více nástrojů (htop, ncdu, vim)

### 6. 💪 Resource Limits
**Nové:**
```hcl
memory      = 8192  # 8GB RAM
memory_swap = 16384 # 16GB with swap
cpus        = 4     # 4 CPU cores
restart     = "unless-stopped"
```

### 7. 🏷️ Lepší Labeling
**Přidáno do volumes i containers:**
```hcl
labels {
  label = "coder.workspace_name"
  value = data.coder_workspace.me.name
}
```

---

## 📋 Srovnání funkcí

| Funkce | Původní | Vylepšený |
|--------|---------|-----------|
| **Error handling** | Základní | ✅ Robustní s logováním |
| **Health checks** | ❌ Žádné | ✅ Dedicated script |
| **Coder Apps** | 2 (RabbitMQ, Terminal) | ✅ 7 (všechny služby) |
| **Monitoring metadata** | 4 metriky | ✅ 6 metrik |
| **Setup validace** | ❌ Žádná | ✅ docker-compose config check |
| **Data složky** | Ruční | ✅ Automatické vytvoření |
| **Docker retry logika** | ❌ Žádná | ✅ 30 pokusů s 2s delay |
| **Resource limits** | ❌ Neomezeno | ✅ 8GB RAM, 4 CPU |
| **Git pull** | ❌ Jen clone | ✅ Pull pokud existuje |
| **Restart policy** | ❌ Žádná | ✅ unless-stopped |

---

## 🚀 Jak použít vylepšený template

### 1. Nahraď původní template

```bash
# Zkopíruj improved-template.tf jako main.tf
cp improved-template.tf main.tf
```

### 2. Přizpůsob pro tvoje služby

**Pokud NEMÁŠ Prometheus/Grafana**, odstraň nebo zakomentuj:
```hcl
# resource "coder_app" "prometheus" { ... }
# resource "coder_app" "grafana" { ... }
```

**Pokud máš JINÉ porty**, uprav URL:
```hcl
resource "coder_app" "grafana" {
  url = "http://localhost:TVUJ_PORT"
}
```

### 3. Uprav resource limits

Pro slabší stroj:
```hcl
memory      = 4096  # 4GB
memory_swap = 8192  # 8GB
cpus        = 2     # 2 CPU
```

### 4. Nahraj do Coder

```bash
# V Coder Admin UI:
# Templates → Create Template → Upload main.tf
```

---

## 🔍 Nové funkce v akci

### Health Check Script
```bash
# V Coder workspace, klikni na "Services Health Check" script
# Nebo v terminálu:
bash ~/orchestration/healthcheck.sh
```

**Výstup:**
```
=== Orchestration Services Status ===
NAME        STATUS          PORTS
postgres    Up 2 minutes    5432/tcp
redis       Up 2 minutes    6379/tcp
rabbitmq    Up 2 minutes    5672/tcp, 15672/tcp

=== Service Health ===
✓ PostgreSQL: Running
✓ Redis: Running
✓ RabbitMQ: Running
```

### Monitoring Dashboard

Po spuštění workspace máš přístup k:

1. **RabbitMQ Management**
   - URL: `https://workspace-rabbitmq.coder.example.com`
   - Login: z `.env`

2. **Prometheus**
   - URL: `https://workspace-prometheus.coder.example.com`
   - Metriky všech služeb

3. **Grafana**
   - URL: `https://workspace-grafana.coder.example.com`
   - Dashboard pro vizualizaci

4. **PostgreSQL CLI**
   - Klikni na "PostgreSQL" app
   - Otevře terminál s `psql` připojeným k DB

5. **Redis CLI**
   - Klikni na "Redis CLI" app
   - Otevře terminál s `redis-cli`

---

## 🐛 Řešení problémů

### ❌ "Docker is not accessible"
**Příčina:** Docker socket není dostupný nebo user není ve skupině docker

**Řešení:**
```bash
# V workspace terminálu:
sudo usermod -aG docker coder
# Otevři nový terminál nebo restartuj workspace
```

### ❌ "docker-compose.yml validation failed"
**Příčina:** Syntax error v docker-compose.yml

**Řešení:**
```bash
cd ~/orchestration
docker-compose config
# Oprav chyby které hlásí
```

### ❌ Coder Apps nefungují
**Příčina:** Služba neběží nebo běží na jiném portu

**Řešení:**
```bash
# Zkontroluj běžící služby:
docker-compose ps

# Zkontroluj porty:
docker-compose port rabbitmq 15672
```

### ❌ "Services Running" ukazuje 0
**Příčina:** docker-compose.yml neexistuje nebo služby neběží

**Řešení:**
```bash
cd ~/orchestration
docker-compose up -d
```

---

## 📊 Monitoring Metriky - Co znamenají

| Metrika | Co měří | Normální hodnota |
|---------|---------|------------------|
| **CPU Usage** | Vytížení CPU | 0-50% idle, 50-80% běžné, >80% vysoké |
| **RAM Usage** | Využití paměti | <70% dobrá, >90% problém |
| **Disk Usage** | Využití disku v home | <80% dobrá, >90% čistění potřeba |
| **Docker Containers** | Počet běžících kontejnerů | Závisí na docker-compose |
| **Services Running** | Orchestration služby | Počet služeb v docker-compose.yml |

---

## 🎓 Best Practices

### 1. Pravidelná údržba
```bash
# Vyčisti staré Docker images (1x týdně)
docker system prune -af --volumes

# Zkontroluj disk space
df -h ~
ncdu ~  # interaktivní

# Zkontroluj logy
docker-compose logs --tail=100
```

### 2. Správa .env
```bash
# Nikdy necommituj .env!
# Používej .env.example jako šablonu

# Backup .env
cp .env .env.backup

# Načti .env do shellu
set -a; source .env; set +a
```

### 3. Monitoring
```bash
# Sleduj metriky v Coder UI
# nebo přímo:

# CPU top processes
htop

# Disk usage
ncdu ~/orchestration/data

# Docker stats
docker stats
```

---

## 🔐 Security Tips

1. **Změň výchozí hesla** v `.env`
2. **Používej secrets** místo plain text v .env
3. **Omezte síťový přístup** v docker-compose.yml
4. **Pravidelně aktualizuj** Docker images

---

## 📚 Další kroky

### Pokud chceš přidat Claude Code modul:

```hcl
module "claude-code" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/modules/claude-code/coder"
  version = "1.0.0"  # Zkontroluj nejnovější verzi

  agent_id = coder_agent.main.id
  folder   = "/home/coder/orchestration"
}
```

### Pokud chceš přidat pgAdmin:

```hcl
resource "coder_app" "pgadmin" {
  agent_id     = coder_agent.main.id
  slug         = "pgadmin"
  display_name = "pgAdmin"
  url          = "http://localhost:5050"  # Port z docker-compose
  icon         = "/icon/postgres.svg"
  share        = "authenticated"
  subdomain    = true
}
```

---

## 🎉 Výsledek

Po nasazení vylepšeného template budeš mít:

✅ Robustní workspace s error handlingem
✅ Kompletní monitoring všech služeb
✅ Snadný přístup ke všem nástrojům přes Coder Apps
✅ Health checks a validace
✅ Resource limits pro stabilitu
✅ Automatické setup s barevným výstupem

**Workspace, který prostě funguje!** 🚀
