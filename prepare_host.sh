#!/bin/bash
set -e

echo "[PREPARE] Iniciando preparação do host para Zabbix Proxies..."

### 0. Aplicação de ajustes finos ###
echo "[PREPARE] Passo 0: Aplicando alterações de ajustes finos"
wget https://github.com/Josefellype/NewZabbixProxiesWithDocker/raw/refs/heads/main/Script_sysctl.sh
chmod +x Script_sysctl.sh
./Script_sysctl.sh

### 1. Configuração de timezone e NTP ###
echo "[PREPARE] Passo 1: Configurando timezone e NTP..."
timedatectl set-timezone America/Sao_Paulo
timedatectl set-ntp true

### 2. Instalação de dependências ###
echo "[PREPARE] Passo 2: Instalando dependências essenciais..."
apt-get update -y

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

### 4. Instalação e Configuração Zabbix Agent 2 para monitorar o host e os containers ###
echo "[PREPARE] Passo 4: Instalando e configurando o Zabbix Agent 2 para monitorar o host e os containers..."

# Baixar o pacote de configuração do repositório para Debian 12 (Bookworm)
wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-1+debian12_all.deb

# Instalar o pacote baixado
dpkg -i zabbix-release_7.0-1+debian12_all.deb

# Atualizar a lista de pacotes para incluir o novo repositório
apt update

# Instalar o agente principal e o plugin do Docker
apt install zabbix-agent2 zabbix-agent2-plugin-docker

### 5. Instalação e Configuração do Servidor SSH ###
echo "[PREPARE] Passo 5: Instalando e configurando o servidor SSH..."

# Instala o servidor OpenSSH e garante que o serviço esteja ativo
apt-get update -y && apt-get install -y openssh-server
systemctl enable ssh --now

# -- ETAPA DE SEGURANÇA: FAZER BACKUP DO ARQUIVO ORIGINAL --
# Fazemos isso para que seja sempre possível reverter para o original.
# O '-n' garante que não vamos sobrescrever um backup existente.
cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.orig

# -- FUNÇÃO AUXILIAR PARA ALTERAR CONFIGURAÇÕES --
# Esta função "upsert" (update or insert) torna nosso script mais limpo.
# Argumento 1: Chave (ex: "Port")
# Argumento 2: Valor (ex: "22")
upsert_ssh_config() {
    local key="$1"
    local value="$2"
    local config_file="/etc/ssh/sshd_config"

    echo "    -> Garantindo que '$key' seja '$value'..."

    # Primeiro, tenta encontrar e substituir a linha existente (comentada ou não).
    # A regex procura pelo início da linha (^), talvez um #, espaços, a chave, e substitui a linha toda.
    sed -i.bak -E "s/^\s*#?\s*${key}\s+.*/${key} ${value}/" "${config_file}"

    # Se, após a substituição, a linha ainda não existir, adiciona-a ao final do arquivo.
    if ! grep -q -E "^\s*${key}\s+${value}" "${config_file}"; then
        echo "${key} ${value}" >> "${config_file}"
    fi
}

# -- APLICAÇÃO DAS CONFIGURAÇÕES DESEJADAS --
# Usamos a função para cada parâmetro que você especificou.
upsert_ssh_config "PermitRootLogin" "yes"
upsert_ssh_config "PasswordAuthentication" "yes"
upsert_ssh_config "PubkeyAuthentication" "yes"
upsert_ssh_config "PermitEmptyPasswords" "no"
upsert_ssh_config "Port" "22"
upsert_ssh_config "ListenAddress" "0.0.0.0"
upsert_ssh_config "MaxSessions" "10"

# -- VALIDAÇÃO E REINICIALIZAÇÃO DO SERVIÇO --
echo "[PREPARE] Validando a nova configuração do SSH..."

# 'sshd -t' é o comando para testar a sintaxe do arquivo de configuração.
# Se o comando falhar, o script irá parar por causa do 'set -e'.
sshd -t

echo "[PREPARE] Reiniciando o serviço SSH para aplicar as mudanças..."
systemctl restart ssh

