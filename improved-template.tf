terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "docker" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# ============================================
# CODER AGENT s vylepšeným startup scriptem
# ============================================
resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  # Rozšířený startup script s error handlingem
  startup_script = <<-SCRIPT
    #!/bin/bash
    set -euo pipefail

    # Logging funkce
    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
    error() { echo "[ERROR] $*" >&2; }

    log "=== Agent Startup ==="

    # Inicializace home složky
    if [ ! -f ~/.init_done ]; then
      log "Initializing home directory..."
      cp -rT /etc/skel ~ 2>/dev/null || true
      touch ~/.init_done
    fi

    # Přidání do docker skupiny
    if ! groups | grep -q docker; then
      log "Adding user to docker group..."
      sudo usermod -aG docker coder 2>/dev/null || true
    fi

    # Kontrola Docker dostupnosti
    for i in {1..30}; do
      if docker info &>/dev/null; then
        log "Docker is accessible"
        break
      fi
      log "Waiting for Docker ($i/30)..."
      sleep 2
    done

    # Vytvoření workspace složek
    mkdir -p ~/orchestration ~/logs ~/data

    log "Agent startup complete"
    exit 0
  SCRIPT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
    DOCKER_BUILDKIT     = "1"
    COMPOSE_DOCKER_CLI_BUILD = "1"
  }

  # CPU Monitoring
  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  # RAM Monitoring
  metadata {
    display_name = "RAM Usage"
    key          = "ram"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  # Disk Monitoring
  metadata {
    display_name = "Disk Usage"
    key          = "disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  # Docker Containers
  metadata {
    display_name = "Docker Containers"
    key          = "docker"
    script       = "docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null | tail -n +2 | wc -l || echo '0'"
    interval     = 30
    timeout      = 5
  }

  # Orchestration Services Status
  metadata {
    display_name = "Services Running"
    key          = "services"
    script       = <<-SCRIPT
      cd ~/orchestration 2>/dev/null || exit 0
      if [ -f docker-compose.yml ]; then
        docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l
      else
        echo "0"
      fi
    SCRIPT
    interval     = 30
    timeout      = 5
  }
}

# ============================================
# SETUP SCRIPT - Vylepšený s kontrolami
# ============================================
resource "coder_script" "setup" {
  agent_id     = coder_agent.main.id
  display_name = "Setup Orchestration"
  icon         = "/icon/docker.svg"

  script = <<-SCRIPT
    #!/bin/bash
    set -euo pipefail

    # Barvy pro výstup
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'

    log() { echo -e "$${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]$${NC} $*"; }
    warn() { echo -e "$${YELLOW}[WARNING]$${NC} $*"; }
    error() { echo -e "$${RED}[ERROR]$${NC} $*" >&2; }

    log "=== HAS Orchestration Setup ==="

    # Navigace do orchestration složky
    mkdir -p /home/coder/orchestration
    cd /home/coder/orchestration

    # Update package lists
    log "Updating package lists..."
    sudo apt-get update -qq || warn "Package update failed"

    # Instalace nástrojů
    log "Installing essential tools..."
    PACKAGES=(
      "docker-compose"
      "git"
      "make"
      "curl"
      "wget"
      "nano"
      "vim"
      "tmux"
      "jq"
      "htop"
      "ncdu"
    )

    for pkg in "$${PACKAGES[@]}"; do
      if ! dpkg -l | grep -q "^ii  $pkg "; then
        log "Installing $pkg..."
        sudo apt-get install -y "$pkg" || warn "$pkg installation failed"
      fi
    done

    # Instalace database clients
    log "Installing database clients..."
    sudo apt-get install -y postgresql-client redis-tools || warn "DB clients installation failed"

    # Docker skupina
    log "Ensuring docker group membership..."
    sudo usermod -aG docker coder || warn "Failed to add to docker group"

    # Klonování repository
    log "Cloning orchestration repository..."
    if [ ! -d ".git" ]; then
      git clone https://github.com/milhy545/orchestration.git . || {
        error "Repository clone failed"
        exit 1
      }

      # Git konfigurace
      git config user.name "${coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)}"
      git config user.email "${data.coder_workspace_owner.me.email}"
    else
      log "Repository already exists, pulling latest..."
      git pull || warn "Git pull failed"
    fi

    # .env setup
    if [ -f ".env.example" ] && [ ! -f ".env" ]; then
      log "Creating .env from example..."
      cp .env.example .env
      chmod 600 .env
      warn "Please edit .env file with your credentials!"
    fi

    # Vytvoření data složek s správnými permissions
    log "Creating data directories..."
    mkdir -p data/{postgres,redis,rabbitmq,monitoring}
    chmod -R 755 data/

    # Kontrola docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
      error "docker-compose.yml not found!"
      exit 1
    fi

    # Validace docker-compose
    log "Validating docker-compose configuration..."
    if docker-compose config &>/dev/null; then
      log "docker-compose.yml is valid"
    else
      error "docker-compose.yml validation failed!"
      docker-compose config
      exit 1
    fi

    log "=== Setup Complete ==="
    log ""
    log "Next steps:"
    log "  1. Edit ~/orchestration/.env with your credentials"
    log "  2. Run: cd ~/orchestration && docker-compose up -d"
    log "  3. Check logs: docker-compose logs -f"
    log ""
  SCRIPT

  run_on_start = true
  run_on_stop  = false
}

