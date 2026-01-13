#!/bin/bash

set -euo pipefail  # Строгий режим: выход при ошибках, неопределённых переменных

# ============================================================================
# КОНФИГУРАЦИЯ
# ============================================================================

readonly BASE_DIR="/var/www"
readonly IMAGES_DIR="wp-content/uploads"
readonly MAX_TIME="4h"
readonly LOG_FILE="/var/log/imgoptimize_batch.log"
readonly LOCK_FILE="/var/run/imgoptimize.lock"
readonly TEMP_SCRIPT="/tmp/imgoptimize_temp_$$.sh"

# Цвета для вывода (если терминал поддерживает)
if [[ -t 1 ]]; then
    readonly COLOR_RESET="\033[0m"
    readonly COLOR_GREEN="\033[0;32m"
    readonly COLOR_YELLOW="\033[0;33m"
    readonly COLOR_RED="\033[0;31m"
    readonly COLOR_BLUE="\033[0;34m"
else
    readonly COLOR_RESET=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_RED=""
    readonly COLOR_BLUE=""
fi

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $*"
    log "INFO" "$*"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2
    log "WARN" "$*"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
    log "ERROR" "$*"
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${COLOR_BLUE}[DEBUG]${COLOR_RESET} $*"
        log "DEBUG" "$*"
    fi
}

# ============================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ БЛОКИРОВКОЙ
# ============================================================================

acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_error "Скрипт уже запущен (PID: $pid)"
            exit 1
        else
            log_warn "Обнаружен устаревший lock-файл, удаляем"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    log_debug "Lock-файл создан: $LOCK_FILE (PID: $$)"
}

release_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log_debug "Lock-файл удалён"
    fi
}

# ============================================================================
# ФУНКЦИИ ОЧИСТКИ
# ============================================================================

cleanup() {
    local exit_code=$?
    
    log_debug "Выполнение очистки (exit code: $exit_code)"
    
    # Удаление временного скрипта
    if [[ -f "$TEMP_SCRIPT" ]]; then
        rm -f "$TEMP_SCRIPT"
        log_debug "Временный скрипт удалён"
    fi
    
    # Снятие блокировки
    release_lock
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "Скрипт завершён успешно"
    else
        log_error "Скрипт завершён с ошибкой (код: $exit_code)"
    fi
    
    exit $exit_code
}

# Установка ловушек для очистки
trap cleanup EXIT
trap 'log_error "Получен сигнал прерывания"; exit 130' INT TERM

# ============================================================================
# ВАЛИДАЦИЯ
# ============================================================================

validate_environment() {
    log_info "Проверка окружения..."
    
    # Проверка базовой директории
    if [[ ! -d "$BASE_DIR" ]]; then
        log_error "Базовая директория не существует: $BASE_DIR"
        exit 1
    fi
    
    if [[ ! -r "$BASE_DIR" ]]; then
        log_error "Нет прав на чтение директории: $BASE_DIR"
        exit 1
    fi
    
    # Проверка команды imgoptimize
    if ! command -v imgoptimize &>/dev/null; then
        log_error "Команда 'imgoptimize' не найдена"
        exit 1
    fi
    
    # Проверка команды timeout
    if ! command -v timeout &>/dev/null; then
        log_error "Команда 'timeout' не найдена"
        exit 1
    fi
    
    # Проверка прав на запись в лог
    if [[ ! -w "$(dirname "$LOG_FILE")" ]]; then
        log_error "Нет прав на запись в директорию логов: $(dirname "$LOG_FILE")"
        exit 1
    fi
    
    log_info "Окружение проверено успешно"
}

# ============================================================================
# ПОДСЧЁТ СТАТИСТИКИ
# ============================================================================

