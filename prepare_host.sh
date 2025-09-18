#!/bin/bash
set -e

echo "[PREPARE] Iniciando preparação do host para Zabbix Proxies..."

### 1. Configuração de timezone e NTP ###
echo "[PREPARE] Passo 1: Configurando timezone e NTP..."
timedatectl set-timezone America/Sao_Paulo
timedatectl set-ntp true

### 2. Instalação de dependências ###
echo "[PREPARE] Passo 2: Instalando dependências essenciais..."
apt-get update -y
# Adicionamos nftables aqui para garantir que a ferramenta esteja disponível
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    net-tools \
    iproute2 \
    iputils-ping \
    nftables

### 3. Repositório e instalação do Docker ###
echo "[PREPARE] Passo 3: Instalando Docker Engine e Compose..."

# Remove versões antigas do Docker para evitar conflitos
apt-get remove -y docker docker-engine docker.io containerd runc || true

# Adiciona a chave GPG e o repositório oficial do Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

### 4. Configuração da Estrutura de Diretórios e Scripts ###
BASE_DIR="/zabbix-proxies"
HOOK_SCRIPT_NAME="docker-nft-hook"
HOOK_SCRIPT_PATH="${BASE_DIR}/${HOOK_SCRIPT_NAME}"

echo "[PREPARE] Passo 4: Criando diretórios e movendo script de firewall para ${BASE_DIR}..."
mkdir -p "$BASE_DIR"

# Move o script de firewall da raiz para o diretório de trabalho
# Assumimos que o script está na mesma pasta que o prepare_host.sh
mv "./${HOOK_SCRIPT_NAME}" "${HOOK_SCRIPT_PATH}"
chmod +x "${HOOK_SCRIPT_PATH}"

# Loop para criar os subdiretórios dos volumes dos proxies
for i in {1..4}; do
    mkdir -p "${BASE_DIR}/g${i}/prx1/db_data"
    mkdir -p "${BASE_DIR}/g${i}/prx1/alertscripts"
    mkdir -p "${BASE_DIR}/g${i}/prx1/externalscripts"
    mkdir -p "${BASE_DIR}/g${i}/prx1/enc"
    mkdir -p "${BASE_DIR}/g${i}/prx1/mibs"
done

### 5. Configuração do Firewall com systemd (Execução no Boot) ###
SERVICE_NAME="firewall-docker-fix.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

echo "[PREPARE] Passo 5: Criando e habilitando serviço systemd para o firewall no boot..."

# Usamos 'cat <<EOF | tee' para escrever o conteúdo no arquivo de forma não interativa
cat <<EOF | tee "${SERVICE_PATH}"
[Unit]
Description=Custom NFTables rules for Docker routed network
After=network-online.target docker.service
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
# Executa o script uma vez agora para aplicar as regras imediatamente
systemctl start "${SERVICE_NAME}"

echo "[PREPARE] Verificando status do serviço de firewall..."
systemctl status "${SERVICE_NAME}" --no-pager -l

echo "[PREPARE] Passo 6: Configurando verificação periódica do firewall com cron..."

    # Criar diretorios dos scripts periodicos:
    # - intervalos curtos
    mkdir -p /etc/cron.1min
    mkdir -p /etc/cron.5min
    mkdir -p /etc/cron.10min
    mkdir -p /etc/cron.15min
    mkdir -p /etc/cron.30min
    # - intervalos basicos
    mkdir -p /etc/cron.hourly
    mkdir -p /etc/cron.daily
    mkdir -p /etc/cron.weekly
    mkdir -p /etc/cron.monthly
    # - agendadores de dias da semana
    mkdir -p /etc/cron.monday
    mkdir -p /etc/cron.tuesday
    mkdir -p /etc/cron.wednesday
    mkdir -p /etc/cron.thursday
    mkdir -p /etc/cron.friday
    mkdir -p /etc/cron.saturday
    mkdir -p /etc/cron.sunday


# Criar config de contrab
(
    echo "PATH=/usr/sbin:/usr/bin:/sbin:/bin"
    echo "0  *  *  *  *  run-parts --regex '.*' /etc/cron.hourly"
    echo "0  2  *  *  *  run-parts --regex '.*' /etc/cron.daily"
    echo "0  3  *  *  6  run-parts --regex '.*' /etc/cron.weekly"
    echo "0  5  1  *  *  run-parts --regex '.*' /etc/cron.monthly"
    for min in 1 5 10 15 30; do
        echo "*/$min  *  *  *  *  run-parts --regex '.*' /etc/cron.${min}min"
    done
    echo "0  0  *  *  0  run-parts --regex '.*' /etc/cron.sunday"
    echo "0  0  *  *  1  run-parts --regex '.*' /etc/cron.monday"
    echo "0  0  *  *  2  run-parts --regex '.*' /etc/cron.tuesday"
    echo "0  0  *  *  3  run-parts --regex '.*' /etc/cron.wednesday"
    echo "0  0  *  *  4  run-parts --regex '.*' /etc/cron.thursday"
    echo "0  0  *  *  5  run-parts --regex '.*' /etc/cron.friday"
    echo "0  0  *  *  6  run-parts --regex '.*' /etc/cron.saturday"
) > /tmp/cron-list

# Registrar no crontab:
cat /tmp/cron-list | crontab -

# Conferir se instalou agendadores:
crontab -l

# Cria o arquivo de log para o script de verificação
touch /var/log/docker-hook-check.log

### 6. Configuração do Cron (Verificação Periódica) ###
CRON_SCRIPT_NAME="docker-firewall-check"
CRON_SCRIPT_PATH="/etc/cron.1min/${CRON_SCRIPT_NAME}"

# Cria o script de verificação de forma não interativa
cat <<EOF | tee "${CRON_SCRIPT_PATH}"
#!/bin/bash
# Este script verifica se a regra principal do firewall existe.
# Se não existir, ele executa o hook principal para recriar tudo.

"Script de verificação de firewall executado em $(date)" >> /var/log/docker-hook-check.log

SENTINEL_COMMENT="DOCKER_FORWARD_ACCEPT_RULE"
RULE_COUNT=\$(nft list ruleset 2>/dev/null | grep "\$SENTINEL_COMMENT" | wc -l)

if [ "\$RULE_COUNT" -eq 0 ]; then
    echo "Regra de firewall ausente em \$(date). Reaplicando..." >> /var/log/docker-hook-check.log
    /usr/bin/flock -n /tmp/firewall-hook.lock ${HOOK_SCRIPT_PATH}
fi

exit 0
EOF

# Torna o script de verificação executável
chmod +x "${CRON_SCRIPT_PATH}"

echo "[PREPARE] Configuração do cron finalizada."

### Conclusão ###
echo ""
echo "[PREPARE] Host preparado com sucesso!"
echo "----------------------------------------------------"
echo "Próximos Passos Recomendados:"
echo "1. Mova seus arquivos (docker-compose.yml, Dockerfile, etc.) para ${BASE_DIR}"
echo "2. Reinicie o host para garantir que o serviço de boot funciona: 'systemctl reboot'"
echo "3. Após reiniciar, navegue para ${BASE_DIR} e suba os containers: 'docker compose up -d --build'"
echo "----------------------------------------------------"