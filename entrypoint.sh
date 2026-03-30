#!/bin/bash

echo "[entrypoint] Iniciando container..."

# 1. FORÇA O USERSPACE NA RAIZ DO PROCESSO
# Isso impede que os proxies briguem pelo Kernel WireGuard do host
export WG_DISABLE_KERNEL=true
export NB_WG_DISABLE_KERNEL=true
export NB_USE_USERSPACE_WG=true

echo "[entrypoint] Iniciando Netbird service em background..."
netbird service run &

sleep 3

# 2. O Delay anti-colisão
SLEEP_TIME=$((5 + RANDOM % 15))
echo "[entrypoint] Aguardando $SLEEP_TIME segundos..."
sleep $SLEEP_TIME

# 3. Verifica o caminho CORRETO da configuração
if [ ! -f /var/lib/netbird/config.json ]; then
    echo "[entrypoint] Registrando novo peer com Netbird..."
    netbird up --setup-key "${NETBIRD_SETUP_KEY}" --management-url "${NETBIRD_MGMT_URL}" --wireguard-port "${NB_WG_PORT}" || true
else
    echo "[entrypoint] Identidade persistente encontrada, apenas conectando..."
    netbird up --management-url "${NETBIRD_MGMT_URL}" || true
fi

echo "[entrypoint] Status da conexão VPN:"
netbird status || true

echo "[entrypoint] Iniciando o Zabbix Proxy..."
exec /usr/bin/docker-entrypoint.sh "$@"