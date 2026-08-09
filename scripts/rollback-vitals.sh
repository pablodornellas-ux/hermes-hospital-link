#!/bin/bash
# rollback-vitals.sh — Inverso do backup-vitals.sh: restaura os vitais de um backup.
# Restaura: state.db, brain_v2.db, MEMORY.md, USER.md, SOUL.md, AGENTS.md
# SEGURANCA: NUNCA restaura sem antes fazer um backup de seguranca do state atual.
#
# Uso:
#   bash rollback-vitals.sh                 # lista + pergunta qual restaurar
#   bash rollback-vitals.sh --latest        # restaura o backup mais recente
#   bash rollback-vitals.sh --ts <TS>       # restaura o timestamp exato (YYYYMMDD_HHMMSS)
#   bash rollback-vitals.sh --dry-run       # mostra o que restauraria, sem tocar em nada
#   bash rollback-vitals.sh --force         # pula a confirmacao interativa
# Flags combinam: --latest --force / --latest --dry-run etc.
#
# Sair: 0=OK, 1=falha na restauracao/validacao, 2=ambiente invalido/sem backup.

set -euo pipefail

# ---- Flags -------------------------------------------------------------------
LATEST=0
DRY_RUN=0
FORCE=0
CHOSEN_TS=""
for ((i = 1; i <= $#; i++)); do
    arg="${!i}"
    case "$arg" in
        --latest)  LATEST=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --force)   FORCE=1 ;;
        --ts)      j=$((i + 1)); CHOSEN_TS="${!j:-}" ;;
        --ts=*)    CHOSEN_TS="${arg#--ts=}" ;;
    esac
done

# ---- Detecta HERMES_HOME (mesma logica de backup-vitals.sh / watchdog.sh) ----
if [ -n "${HERMES_HOME:-}" ] && [ -d "${HERMES_HOME:-}" ]; then
    HOME_DIR="${HERMES_HOME:-}"
elif [ -d "$HOME/AppData/Local/hermes" ]; then
    HOME_DIR="$HOME/AppData/Local/hermes"
elif [ -d "$HOME/.hermes" ]; then
    HOME_DIR="$HOME/.hermes"
else
    echo "CRIT: HERMES_HOME nao encontrado"
    exit 2
fi

BACKUP_DIR="$HOME_DIR/backups"
WORKSPACE_DIR="$HOME_DIR/workspace"
SCRIPT_DIR="$WORKSPACE_DIR/scripts"
LOG_DIR="$WORKSPACE_DIR/logs"
mkdir -p "$LOG_DIR"

RUN_TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/rollback-${RUN_TS}.log"

# Loga em tela E em arquivo (dry-run tambem, pra deixar evidencia).
log() { echo "$1" | tee -a "$LOG_FILE" ; }

log "=============================================="
log "  ROLLBACK VITALS — $RUN_TS"
[ "$DRY_RUN" = "1" ] && log "  MODO: DRY-RUN (nenhuma alteracao sera feita)"
log "  HERMES_HOME: $HOME_DIR"
log "=============================================="

if [ ! -d "$BACKUP_DIR" ]; then
    log "CRIT: diretorio de backups nao existe: $BACKUP_DIR"
    exit 2
fi

# ---- 1. Descobrir backups disponiveis (por timestamp) ------------------------
# Um "set" e identificado pelo TS canonico YYYYMMDD_HHMMSS presente nos nomes
# state_db_<TS>.db / brain_v2_<TS>.db / MEMORY_<TS>.md / USER_/SOUL_/AGENTS_<TS>.md
TIMESTAMPS=$(ls -1 "$BACKUP_DIR" 2>/dev/null \
    | grep -E '^(state_db|brain_v2|MEMORY|USER|SOUL|AGENTS)_[0-9]{8}_[0-9]{6}\.(db|md)$' \
    | grep -oE '[0-9]{8}_[0-9]{6}' \
    | sort -ur || true)

if [ -z "$TIMESTAMPS" ]; then
    log "CRIT: nenhum backup encontrado em $BACKUP_DIR"
    exit 2
fi

