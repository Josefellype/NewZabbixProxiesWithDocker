#!/bin/bash
# Este script não deve ser executado diretamente.
# Ele serve como uma biblioteca para ser 'source' por outros scripts.

# Função "upsert" (update or insert) aprimorada e idempotente
# Argumento 1: Caminho do arquivo de configuração
# Argumento 2: Chave do parâmetro
# Argumento 3: Valor do parâmetro
upsert_config() {
    local config_file="$1"
    local key="$2"
    local value="$3"
    local temp_file="${config_file}.tmp"

    echo "    -> Garantindo que '${key}' seja '${value}'..."

    # 1. Remove todas as ocorrências da chave (comentadas ou não) do arquivo.
    #    A regex procura por linhas que começam com espaços, talvez um '#', a chave, e um '='.
    #    O 'grep -v' inverte a busca, mantendo todas as linhas que NÃO correspondem.
    grep -vE "^\s*#?\s*${key}\s*=" "${config_file}" > "${temp_file}"

    # 2. Adiciona a linha correta e formatada no final do arquivo temporário.
    echo "${key}=${value}" >> "${temp_file}"

    # 3. Substitui o arquivo original pelo temporário, já corrigido.
    mv "${temp_file}" "${config_file}"

    # Opcional: restaura as permissões e o dono do arquivo original, se necessário.
    if [ -f "${config_file}.bak" ]; then
        chown --reference="${config_file}.bak" "${config_file}"
        chmod --reference="${config_file}.bak" "${config_file}"
        rm "${config_file}.bak" # Limpa o backup do sed anterior, se houver
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