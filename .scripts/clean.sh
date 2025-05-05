#!/usr/bin/env bash

directories=(
    # "$HOME/.cache"
    "/var/log"
)

DEFAULT_DAYS_OLD=7
DAYS_OLD=$DEFAULT_DAYS_OLD

SHOULD_CLEAN_JOURNAL=false
DRY_RUN=false
VERBOSE=false

log_message() {
    echo "[INFO] $1"
}

log_verbose() {
    if $VERBOSE; then
        echo "[VERBOSE] $1"
    fi
}

log_warning() {
    echo "[WARN] $1" >&2
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

show_usage_menu() {
    echo "Uso: $0 [OPÇÕES]"
    echo "Limpa arquivos antigos em diretórios específicos."
    echo
    echo "Opções:"
    echo "  -d, --days N      Define a idade mínima (em dias) dos arquivos a serem removidos (padrão: $DEFAULT_DAYS_OLD)."
    echo "  --dir DIR         Adiciona um diretório à lista de limpeza (pode ser usado várias vezes)."
    echo "  --dry-run         Simula a execução sem remover arquivos."
    echo "  -v, --verbose     Mostra mais detalhes sobre os arquivos encontrados."
    echo "  --clean-journal   Limpa os logs do systemd journal (requer sudo)."
    echo "  -h, --help        Mostra esta ajuda."
    echo
    echo "Diretórios padrão:"

    if [ ${#directories[@]} -gt 0 ]; then
        for dir in "${directories[@]}"; do
            echo "  - $dir"
        done
    else
        echo "  (Nenhum diretório padrão configurado ou todos foram substituídos por --dir)"
    fi
    exit 0
}

custom_dirs=()
while [[ "$#" -gt 0 ]]; do
    case $1 in
    -d | --days)

        if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
            DAYS_OLD="$2"
            shift
        else
            log_error "Opção '$1' requer um número inteiro como argumento."
        fi
        ;;
    --dir)

        if [[ -n "$2" ]]; then
            custom_dirs+=("$2")
            shift
        else
            log_error "Opção '--dir' requer um caminho de diretório como argumento."
        fi
        ;;
    --dry-run) DRY_RUN=true ;;
    --clean-journal) SHOULD_CLEAN_JOURNAL=true ;;
    -v | --verbose) VERBOSE=true ;;
    -h | --help) show_usage_menu ;;
    *)
        log_error "Opção desconhecida: $1"
        show_usage_menu
        ;;
    esac
    shift
done

