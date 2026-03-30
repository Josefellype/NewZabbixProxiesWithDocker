#!/bin/bash
set -e

echo "[DEPLOY] Iniciando preparação do ambiente de deployment dos proxies..."

BASE_DIR="/zabbix-proxies"
FRR_DIR="${BASE_DIR}/frr"
GITHUB_RAW_BASE="https://github.com/Josefellype/NewZabbixProxiesWithDocker/raw/refs/heads/main"

# --------------------------------------------------------
# Lista de arquivos a serem baixados (formato: destino=url)
# --------------------------------------------------------

# Arquivos do diretório raiz
declare -A FILES=(
    ["docker-nft-hook"]="${GITHUB_RAW_BASE}/docker-nft-hook"
    ["Dockerfile"]="${GITHUB_RAW_BASE}/Dockerfile"
    ["docker-compose.yml"]="${GITHUB_RAW_BASE}/docker-compose.yml"
    ["entrypoint.sh"]="${GITHUB_RAW_BASE}/entrypoint.sh"
    ["zabbix-netbird-routes.sh"]="${GITHUB_RAW_BASE}/zabbix-netbird-routes.sh"
    ["zabbix-routes.service"]="${GITHUB_RAW_BASE}/zabbix-routes.service"
)

# Arquivos do subdiretório frr/
declare -A FRR_FILES=(
    ["daemons"]="${GITHUB_RAW_BASE}/frr/daemons"
    ["frr.conf.template"]="${GITHUB_RAW_BASE}/frr/frr.conf.template"
)

# --------------------------------------------------------
# Criação dos diretórios base
# --------------------------------------------------------
echo "[DEPLOY] Criando diretório base: ${BASE_DIR}"
mkdir -p "$BASE_DIR"

echo "[DEPLOY] Criando diretório FRR: ${FRR_DIR}"
mkdir -p "$FRR_DIR"

# --------------------------------------------------------
# Download dos arquivos raiz
# --------------------------------------------------------
for filename in "${!FILES[@]}"; do
    url="${FILES[$filename]}"
    path="${BASE_DIR}/${filename}"
    echo "[DEPLOY] Baixando ${filename}..."
    wget -q -O "$path" "$url"
done

# --------------------------------------------------------
# Download dos arquivos FRR
# --------------------------------------------------------
for filename in "${!FRR_FILES[@]}"; do
    url="${FRR_FILES[$filename]}"
    path="${FRR_DIR}/${filename}"
    echo "[DEPLOY] Baixando frr/${filename}..."
    wget -q -O "$path" "$url"
done

# --------------------------------------------------------
# Permissões de execução
# --------------------------------------------------------
chmod +x "${BASE_DIR}/docker-nft-hook"
chmod +x "${BASE_DIR}/entrypoint.sh"
chmod +x "${BASE_DIR}/zabbix-netbird-routes.sh"

# --------------------------------------------------------
# Criação dos subdiretórios dos volumes dos proxies
# --------------------------------------------------------
echo "[DEPLOY] Criando estrutura de volumes dos proxies..."
for i in {1..4}; do
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/db_data"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/alertscripts"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/externalscripts"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/enc"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/mibs"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/netbird"
done

# O frr.env fica dentro do próprio diretório /zabbix-proxies
# (o diretório já foi criado acima — não é necessário mkdir separado)

# Cria o arquivo frr.env de exemplo apenas se não existir (não sobrescreve)
FRR_ENV_FILE="/zabbix-proxies/frr.env"
if [ ! -f "$FRR_ENV_FILE" ]; then
    echo "[DEPLOY] Criando arquivo de configuração de exemplo: ${FRR_ENV_FILE}"
    cat > "$FRR_ENV_FILE" <<'EOF'
# ============================================================
# Parâmetros de Configuração do FRR (BGP)
# ============================================================
# Preencha estes valores ANTES de executar o módulo 07.
# Verifique os valores com a equipe de redes antes de aplicar.
# ============================================================

# Hostname identificador desta instância do FRR
# Padrão: hostname do sistema (substituir pelo nome descritivo)
FRR_HOSTNAME=MEU-HOST-ZBX-PROXIES

# IP do router-id BGP (geralmente o IP da interface de gerência do host)
# OBRIGATÓRIO: deve ser um IP válido e único na rede BGP
ROUTER_ID=172.16.X.Y

# ASN (Autonomous System Number) local deste roteador
LOCAL_ASN=64701

# ASN remoto dos Route Reflectors (peers BGP)
REMOTE_ASN=61621

# IP do vizinho BGP direto (gateway da rede de gerência)
BGP_NEIGHBOR=172.16.X.1

# Sub-rede Docker dos containers proxy (definida no docker-compose.yml)
PROXY_SUBNET=172.16.3.48/28
EOF
    echo "[DEPLOY] ATENÇÃO: Edite ${FRR_ENV_FILE} com os valores corretos antes de continuar!"
else
    echo "[DEPLOY] Arquivo ${FRR_ENV_FILE} já existe. Não foi sobrescrito."
fi

echo "[DEPLOY] Preparação do ambiente finalizada."
echo ""
echo "PRÓXIMO PASSO OBRIGATÓRIO:"
echo "  Edite o arquivo de configuração do FRR antes de continuar:"
echo "  nano ${FRR_ENV_FILE}"