echo "[PREPARE] Configuração do SSH finalizada."

### 6. Configuração da Estrutura de Diretórios e Scripts ###
BASE_DIR="/zabbix-proxies"
HOOK_SCRIPT_NAME="docker-nft-hook"
HOOK_SCRIPT_PATH="${BASE_DIR}/${HOOK_SCRIPT_NAME}"
DOCKERFILE_PATH="${BASE_DIR}/Dockerfile"
ENTRYPOINT_PATH="${BASE_DIR}/entrypoint.sh"
COMPOSE_PATH="${BASE_DIR}/docker-compose.yml"

GITHUB_URL_NFT_HOOK="https://github.com/Josefellype/NewZabbixProxiesWithDocker/raw/refs/heads/main/docker-nft-hook" 

GITHUB_URL_DOCKERFILE="https://github.com/Josefellype/NewZabbixProxiesWithDocker/raw/refs/heads/main/Dockerfile"

GITHUB_URL_ENTRYPOINT="https://github.com/Josefellype/NewZabbixProxiesWithDocker/raw/refs/heads/main/entrypoint.sh"

GITHUB_URL_COMPOSE="https://github.com/Josefellype/NewZabbixProxiesWithDocker/raw/refs/heads/main/docker-compose.yml" 

echo "[PREPARE] Passo 6: Criando diretórios e baixando script de firewall..."
mkdir -p "$BASE_DIR"

# Baixa o script de firewall diretamente do GitHub
wget -O "${HOOK_SCRIPT_PATH}" "${GITHUB_URL_NFT_HOOK}"
chmod +x "${HOOK_SCRIPT_PATH}"

wget -O "${DOCKERFILE_PATH}" "${GITHUB_URL_DOCKERFILE}"
chmod +x "${DOCKERFILE_PATH}"

wget -O "${ENTRYPOINT_PATH}" "${GITHUB_URL_ENTRYPOINT}"
chmod +x "${ENTRYPOINT_PATH}"

wget -O "${COMPOSE_PATH}" "${GITHUB_URL_COMPOSE}"
chmod +x "${COMPOSE_PATH}"

# Loop para criar os subdiretórios dos volumes dos proxies
for i in 1 2 3 4; do
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/db_data"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/alertscripts"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/externalscripts"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/enc"
    mkdir -p "${BASE_DIR}/g${i}/prx${i}/mibs"
done

### 7. Configuração do Firewall com systemd (Execução no Boot) ###
SERVICE_NAME="firewall-docker-fix.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

echo "[PREPARE] Passo 7: Criando e habilitando serviço systemd para o firewall no boot..."

# Usamos 'cat <<EOF | tee' para escrever o conteúdo no arquivo de forma não interativa
cat <<EOF | tee "${SERVICE_PATH}"
[Unit]
Description=Custom NFTables rules for Docker routed network
# Adicionamos docker.service aqui. Nosso script agora roda DEPOIS do docker.
After=multi-user.target network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes

# Adicionamos uma pausa de 15 segundos como garantia extra.
# Isso dá tempo para a rede e o docker se estabilizarem completamente.
ExecStartPre=/bin/sleep 15
# O comando principal permanece o mesmo.
ExecStart=/zabbix-proxies/docker-nft-hook

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

### 8. Configuração do Cron (Verificação periódica) 

echo "[PREPARE] Passo 8: Configurando verificação periódica do firewall com cron..."

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

### 9. Usando o Cron (Verificação de 1 em 1 min) ###

echo "[PREPARE] Passo 9: Colocando o docker-firewall-check no /etc/cron.1min."

CRON_SCRIPT_NAME="docker-firewall-check"
CRON_SCRIPT_PATH="/etc/cron.1min/${CRON_SCRIPT_NAME}"

# Cria o script de verificação de forma não interativa
cat <<EOF | tee "${CRON_SCRIPT_PATH}"
#!/bin/bash
# Este script verifica se a regra principal do firewall existe.
# Se não existir, ele executa o hook principal para recriar tudo.

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