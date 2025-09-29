#!/bin/bash
set -e

echo "[SYSTEM] Iniciando configuração base do sistema..."

# --- Personalização do Prompt de Comando ---
echo "[SYSTEM] Configurando PS1..."
cat <<'EOF' > /etc/profile.d/ps1.sh
export PS1='\[\033[0;99m\][\[\033[0;96m\]\u\[\033[0;99m\]@\[\033[0;92m\]\h\[\033[0;99m\]] \[\033[1;38m\]\w \[\033[0;94m\][$(date +%k:%M:%S)]\[\033[0;99m\] \$\[\033[0m\] '
EOF
chmod +x /etc/profile.d/ps1.sh

# --- Aplicação de ajustes finos (sysctl) ---
echo "[SYSTEM] Aplicando ajustes de kernel (sysctl)..."
cat <<'EOF' > /etc/sysctl.d/95-zabbix-proxy-tuning.conf
# ===================================================================
# AJUSTES DE KERNEL OTIMIZADOS PARA ZABBIX PROXY EM HOST DE 16GB RAM
# ===================================================================
vm.min_free_kbytes = 131072
vm.swappiness = 1
vm.vfs_cache_pressure = 50
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
fs.file-max = 2000000
kernel.threads-max = 512000
kernel.panic = 3
EOF
# Aplicar imediatamente
sysctl --system

# --- Configuração de timezone e NTP ---
echo "[SYSTEM] Configurando timezone e NTP..."
timedatectl set-timezone America/Sao_Paulo
timedatectl set-ntp true

# --- Instalação de dependências essenciais ---
echo "[SYSTEM] Instalando dependências..."
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
    wget \
    nftables

# --- Instalação de ferramentas VMware (se aplicável) ---
if hostnamectl | grep -qi vmware; then
    echo "[SYSTEM] Ambiente VMware detectado. Instalando open-vm-tools..."
    apt-get -y install open-vm-tools
    systemctl enable --now open-vm-tools
fi

echo "[SYSTEM] Configuração base finalizada."