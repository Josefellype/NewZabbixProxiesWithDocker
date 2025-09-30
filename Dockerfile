# Usa a imagem oficial do Zabbix Proxy como base
FROM zabbix/zabbix-proxy-sqlite3:7.0.12-ubuntu

# Muda para o usuário root para instalar pacotes
USER root

# Instala apenas as ferramentas de diagnóstico e manutenção necessárias
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Ferramentas de rede
    iputils-ping \
    iproute2 \
    dnsutils \
    traceroute \
    netcat-openbsd \
    # Editor de texto
    nano \
    && rm -rf /var/lib/apt/lists/*