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

# --- Configuração do Cron (Verificação periódica) ---
CRON_JOB_PATH="/etc/cron.d/zabbix-firewall-check"
CRON_CHECK_LOG="/var/log/docker-hook-check.log"

echo "[FIREWALL] Configurando verificação periódica do firewall com cron..."

# Cria o arquivo de log para o script de verificação
touch "${CRON_CHECK_LOG}"

# Cria o script de verificação de forma mais simples e direta
cat <<EOF | tee "${CRON_JOB_PATH}"
# Executa a verificação do firewall a cada minuto
PATH=/usr/sbin:/usr/bin:/sbin:/bin

* * * * * root /usr/bin/flock -n /tmp/firewall-hook.lock bash -c '\
    SENTINEL_COMMENT="DOCKER_FORWARD_ACCEPT_RULE"; \
    RULE_COUNT=\$(nft list ruleset 2>/dev/null | grep "\$SENTINEL_COMMENT" | wc -l); \
    if [ "\$RULE_COUNT" -eq 0 ]; then \
        echo "Regra de firewall ausente em \$(date). Reaplicando..." >> ${CRON_CHECK_LOG}; \
        ${HOOK_SCRIPT_PATH}; \
    fi'
EOF

chmod 0644 "${CRON_JOB_PATH}"

echo "[FIREWALL] Configuração finalizada."