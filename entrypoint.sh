#!/bin/bash
set -e

echo "[entrypoint] Iniciando container Zabbix Proxy..."

# Garante que o diretório de log exista
echo "[entrypoint] Garantindo que o diretório de log exista..."
mkdir -p /var/log/zabbix
chown zabbix:zabbix /var/log/zabbix

# Gerar zabbix_proxy.conf a partir das variáveis
ZABBIX_CONF="/etc/zabbix/zabbix_proxy.conf"
echo "[entrypoint] Gerando $ZABBIX_CONF..."
# ... (aqui vai o seu bloco `cat <<EOF ...` que já está correto) ...
# (copie e cole a partir do seu script original)
cat <<EOF > $ZABBIX_CONF
Server=${ZBX_SERVER_HOST}
ServerPort=${ZBX_SERVER_PORT:-10051}
Hostname=${ZBX_HOSTNAME}
ProxyMode=${ZBX_PROXYMODE:-0}
DBName=zabbix_proxy
DBUser=zabbix
DBPassword=
LogType=file
LogFile=/var/log/zabbix/zabbix_proxy.log
LogFileSize=0
ProxyConfigFrequency=${ZBX_PROXYCONFIGFREQUENCY:-3600}
DataSenderFrequency=${ZBX_DATASENDERFREQUENCY:-1}
StartPollers=${ZBX_STARTPOLLERS:-5}
# ... (continue com o resto das suas variáveis) ...
AllowRoot=1
EOF

echo "[entrypoint] Configuração gerada."

# Inicia o Zabbix Proxy em PRIMEIRO PLANO (Foreground)
# Esta será a única e principal tarefa do container.
echo "[entrypoint] Iniciando Zabbix Proxy em primeiro plano..."
exec /usr/sbin/zabbix_proxy -f -c $ZABBIX_CONF