#!/bin/bash

echo "Iniciando daemon de monitoramento de rotas do Netbird..."

# =========================================================
# CONFIGURAÇÃO
# =========================================================
# Nome do container FRR para executar comandos vtysh
FRR_CONTAINER="frr-bgp-lem"

# =========================================================
# FUNÇÃO: Injetar network no FRR via vtysh (dentro do container)
# =========================================================
# Argumento 1: IP Netbird do proxy (ex: 10.255.255.69)
# Argumento 2: nome do container (para log)
anunciar_network_frr() {
    local NETBIRD_IP="$1"
    local CONTAINER="$2"

    # Verifica se o container FRR está rodando antes de tentar
    if ! docker ps --format '{{.Names}}' | grep -q "^${FRR_CONTAINER}$"; then
        echo "[$CONTAINER] AVISO: Container FRR '${FRR_CONTAINER}' não está rodando. Pulando anúncio BGP."
        return 0
    fi

    echo "[$CONTAINER] Anunciando ${NETBIRD_IP}/32 via BGP no FRR..."

    docker exec "$FRR_CONTAINER" vtysh \
        -c "configure terminal" \
        -c "router bgp" \
        -c " address-family ipv4 unicast" \
        -c "  network ${NETBIRD_IP}/32" \
        -c " exit-address-family" \
        -c "exit" \
        -c "end" \
        -c "write memory" 2>/dev/null \
        && echo "[$CONTAINER] BGP network ${NETBIRD_IP}/32 anunciada e salva no FRR." \
        || echo "[$CONTAINER] AVISO: Falha ao anunciar ${NETBIRD_IP}/32 no FRR (não crítico)."
}

# =========================================================
# FUNÇÃO: Remover network do FRR via vtysh
# =========================================================
remover_network_frr() {
    local NETBIRD_IP="$1"
    local CONTAINER="$2"

    if ! docker ps --format '{{.Names}}' | grep -q "^${FRR_CONTAINER}$"; then
        return 0
    fi

    echo "[$CONTAINER] Removendo ${NETBIRD_IP}/32 do anúncio BGP no FRR..."

    docker exec "$FRR_CONTAINER" vtysh \
        -c "configure terminal" \
        -c "router bgp" \
        -c " address-family ipv4 unicast" \
        -c "  no network ${NETBIRD_IP}/32" \
        -c " exit-address-family" \
        -c "exit" \
        -c "end" \
        -c "write memory" 2>/dev/null \
        && echo "[$CONTAINER] BGP network ${NETBIRD_IP}/32 removida do FRR." \
        || echo "[$CONTAINER] AVISO: Falha ao remover ${NETBIRD_IP}/32 do FRR (não crítico)."
}

# =========================================================
# FUNÇÃO: Configurar rota para um container específico
# =========================================================
configurar_rota() {
    local CONTAINER=$1
    echo "---------------------------------------------------"
    echo "[$CONTAINER] Iniciando analise de rotas..."

    # Aguarda a placa de rede do container estabilizar
    sleep 5

    local CONTAINER_IP
    CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER" 2>/dev/null)

    if [ -z "$CONTAINER_IP" ]; then
        echo "[$CONTAINER] Falha ao obter o IP de bridge. Pulando..."
        return 1
    fi

    local MAX_RETRIES=20
    local COUNT=0
    local NETBIRD_IP=""

    # Loop de espera inteligente — aguarda o Netbird atribuir IP
    while [ $COUNT -lt $MAX_RETRIES ]; do
        local RAW_IP
        RAW_IP=$(docker exec "$CONTAINER" netbird status 2>/dev/null | grep "NetBird IP:" | awk '{print $3}' | cut -d'/' -f1)

        if [[ "$RAW_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            NETBIRD_IP="$RAW_IP"
            break
        fi

        echo "[$CONTAINER] Aguardando Netbird (Status: ${RAW_IP:-Nenhum}). Tentativa $((COUNT+1))/$MAX_RETRIES..."
        sleep 6
        COUNT=$((COUNT+1))
    done

    if [ -z "$NETBIRD_IP" ]; then
        echo "[$CONTAINER] Falha: Netbird nao conectou dentro do tempo limite."
        return 1
    fi

    echo "[$CONTAINER] Sucesso -> Gateway: $CONTAINER_IP | Destino: $NETBIRD_IP"

    # --- Injetar rota estática no host ---
    ip route del "${NETBIRD_IP}/32" 2>/dev/null || true
    ip route add "${NETBIRD_IP}/32" via "$CONTAINER_IP"
    echo "[$CONTAINER] Rota INJETADA no host: ${NETBIRD_IP}/32 via ${CONTAINER_IP}"

    # --- Anunciar network no FRR via BGP ---
    anunciar_network_frr "$NETBIRD_IP" "$CONTAINER"
}

# =========================================================
# FUNÇÃO: Limpar rota quando container para
# =========================================================
limpar_rota() {
    local CONTAINER=$1
    echo "---------------------------------------------------"
    echo "[$CONTAINER] Container parado. Verificando rotas para limpar..."

    # Tenta obter o IP Netbird do histórico de rotas do sistema
    # (já que o container não está mais rodando)
    # Abordagem: lista rotas e tenta identificar /32 que foram via este container

    # Esta etapa é best-effort: se o container reiniciar, configurar_rota vai corrigir.
    echo "[$CONTAINER] Limpeza de rota será corrigida no próximo start do container."
}

# =========================================================
# FASE 1: Varredura Inicial (Cold Boot)
# =========================================================
# Pega os containers que já estão rodando no momento em que o script liga
CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep "zabbix-proxy" || true)

if [ -n "$CONTAINERS" ]; then
    echo "Containers zabbix-proxy já rodando:"
    echo "$CONTAINERS"
    for c in $CONTAINERS; do
        # O '&' comercial joga a função para segundo plano,
        # permitindo processar todos os proxies em paralelo!
        configurar_rota "$c" &
    done
fi

# =========================================================
# FASE 2: Monitoramento Contínuo (Real-Time via Docker Events)
# =========================================================
echo "Entrando em modo de escuta continua (Docker Events)..."

# Fica escutando silenciosamente os eventos do Docker
docker events \
    --filter 'type=container' \
    --filter 'event=start' \
    --filter 'event=die' \
    --format '{{.Status}} {{.Actor.Attributes.name}}' | while read -r EVENT_STATUS CONTAINER_NAME; do

    # Filtra apenas containers zabbix-proxy
    if [[ "$CONTAINER_NAME" != *"zabbix-proxy"* ]]; then
        continue
    fi

    if [ "$EVENT_STATUS" = "start" ]; then
        echo ">>> Gatilho 'start' disparado: O container '$CONTAINER_NAME' iniciou!"
        configurar_rota "$CONTAINER_NAME" &

    elif [ "$EVENT_STATUS" = "die" ]; then
        echo ">>> Gatilho 'die' disparado: O container '$CONTAINER_NAME' parou!"
        limpar_rota "$CONTAINER_NAME" &
    fi
done