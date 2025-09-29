#!/bin/bash
set -e

# Carrega as funções auxiliares
source ./00-helper-functions.sh

echo "[ZABBIX-AGENT] Iniciando instalação e configuração do Zabbix Agent 2..."

# Adiciona o repositório do Zabbix 7.0
wget -q https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-1+debian12_all.deb
dpkg -i zabbix-release_7.0-1+debian12_all.deb
apt-get update -y

# Instala o agente (o plugin do Docker já vem incluído)
apt-get install -y zabbix-agent2

# Configura o agente
upsert_config "/etc/zabbix/zabbix_agent2.conf" "Server" "100.76.180.207,172.16.9.78"
upsert_config "/etc/zabbix/zabbix_agent2.conf" "ServerActive" "100.76.180.207,172.16.9.78"
comment_config "/etc/zabbix/zabbix_agent2.conf" "Hostname"
uncomment_config "/etc/zabbix/zabbix_agent2.conf" "HostnameItem"

# Adiciona o usuário 'zabbix' ao grupo 'docker'
usermod -aG docker zabbix

# Reinicia e habilita o serviço
systemctl restart zabbix-agent2
systemctl enable zabbix-agent2

echo "[ZABBIX-AGENT] Instalação finalizada. Verificando status..."
systemctl status zabbix-agent2 --no-pager -l