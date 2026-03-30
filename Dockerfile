# Usa a imagem oficial do Zabbix Proxy como base
FROM zabbix/zabbix-proxy-sqlite3:7.0.12-ubuntu

USER root

# Instala dependências, repositório do Netbird e as ferramentas de rede
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg ca-certificates \
    iputils-ping iproute2 dnsutils traceroute netcat-openbsd nano && \
    curl -fsSL https://pkgs.netbird.io/debian/public.key | gpg --dearmor -o /usr/share/keyrings/netbird.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/netbird.gpg] https://pkgs.netbird.io/debian stable main" > /etc/apt/sources.list.d/netbird.list && \
    apt-get update && apt-get install -y netbird && \
    rm -rf /var/lib/apt/lists/*

# Copia o nosso script customizado
COPY entrypoint.sh /custom-entrypoint.sh

# Altera o entrypoint padrão para o nosso script
ENTRYPOINT ["/custom-entrypoint.sh"]

# Mantém o comando original que o entrypoint do Zabbix espera receber
CMD ["/usr/sbin/zabbix_proxy", "-c", "/etc/zabbix/zabbix_proxy.conf", "-f"]