# Componentes de um TS: imprime "arquivo(size)" para os que existem.
set_components() {
    local ts="$1" out=""
    for pair in "state_db_${ts}.db:state.db" \
                "brain_v2_${ts}.db:brain_v2.db" \
                "MEMORY_${ts}.md:MEMORY.md" \
                "USER_${ts}.md:USER.md" \
                "SOUL_${ts}.md:SOUL.md" \
                "AGENTS_${ts}.md:AGENTS.md"; do
        local src="${pair%%:*}" name="${pair##*:}"
        if [ -f "$BACKUP_DIR/$src" ]; then
            local sz
            sz=$(stat -c%s "$BACKUP_DIR/$src" 2>/dev/null || stat -f%z "$BACKUP_DIR/$src" 2>/dev/null || echo 0)
            out="$out $name(${sz}B)"
        fi
    done
    echo "$out"
}

# Converte TS YYYYMMDD_HHMMSS -> data legivel.
human_ts() {
    local ts="$1"
    echo "${ts:0:4}-${ts:4:2}-${ts:6:2} ${ts:9:2}:${ts:11:2}:${ts:13:2}"
}

log ""
log "Backups disponiveis (mais recente primeiro):"
idx=0
declare -a TS_LIST=()
while IFS= read -r ts; do
    [ -z "$ts" ] && continue
    idx=$((idx + 1))
    TS_LIST+=("$ts")
    log "  [$idx] $ts  ($(human_ts "$ts")) ->$(set_components "$ts")"
done <<< "$TIMESTAMPS"

# ---- 2. Escolher qual restaurar ---------------------------------------------
RESTORE_TS=""
if [ -n "$CHOSEN_TS" ]; then
    for ts in "${TS_LIST[@]}"; do
        [ "$ts" = "$CHOSEN_TS" ] && RESTORE_TS="$ts"
    done
    if [ -z "$RESTORE_TS" ]; then
        log "CRIT: timestamp '$CHOSEN_TS' nao encontrado entre os backups"
        exit 2
    fi
elif [ "$LATEST" = "1" ]; then
    RESTORE_TS="${TS_LIST[0]}"
    log ""
    log "--latest -> selecionado: $RESTORE_TS"
else
    # Interativo. Sem TTY e sem --latest = nao da pra escolher com seguranca.
    if [ ! -t 0 ] && [ ! -r /dev/tty ]; then
        log ""
        log "CRIT: sem TTY para escolha interativa. Use --latest ou --ts <TS>."
        exit 2
    fi
    echo ""
    read -r -p "Qual backup restaurar? [1-$idx] (Enter=1, q=cancelar): " choice < /dev/tty
    choice="${choice:-1}"
    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        log "Cancelado pelo usuario."
        exit 0
    fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$idx" ]; then
        log "CRIT: escolha invalida: $choice"
        exit 2
    fi
    RESTORE_TS="${TS_LIST[$((choice - 1))]}"
fi

log ""
log "Alvo da restauracao: $RESTORE_TS ($(human_ts "$RESTORE_TS"))"
log "Componentes:$(set_components "$RESTORE_TS")"

# Mapeamento origem(backup) -> destino(vivo)
declare -a MAP=(
    "state_db_${RESTORE_TS}.db:$HOME_DIR/state.db"
    "brain_v2_${RESTORE_TS}.db:$WORKSPACE_DIR/brain_v2.db"
    "MEMORY_${RESTORE_TS}.md:$HOME_DIR/MEMORY.md"
    "USER_${RESTORE_TS}.md:$HOME_DIR/USER.md"
    "SOUL_${RESTORE_TS}.md:$HOME_DIR/SOUL.md"
    "AGENTS_${RESTORE_TS}.md:$HOME_DIR/AGENTS.md"
)

# ---- 3. DRY-RUN: mostra o plano e sai ---------------------------------------
if [ "$DRY_RUN" = "1" ]; then
    log ""
    log "--- PLANO DE RESTAURACAO (dry-run) ---"
    log "  1) backup de seguranca do state atual (backup-vitals.sh)"
    for pair in "${MAP[@]}"; do
        src="${pair%%:*}"; dst="${pair##*:}"
        if [ -f "$BACKUP_DIR/$src" ]; then
            log "  2) $src  ->  $dst"
        else
            log "     (pula: $src nao existe neste backup)"
        fi
    done
    log "  3) validar: hermes --version + watchdog.sh"
    log ""
    log "Nenhuma alteracao feita. Log: $LOG_FILE"
    exit 0
fi