# ============================================
# HEALTH CHECK SCRIPT - Kontrola služeb
# ============================================
resource "coder_script" "healthcheck" {
  agent_id     = coder_agent.main.id
  display_name = "Services Health Check"
  icon         = "/icon/health.svg"

  script = <<-SCRIPT
    #!/bin/bash

    cd ~/orchestration 2>/dev/null || exit 0

    if [ ! -f docker-compose.yml ]; then
      echo "No docker-compose.yml found"
      exit 0
    fi

    echo "=== Orchestration Services Status ==="
    docker-compose ps
    echo ""

    echo "=== Service Health ==="

    # PostgreSQL
    if docker-compose ps postgres 2>/dev/null | grep -q "Up"; then
      echo "✓ PostgreSQL: Running"
    else
      echo "✗ PostgreSQL: Stopped"
    fi

    # Redis
    if docker-compose ps redis 2>/dev/null | grep -q "Up"; then
      echo "✓ Redis: Running"
    else
      echo "✗ Redis: Stopped"
    fi

    # RabbitMQ
    if docker-compose ps rabbitmq 2>/dev/null | grep -q "Up"; then
      echo "✓ RabbitMQ: Running"
    else
      echo "✗ RabbitMQ: Stopped"
    fi

    echo ""
  SCRIPT

  run_on_start = false
  run_on_stop  = false
}

# ============================================
# IDE MODULES
# ============================================

# Code Server
module "code-server" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/modules/code-server/coder"
  version = "1.0.13"

  agent_id = coder_agent.main.id
  folder   = "/home/coder/orchestration"
}

# Cursor
module "cursor" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/modules/cursor/coder"
  version = "1.3.2"

  agent_id = coder_agent.main.id
  folder   = "/home/coder/orchestration"
}

# ============================================
# CODER APPS - Přístup k službám
# ============================================

# RabbitMQ Management UI
resource "coder_app" "rabbitmq" {
  agent_id     = coder_agent.main.id
  slug         = "rabbitmq"
  display_name = "RabbitMQ Management"
  url          = "http://localhost:15672"
  icon         = "/icon/rabbitmq.svg"
  share        = "authenticated"
  subdomain    = true

  healthcheck {
    url       = "http://localhost:15672/"
    interval  = 10
    threshold = 30
  }
}

# PostgreSQL Admin (pokud máš pgAdmin v docker-compose)
resource "coder_app" "postgres" {
  agent_id     = coder_agent.main.id
  slug         = "postgres"
  display_name = "PostgreSQL"
  icon         = "/icon/postgres.svg"
  command      = "psql postgresql://localhost:5432/has_db"
  share        = "owner"
}

# Redis CLI
resource "coder_app" "redis" {
  agent_id     = coder_agent.main.id
  slug         = "redis-cli"
  display_name = "Redis CLI"
  icon         = "/icon/redis.svg"
  command      = "redis-cli"
  share        = "owner"
}

# Prometheus (pokud běží na portu 9090)
resource "coder_app" "prometheus" {
  agent_id     = coder_agent.main.id
  slug         = "prometheus"
  display_name = "Prometheus"
  url          = "http://localhost:9090"
  icon         = "/icon/prometheus.svg"
  share        = "authenticated"
  subdomain    = true

  healthcheck {
    url       = "http://localhost:9090/-/healthy"
    interval  = 15
    threshold = 30
  }
}

# Grafana (pokud běží na portu 3000)
resource "coder_app" "grafana" {
  agent_id     = coder_agent.main.id
  slug         = "grafana"
  display_name = "Grafana"
  url          = "http://localhost:3000"
  icon         = "/icon/grafana.svg"
  share        = "authenticated"
  subdomain    = true

  healthcheck {
    url       = "http://localhost:3000/api/health"
    interval  = 15
    threshold = 30
  }
}

# Terminal Access
resource "coder_app" "terminal" {
  agent_id     = coder_agent.main.id
  slug         = "terminal"
  display_name = "Terminal"
  icon         = "/icon/terminal.svg"
  command      = "bash"
  share        = "owner"
}

# ============================================
# DOCKER RESOURCES
# ============================================

# Persistent Home Volume
resource "docker_volume" "home" {
  name = "coder-$${data.coder_workspace.me.id}-home"

  lifecycle {
    ignore_changes = all
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }

  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }

  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}

# Workspace Container
resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count

  image      = "codercom/enterprise-base:ubuntu"
  name       = "coder-$${data.coder_workspace_owner.me.name}-$${lower(data.coder_workspace.me.name)}"
  hostname   = data.coder_workspace.me.name
  user       = "coder"
  privileged = true

  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]

  env = [
    "CODER_AGENT_TOKEN=$${coder_agent.main.token}",
  ]

  # Host networking pro Docker
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  # Home volume
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
  }

  # Docker socket
  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
  }

  # Resource limits (upravitelné)
  memory      = 8192  # 8GB RAM
  memory_swap = 16384 # 16GB with swap
  cpus        = 4     # 4 CPU cores

  # Restart policy
  restart = "unless-stopped"

  # Labels
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }

  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }

  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
