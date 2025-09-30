#!/bin/bash
set -e

echo "[DEPLOY] Iniciando preparação do ambiente de deployment dos proxies..."

BASE_DIR="/zabbix-proxies"
GITHUB_RAW_BASE="https://github.com/Josefellype/NewZabbixProxiesWithDocker/raw/refs/heads/main"

# Lista de arquivos a serem baixados
declare -A FILES=(
    ["docker-nft-hook"]="${GITHUB_RAW_BASE}/docker-nft-hook"
    ["Dockerfile"]="${GITHUB_RAW_BASE}/Dockerfile"
    ["docker-compose.yml"]="${GITHUB_RAW_BASE}/docker-compose.yml"
)

echo "[DEPLOY] Criando diretório base: ${BASE_DIR}"
mkdir -p "$BASE_DIR"

# Baixa os arquivos
for filename in "${!FILES[@]}"; do
    url="${FILES[$filename]}"
    path="${BASE_DIR}/${filename}"
    echo "[DEPLOY] Baixando ${url} no caminho ${path}..."
    wget -q -O "$path" "$url"
done

# Torna os scripts executáveis
chmod +x "${BASE_DIR}/docker-nft-hook"

# Loop para criar os subdiretórios dos volumes dos proxies
echo "[DEPLOY] Criando estrutura de volumes..."
for i in {1..4}; do
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/db_data"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/alertscripts"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/externalscripts"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/enc"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/mibs"
done

echo "[DEPLOY] Preparação do ambiente finalizada."