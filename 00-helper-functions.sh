#!/bin/bash
# Este script não deve ser executado diretamente.
# Ele serve como uma biblioteca para ser 'source' por outros scripts.

# Função "upsert" (update or insert)
upsert_config() {
    local config_file="$1"
    local key="$2"
    local value="$3"
    echo "    -> Garantindo que '$key' seja '$value'..."
    sed -i.bak -E "s/^\s*#?\s*${key}\s+.*/${key} ${value}/" "${config_file}"
    if ! grep -q -E "^\s*${key}\s+${value}" "${config_file}"; then
        echo "${key} ${value}" >> "${config_file}"
    fi
}

# Função para COMENTAR um parâmetro
comment_config() {
    local config_file="$1"
    local key="$2"
    echo "    -> Garantindo que o parâmetro '$key' esteja comentado..."
    sed -i.bak -E "s/^\s*${key}\s+.*/# &/" "${config_file}"
}

# Função para DESCOMENTAR um parâmetro
uncomment_config() {
    local config_file="$1"
    local key="$2"
    echo "    -> Garantindo que o parâmetro '$key' esteja ativo (descomentado)..."
    sed -i.bak -E "s/^\s*#\s*(${key}\s+.*)/\1/" "${config_file}"
}