if [ ${#custom_dirs[@]} -gt 0 ]; then
    directories=("${custom_dirs[@]}")
    log_message "Usando diretórios personalizados especificados via --dir."
fi

if ! [[ "$DAYS_OLD" =~ ^[0-9]+$ ]]; then
    log_error "A idade dos arquivos deve ser um número inteiro positivo: $DAYS_OLD"
fi

if $DRY_RUN; then
    log_message "--- MODO DRY RUN ATIVADO (NENHUM ARQUIVO SERÁ REMOVIDO) ---"
fi

do_cleanup() {
    local dir=$1
    local days=$2

    local initial_size
    local final_size
    local space_saved_bytes=0
    local files_to_remove=()
    local files_count=0

    log_message "Processando diretório: '$dir' (arquivos com mais de $days dias)"

    if [ ! -d "$dir" ]; then
        log_warning "Diretório não encontrado ou não é um diretório: '$dir'. Pulando."
        return 1
    fi

    if [ ! -r "$dir" ] || [ ! -x "$dir" ]; then
        log_warning "Não há permissão de leitura/execução para entrar em '$dir'. Pulando. (Pode precisar de sudo?)"
        return 1
    fi

    initial_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    log_message "Tamanho inicial de '$dir': ${initial_size:-N/A (sem permissão ou vazio?)}"

    if ! mapfile -t -d $'\0' files_to_remove < <(find "$dir" -mindepth 1 -type f -mtime +"$days" -print0 2>/dev/null); then
        log_warning "Erro ao executar 'find' em '$dir' (verifique permissões). Pode não ter encontrado todos os arquivos."
    fi
    files_count=${#files_to_remove[@]}

    if [ "$files_count" -eq 0 ]; then
        log_message "Nenhum arquivo com mais de $days dias encontrado em '$dir'."
        return 0
    fi

    log_message "Encontrados $files_count arquivos com mais de $days dias para remover em '$dir'."

    if $VERBOSE || $DRY_RUN; then
        log_verbose "Arquivos a serem removidos em '$dir':"
        for file in "${files_to_remove[@]}"; do
            printf "  - %s\n" "$file"
        done | less
    fi

    local current_removed_count=0
    local current_space_saved=0
    if ! $DRY_RUN; then
        log_message "Removendo $files_count arquivos de '$dir'..."

        local initial_bytes_batch=0
        if ((files_count > 0)); then
            initial_bytes=$(du -sb "$dir" 2>/dev/null | cut -f1)
        fi

        printf '%s\0' "${files_to_remove[@]}" | xargs -0 rm -f
        local exit_status=$?

        if [ $exit_status -ne 0 ]; then
            log_warning "Ocorreram erros ao remover *alguns* arquivos em '$dir'. Verifique as permissões ou mensagens do sistema."
            current_removed_count=$files_count
        else
            log_message "Remoção dos $files_count arquivos concluída para '$dir'."
            current_removed_count=$files_count
        fi

        final_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        final_bytes=$(du -sb "$dir" 2>/dev/null | cut -f1)

        if [[ "$initial_bytes" =~ ^[0-9]+$ ]] && [[ "$final_bytes" =~ ^[0-9]+$ ]]; then
            space_saved_bytes=$((initial_bytes - final_bytes))

            if ((space_saved_bytes < 0)); then space_saved_bytes=0; fi
            current_space_saved=$space_saved_bytes
        else
            log_warning "Não foi possível calcular o espaço liberado com precisão para '$dir'."
            current_space_saved=0
        fi

        log_message "Tamanho final de '$dir': ${final_size:-N/A}"
        if [ "$current_space_saved" -gt 0 ]; then
            local space_saved_human
            space_saved_human=$(numfmt --to=iec-i --suffix=B --format="%.2f" "$current_space_saved")
            log_message "Espaço liberado em '$dir': $space_saved_human ($current_space_saved bytes)"
        fi
    else
        log_message "[DRY RUN] Nenhum arquivo foi removido de '$dir'."

        current_removed_count=0
        current_space_saved=0
    fi

    TOTAL_FILES_POTENTIAL=$((TOTAL_FILES_POTENTIAL + files_count))
    TOTAL_SPACE_SAVED=$((TOTAL_SPACE_SAVED + current_space_saved))
    TOTAL_FILES_REMOVED=$((TOTAL_FILES_REMOVED + current_removed_count))

    return 0
}

do_clean_journal() {
    if [ "$(id -u)" -ne 0 ]; then
        log_warning "A limpeza do journal requer privilégios de root (sudo)."
        return 1
    fi

    log_message "Limpando logs do systemd journal (ex: mantendo ~200M)..."
    journalctl --vacuum-size=200M
    local exit_status=$?
    if [ $exit_status -ne 0 ]; then
        log_warning "Falha ao limpar o journal."
        return 1
    else
        log_message "Limpeza do journal concluída."
        journalctl --disk-usage
        return 0
    fi
}

TOTAL_FILES_POTENTIAL=0
TOTAL_FILES_REMOVED=0
TOTAL_SPACE_SAVED=0

log_message "Iniciando limpeza de arquivos com mais de $DAYS_OLD dias..."
log_message "Diretórios a serem processados:"
for dir in "${directories[@]}"; do
    log_message "  - '$dir'"
done
echo

if [ ${#directories[@]} -eq 0 ]; then
    log_warning "Nenhum diretório foi especificado para limpeza. Use --dir ou configure diretórios padrão."
    exit 1
fi

for dir in "${directories[@]}"; do
    do_cleanup "$dir" "$DAYS_OLD"

    if $SHOULD_CLEAN_JOURNAL; then
        do_clean_journal
    fi

    echo
done

log_message "--- Resumo da Limpeza ---"
if $DRY_RUN; then
    log_message "Modo DRY RUN. Nenhuma alteração foi feita."
    log_message "Total de arquivos que seriam removidos: $TOTAL_FILES_POTENTIAL"

    log_message "Espaço que seria liberado: (não calculado no dry run)"
else
    log_message "Total de arquivos encontrados para remoção: $TOTAL_FILES_POTENTIAL"
    log_message "Total de arquivos efetivamente removidos: $TOTAL_FILES_REMOVED"
    if [ "$TOTAL_SPACE_SAVED" -gt 0 ]; then
        space_saved_human=$(numfmt --to=iec-i --suffix=B --format="%.2f" "$TOTAL_SPACE_SAVED")
        log_message "Total de espaço liberado: $space_saved_human ($TOTAL_SPACE_SAVED bytes)"
    else
        log_message "Total de espaço liberado: ${TOTAL_SPACE_SAVED} bytes (pode indicar 0 arquivos removidos ou erro no cálculo)"
    fi
fi
log_message "Limpeza concluída."

exit 0
