#!/bin/bash
set -e

echo "[FIREWALL] Iniciando configuração do serviço de firewall e cron..."

BASE_DIR="/zabbix-proxies"
HOOK_SCRIPT_PATH="${BASE_DIR}/docker-nft-hook"

# --- Configuração do systemd (Execução no Boot) ---
SERVICE_NAME="firewall-docker-fix.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

echo "[FIREWALL] Criando serviço systemd para o firewall no boot..."
cat <<EOF | tee "${SERVICE_PATH}"
[Unit]
Description=Custom NFTables rules for Docker routed network
After=multi-user.target network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 15
ExecStart=${HOOK_SCRIPT_PATH}

[Install]
WantedBy=multi-user.target
EOF

# Recarrega o systemd, habilita e inicia o serviço
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}"
echo "[FIREWALL] Verificando status do serviço systemd..."
systemctl status "${SERVICE_NAME}" --no-pager -l

echo "[FIREWALL] Configuração finalizada."