count_sites() {
    local count=0
    
    for site_dir in "$BASE_DIR"/*; do
        if [[ -d "$site_dir/$IMAGES_DIR" ]]; then
            ((count++))
        fi
    done
    
    echo "$count"
}

# ============================================================================
# СОЗДАНИЕ ВРЕМЕННОГО СКРИПТА
# ============================================================================

create_temp_script() {
    log_info "Создание временного скрипта: $TEMP_SCRIPT"
    
    cat > "$TEMP_SCRIPT" <<'SCRIPT_EOF'
#!/bin/bash

set -euo pipefail

BASE_DIR="$1"
IMAGES_DIR="$2"

processed=0
skipped=0
failed=0

for site_dir in "$BASE_DIR"/*; do
    if [[ ! -d "$site_dir" ]]; then
        continue
    fi
    
    site_name=$(basename "$site_dir")
    uploads_dir="$site_dir/$IMAGES_DIR"
    
    if [[ -d "$uploads_dir" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Обработка сайта: $site_name"
        echo "  Директория: $uploads_dir"
        
        # Подсчёт директорий для обработки
        dir_count=$(find "$uploads_dir" -type d | wc -l)
        echo "  Найдено директорий: $dir_count"
        
        # Выполняем оптимизацию в каждой поддиректории
        find "$uploads_dir" -type d \( ! -name . \) -print0 2>/dev/null | \
        while IFS= read -r -d '' dir; do
            if cd "$dir" 2>/dev/null; then
                if imgoptimize 2>&1 | tee -a /var/log/imgoptimize_batch.log; then
                    ((processed++)) || true
                else
                    echo "  [ОШИБКА] Не удалось оптимизировать: $dir"
                    ((failed++)) || true
                fi
            else
                echo "  [ПРЕДУПРЕЖДЕНИЕ] Не удалось перейти в директорию: $dir"
                ((skipped++)) || true
            fi
        done
        
        echo "  ✓ Сайт $site_name обработан"
        echo ""
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Пропуск сайта $site_name (директория uploads не найдена)"
        ((skipped++)) || true
    fi
done

echo "========================================="
echo "Итоговая статистика:"
echo "  Обработано: $processed"
echo "  Пропущено: $skipped"
echo "  Ошибок: $failed"
echo "========================================="
SCRIPT_EOF

    chmod +x "$TEMP_SCRIPT"
    log_debug "Временный скрипт создан и готов к выполнению"
}

# ============================================================================
# ОСНОВНАЯ ФУНКЦИЯ
# ============================================================================

main() {
    log_info "========================================="
    log_info "Запуск массовой оптимизации изображений"
    log_info "========================================="
    log_info "Базовая директория: $BASE_DIR"
    log_info "Путь к изображениям: $IMAGES_DIR"
    log_info "Максимальное время выполнения: $MAX_TIME"
    log_info "Лог-файл: $LOG_FILE"
    
    # Блокировка от повторного запуска
    acquire_lock
    
    # Валидация окружения
    validate_environment
    
    # Подсчёт сайтов
    local sites_count
    sites_count=$(count_sites)
    log_info "Найдено сайтов с директорией uploads: $sites_count"
    
    if [[ "$sites_count" -eq 0 ]]; then
        log_warn "Сайты для обработки не найдены"
        exit 0
    fi
    
    # Создание временного скрипта
    create_temp_script
    
    # Запуск с ограничением по времени
    log_info "Запуск оптимизации (timeout: $MAX_TIME)..."
    
    local start_time
    start_time=$(date +%s)
    
    if timeout "$MAX_TIME" bash "$TEMP_SCRIPT" "$BASE_DIR" "$IMAGES_DIR"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_info "Оптимизация завершена успешно"
        log_info "Время выполнения: $((duration / 60)) минут $((duration % 60)) секунд"
    else
        local exit_code=$?
        
        if [[ $exit_code -eq 124 ]]; then
            log_warn "Оптимизация прервана по таймауту ($MAX_TIME)"
        else
            log_error "Оптимизация завершилась с ошибкой (код: $exit_code)"
            exit $exit_code
        fi
    fi
}

# ============================================================================
# ТОЧКА ВХОДА
# ============================================================================

main "$@"
