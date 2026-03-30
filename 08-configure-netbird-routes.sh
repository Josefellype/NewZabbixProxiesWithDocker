#!/bin/bash
set -e

# ============================================================
# MÓDULO 08 — Instalação do Serviço de Rotas Netbird
# ============================================================
# Este script instala o daemon 'zabbix-netbird-routes.sh' como
# um serviço systemd de longa duração. Esse serviço:
#   1. Monitora os containers Docker do Zabbix Proxy
#   2. Detecta quando o Netbird atribui um IP a cada container
#   3. Injeta a rota estática no host: <netbird_ip>/32 via <container_ip>
#   4. Anuncia o novo IP /32 via BGP no FRR (via vtysh)
#
# Dependências: docker, vtysh (fornecido pelo container FRR)
# ============================================================

echo "[NETBIRD-ROUTES] Iniciando instalação do serviço de rotas Netbird..."

BASE_DIR="/zabbix-proxies"
ROUTES_SCRIPT_SRC="${BASE_DIR}/zabbix-netbird-routes.sh"
ROUTES_SCRIPT_DST="/usr/local/bin/zabbix-netbird-routes.sh"
SERVICE_SRC="${BASE_DIR}/zabbix-routes.service"
SERVICE_DST="/etc/systemd/system/zabbix-routes.service"

# --- Verificar script de rotas ---
if [ ! -f "$ROUTES_SCRIPT_SRC" ]; then
    echo "[NETBIRD-ROUTES] ERRO: Script de rotas não encontrado em ${ROUTES_SCRIPT_SRC}"
    echo "  Execute o módulo 05-prepare-proxy-deployment.sh antes deste módulo."
    exit 1
fi

# --- Verificar arquivo de serviço ---
if [ ! -f "$SERVICE_SRC" ]; then
    echo "[NETBIRD-ROUTES] ERRO: Arquivo de serviço não encontrado em ${SERVICE_SRC}"
    echo "  Execute o módulo 05-prepare-proxy-deployment.sh antes deste módulo."
    exit 1
fi

# --- Instalar o script de rotas ---
echo "[NETBIRD-ROUTES] Instalando script em ${ROUTES_SCRIPT_DST}..."
cp "$ROUTES_SCRIPT_SRC" "$ROUTES_SCRIPT_DST"
chmod +x "$ROUTES_SCRIPT_DST"

# --- Instalar o arquivo de serviço ---
echo "[NETBIRD-ROUTES] Instalando serviço systemd em ${SERVICE_DST}..."
cp "$SERVICE_SRC" "$SERVICE_DST"

# --- Ativar e iniciar o serviço ---
echo "[NETBIRD-ROUTES] Recarregando systemd e habilitando serviço..."
systemctl daemon-reload
systemctl enable zabbix-routes.service

# Iniciamos aqui apenas se o Docker já estiver rodando.
# Na primeira execução (prepare_host), o Docker está ativo mas os containers
# ainda não existem — o serviço vai aguardar via docker events.
if systemctl is-active --quiet docker; then
    echo "[NETBIRD-ROUTES] Docker ativo. Iniciando serviço de rotas..."
    systemctl start zabbix-routes.service
    echo "[NETBIRD-ROUTES] Status do serviço:"
    systemctl status zabbix-routes.service --no-pager -l || true
else
    echo "[NETBIRD-ROUTES] Docker não está ativo ainda."
    echo "  O serviço será iniciado automaticamente no próximo boot."
fi

echo "[NETBIRD-ROUTES] Instalação do serviço de rotas finalizada."
