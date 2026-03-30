#!/bin/bash
set -e

# ============================================================
# MÓDULO 07 — Configuração do Container FRR
# ============================================================
# Este script lê os parâmetros de roteamento de um arquivo de
# configuração (/etc/zabbix-proxies/frr.env) e gera o frr.conf
# final a partir do template, instalando-o no diretório correto.
#
# ARQUIVO DE CONFIGURAÇÃO ESPERADO: /etc/zabbix-proxies/frr.env
# Formato (um parâmetro por linha, sem aspas necessárias):
#
#   FRR_HOSTNAME=nome-do-host-frr
#   ROUTER_ID=172.16.X.Y
#   LOCAL_ASN=64701
#   REMOTE_ASN=61621
#   BGP_NEIGHBOR=172.16.X.1
#   PROXY_SUBNET=172.16.3.48/28
#
# ============================================================

echo "[FRR] Iniciando configuração do container FRR..."

CONFIG_FILE="/zabbix-proxies/frr.env"
BASE_DIR="/zabbix-proxies"
FRR_DIR="${BASE_DIR}/frr"
TEMPLATE_PATH="${FRR_DIR}/frr.conf.template"
OUTPUT_PATH="${FRR_DIR}/frr.conf"

# --- Verificação do Arquivo de Configuração ---
if [ ! -f "$CONFIG_FILE" ]; then
    echo ""
    echo "[FRR] ERRO: Arquivo de configuração não encontrado em ${CONFIG_FILE}"
    echo ""
    echo "  Crie o arquivo antes de continuar. Exemplo:"
    echo ""
    echo "  cat > ${CONFIG_FILE} <<'EOF'"
    echo "  FRR_HOSTNAME=\$(hostname)"
    echo "  ROUTER_ID=172.16.X.Y"
    echo "  LOCAL_ASN=64701"
    echo "  REMOTE_ASN=61621"
    echo "  BGP_NEIGHBOR=172.16.X.1"
    echo "  PROXY_SUBNET=172.16.3.48/28"
    echo "  EOF"
    echo ""
    exit 1
fi

# --- Carregar Variáveis ---
echo "[FRR] Carregando parâmetros de ${CONFIG_FILE}..."
# Carregamos com 'set -a' para exportar automaticamente todas as variáveis
set -a
# shellcheck disable=SC1090
source "$CONFIG_FILE"
set +a

# --- Validação dos Parâmetros Obrigatórios ---
MISSING_PARAMS=()
[ -z "${FRR_HOSTNAME:-}" ]  && MISSING_PARAMS+=("FRR_HOSTNAME")
[ -z "${ROUTER_ID:-}" ]     && MISSING_PARAMS+=("ROUTER_ID")
[ -z "${LOCAL_ASN:-}" ]     && MISSING_PARAMS+=("LOCAL_ASN")
[ -z "${REMOTE_ASN:-}" ]    && MISSING_PARAMS+=("REMOTE_ASN")
[ -z "${BGP_NEIGHBOR:-}" ]  && MISSING_PARAMS+=("BGP_NEIGHBOR")
[ -z "${PROXY_SUBNET:-}" ]  && MISSING_PARAMS+=("PROXY_SUBNET")

if [ ${#MISSING_PARAMS[@]} -gt 0 ]; then
    echo "[FRR] ERRO: Os seguintes parâmetros estão ausentes em ${CONFIG_FILE}:"
    for param in "${MISSING_PARAMS[@]}"; do
        echo "  - ${param}"
    done
    exit 1
fi

echo "[FRR] Parâmetros carregados com sucesso:"
echo "  FRR_HOSTNAME : ${FRR_HOSTNAME}"
echo "  ROUTER_ID    : ${ROUTER_ID}"
echo "  LOCAL_ASN    : ${LOCAL_ASN}"
echo "  REMOTE_ASN   : ${REMOTE_ASN}"
echo "  BGP_NEIGHBOR : ${BGP_NEIGHBOR}"
echo "  PROXY_SUBNET : ${PROXY_SUBNET}"

# --- Verificar Template ---
if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "[FRR] ERRO: Template não encontrado em ${TEMPLATE_PATH}"
    echo "  Execute o módulo 05-prepare-proxy-deployment.sh antes deste módulo."
    exit 1
fi

# --- Gerar frr.conf a partir do Template ---
echo "[FRR] Gerando ${OUTPUT_PATH} a partir do template..."

# Usa um arquivo temporário para construir o resultado
TMP_CONF=$(mktemp)

# Substituição dos placeholders
sed \
    -e "s|__FRR_HOSTNAME__|${FRR_HOSTNAME}|g" \
    -e "s|__ROUTER_ID__|${ROUTER_ID}|g" \
    -e "s|__LOCAL_ASN__|${LOCAL_ASN}|g" \
    -e "s|__REMOTE_ASN__|${REMOTE_ASN}|g" \
    -e "s|__BGP_NEIGHBOR__|${BGP_NEIGHBOR}|g" \
    -e "s|__PROXY_SUBNET__|${PROXY_SUBNET}|g" \
    "$TEMPLATE_PATH" > "$TMP_CONF"

# Move para o destino final
mv "$TMP_CONF" "$OUTPUT_PATH"

echo "[FRR] frr.conf gerado com sucesso em ${OUTPUT_PATH}"
echo ""
echo "[FRR] Conteúdo gerado:"
echo "-----------------------------------------------------------"
cat "$OUTPUT_PATH"
echo "-----------------------------------------------------------"
echo ""
echo "[FRR] NOTA: As networks /32 dos IPs Netbird de cada proxy serão"
echo "            anunciadas automaticamente pelo serviço zabbix-routes"
echo "            após os containers subirem e o Netbird atribuir IPs."
echo ""
echo "[FRR] Configuração do FRR finalizada."
echo "[FRR] Para iniciar o container, execute dentro de ${BASE_DIR}:"
echo "      docker compose up -d frr-router"
