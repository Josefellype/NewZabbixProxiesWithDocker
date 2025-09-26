# ===================================================================
# AJUSTES DE KERNEL OTIMIZADOS PARA ZABBIX PROXY EM HOST DE 16GB RAM
# ===================================================================

# --- Memória Virtual e Cache (CRÍTICO PARA SQLITE) ---

# Manter 128MB de RAM livres para operações críticas do kernel
vm.min_free_kbytes = 131072

# Usar swap apenas em emergências extremas. Priorizar manter a aplicação em RAM.
vm.swappiness = 1

# Fortemente priorizar o cache de metadados do sistema de arquivos (melhora performance do SQLite).
vm.vfs_cache_pressure = 50


# --- Rede (Otimizado para alto número de conexões) ---

# Usar o algoritmo de controle de congestionamento BBR do Google (requer qdisc fq)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Aumentar o tamanho da fila de conexões TCP pendentes
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 8192

# Aumentar ligeiramente os buffers de memória TCP (valores seguros para 1Gbps)
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Usar toda a faixa de portas altas para conexões de saída
net.ipv4.ip_local_port_range = 1024 65535

# Reutilizar sockets no estado TIME-WAIT mais rapidamente. Útil para alto volume de conexões.
net.ipv4.tcp_tw_reuse = 1


# --- Limites do Sistema (Segurança e Capacidade) ---

# Aumentar o limite total de arquivos abertos no sistema
fs.file-max = 2000000

# Aumentar o limite máximo de threads do kernel
kernel.threads-max = 512000

# Reiniciar o sistema 3 segundos após um Kernel Panic
kernel.panic = 3