#!/bin/bash
set -e

echo "==========================================================="
echo "== Inciando Orquestração de Preparação do Host Zabbix Proxy =="
echo "==========================================================="

# URL base para download dos scripts dos módulos
GITHUB_URL_BASE="https://github.com/Josefellype/NewZabbixProxiesWithDocker/raw/refs/heads/main/"

# Diretório de trabalho temporário para os scripts
# Isso mantém a execução limpa e isolada.
SCRIPT_DIR="/tmp/zabbix-host-prep-$(date +%s)"
mkdir -p "$SCRIPT_DIR"
cd "$SCRIPT_DIR"

echo "Scripts serão baixados e executados em: ${SCRIPT_DIR}"

# Lista de TODOS os scripts necessários para o processo, incluindo a biblioteca de funções.
SCRIPTS_TO_DOWNLOAD=(
    "00-helper-functions.sh"
    "01-setup-system-basics.sh"
    "02-install-docker.sh"
    "03-configure-ssh.sh"
    "04-install-zabbix-agent.sh"
    "05-prepare-proxy-deployment.sh"
    "06-configure-firewall.sh"
)

# --- Etapa 1: Download de todos os Módulos ---
echo -e "\n----- Baixando módulos de preparação... -----"
for script_name in "${SCRIPTS_TO_DOWNLOAD[@]}"; do
    script_url="${GITHUB_URL_BASE}${script_name}"
    echo "Baixando ${script_name}..."
    
    # Baixa o script para o diretório de trabalho. O '-q' é modo silencioso.
    wget -q -O "${script_name}" "${script_url}"
    
    # Verifica se o download foi bem-sucedido
    if [ $? -ne 0 ]; then
        echo "[ERRO] Falha ao baixar ${script_name}. Verifique a URL e a conexão. Abortando."
        exit 1
    fi
done
echo "----- Download de todos os módulos concluído. -----"


# --- Etapa 2: Execução dos Módulos em Ordem ---
# A lista de execução não precisa do '00-helper-functions.sh', pois ele é chamado internamente pelos outros.
MODULES_TO_EXECUTE=(
    "01-setup-system-basics.sh"
    "02-install-docker.sh"
    "03-configure-ssh.sh"
    "04-install-zabbix-agent.sh"
    "05-prepare-proxy-deployment.sh"
    "06-configure-firewall.sh"
)

for module in "${MODULES_TO_EXECUTE[@]}"; do
    # O caminho é relativo ao diretório de trabalho atual.
    module_path="./${module}"
    
    echo -e "\n----- Executando Módulo: ${module} -----"
    chmod +x "$module_path"
    "$module_path"
    echo "----- Módulo ${module} finalizado com sucesso. -----"
done

echo -e "\n=========================================================="
echo "== Host preparado com sucesso! =="
echo "----------------------------------------------------"
echo "Próximos Passos Recomendados:"
echo "1. Reinicie o host para garantir que os serviços de boot (firewall, docker) funcionem: 'sudo systemctl reboot'"
echo "2. Após reiniciar, navegue para /zabbix-proxies e suba os containers: 'docker compose up -d --build'"
echo "----------------------------------------------------"
echo "Limpando diretório de scripts temporários: ${SCRIPT_DIR}"
cd /
rm -rf "${SCRIPT_DIR}"