# ---- 4. Confirmacao ----------------------------------------------------------
if [ "$FORCE" != "1" ]; then
    if [ ! -t 0 ] && [ ! -r /dev/tty ]; then
        log "CRIT: restauracao real sem TTY exige --force. Abortado."
        exit 2
    fi
    echo ""
    echo "!! Isto vai SOBRESCREVER os vitais vivos com o backup $RESTORE_TS."
    read -r -p "Confirmar restauracao? (digite 'sim'): " confirm < /dev/tty
    if [ "$confirm" != "sim" ]; then
        log "Cancelado: confirmacao negada."
        exit 0
    fi
fi

# ---- 5. SAFETY NET: backup do state atual antes de qualquer escrita ----------
log ""
log "--- SAFETY NET: backup do state atual antes de restaurar ---"
if [ -f "$SCRIPT_DIR/backup-vitals.sh" ]; then
    if bash "$SCRIPT_DIR/backup-vitals.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log "[OK] safety backup concluido"
    else
        log "CRIT: safety backup FALHOU — abortando restauracao (nao restaura sem rede de seguranca)"
        exit 1
    fi
else
    log "CRIT: backup-vitals.sh nao encontrado em $SCRIPT_DIR — abortando (sem rede de seguranca)"
    exit 1
fi

# ---- 6. Restaurar ------------------------------------------------------------
log ""
log "--- RESTAURANDO $RESTORE_TS ---"
OK=0
FAIL=0
SKIP=0
for pair in "${MAP[@]}"; do
    src="${pair%%:*}"; dst="${pair##*:}"
    SRC_PATH="$BACKUP_DIR/$src"
    if [ ! -f "$SRC_PATH" ]; then
        log "[SKIP] $src nao existe neste backup"
        SKIP=$((SKIP + 1))
        continue
    fi
    # Valida integridade do .db de origem antes de sobrescrever o vivo.
    if [[ "$src" == *.db ]]; then
        if ! python -c "
import sqlite3, sys
try:
    c = sqlite3.connect(r'$SRC_PATH')
    r = c.execute('PRAGMA integrity_check').fetchone()
    c.close()
    sys.exit(0 if r and r[0] == 'ok' else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
            log "[FAIL] $src corrompido (integrity_check != ok) — NAO restaurado"
            FAIL=$((FAIL + 1))
            continue
        fi
    fi
    mkdir -p "$(dirname "$dst")"
    if cp "$SRC_PATH" "$dst" 2>/dev/null; then
        log "[OK] $src -> $dst"
        OK=$((OK + 1))
    else
        log "[FAIL] cp $src -> $dst"
        FAIL=$((FAIL + 1))
    fi
done

# ---- 7. Validacao ------------------------------------------------------------
log ""
log "--- VALIDACAO ---"
VALID_FAIL=0

# hermes --version
HERMES_BIN="$(command -v hermes 2>/dev/null || true)"
if [ -z "$HERMES_BIN" ] && [ -x "$HOME_DIR/hermes-agent/venv/Scripts/hermes" ]; then
    HERMES_BIN="$HOME_DIR/hermes-agent/venv/Scripts/hermes"
fi
if [ -n "$HERMES_BIN" ]; then
    if VER=$("$HERMES_BIN" --version 2>&1); then
        log "[OK] hermes --version: $VER"
    else
        log "[WARN] hermes --version retornou erro: $VER"
        VALID_FAIL=$((VALID_FAIL + 1))
    fi
else
    log "[WARN] binario hermes nao encontrado — pulei --version"
fi

# watchdog.sh
if [ -f "$SCRIPT_DIR/watchdog.sh" ]; then
    log "watchdog.sh:"
    if bash "$SCRIPT_DIR/watchdog.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log "[OK] watchdog.sh exit 0"
    else
        wd_rc=$?
        log "[WARN] watchdog.sh exit $wd_rc (WARN/CRIT — investigar apos rollback)"
        VALID_FAIL=$((VALID_FAIL + 1))
    fi
else
    log "[WARN] watchdog.sh nao encontrado em $SCRIPT_DIR"
fi

# ---- 8. Resumo ---------------------------------------------------------------
log ""
log "=============================================="
log "  ROLLBACK VITALS — $RUN_TS"
log "  Restaurado de: $RESTORE_TS ($(human_ts "$RESTORE_TS"))"
log "  OK: $OK  FAIL: $FAIL  SKIP: $SKIP  VALID_WARN: $VALID_FAIL"
log "  Log: $LOG_FILE"
log "=============================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
