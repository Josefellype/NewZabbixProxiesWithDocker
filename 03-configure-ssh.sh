#!/bin/bash
set -e

# Carrega as funções auxiliares
source ./00-helper-functions.sh

echo "[SSH] Iniciando instalação e configuração do servidor SSH..."

# Instala o servidor OpenSSH e garante que o serviço esteja ativo
apt-get update -y && apt-get install -y openssh-server
systemctl enable ssh --now

# Faz backup do arquivo original, se não existir um
cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.orig

# Aplica as configurações desejadas
upsert_config "/etc/ssh/sshd_config" "PermitRootLogin" "yes"
upsert_config "/etc/ssh/sshd_config" "PasswordAuthentication" "yes"
upsert_config "/etc/ssh/sshd_config" "PubkeyAuthentication" "yes"
upsert_config "/etc/ssh/sshd_config" "PermitEmptyPasswords" "no"
upsert_config "/etc/ssh/sshd_config" "Port" "22"
upsert_config "/etc/ssh/sshd_config" "ListenAddress" "0.0.0.0"
upsert_config "/etc/ssh/sshd_config" "MaxSessions" "10"

# Valida a nova configuração
echo "[SSH] Validando a nova configuração..."
sshd -t

# Reinicia o serviço para aplicar as mudanças
echo "[SSH] Reiniciando o serviço SSH..."
systemctl restart ssh

echo "[SSH] Configuração finalizada."