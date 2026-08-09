#!/bin/bash
# backup-vitals.sh — Backup dos databases + memoria do agente
# CLAUDE AUDIT round 2: "vacuum != backup. state.db/brain_v2 sem copia = perda total"
# Uso: bash backup-vitals.sh [--keep 7]
# Default: mantem 7 dias de backup

set -euo pipefail

# CLAUDE AUDIT round 3: parse --keep N ou numero direto, default 7
KEEP_DAYS=7
for arg in "$@"; do
    case "$arg" in
        --keep) shift_next=1 ;;
        *)
            if [ "${shift_next:-0}" = "1" ]; then
                KEEP_DAYS="$arg"; shift_next=0
            elif [[ "$arg" =~ ^[0-9]+$ ]]; then
                KEEP_DAYS="$arg"
            fi
            ;;
    esac
done
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Detecta HERMES_HOME
if [ -n "$HERMES_HOME" ] && [ -d "$HERMES_HOME" ]; then
    HOME_DIR="$HERMES_HOME"
elif [ -d "$HOME/AppData/Local/hermes" ]; then
    HOME_DIR="$HOME/AppData/Local/hermes"
elif [ -d "$HOME/.hermes" ]; then
    HOME_DIR="$HOME/.hermes"
else
    echo "CRIT: HERMES_HOME nao encontrado"
    exit 2
fi

BACKUP_DIR="$HOME_DIR/backups"
mkdir -p "$BACKUP_DIR"

OK=0
FAIL=0

log_ok()   { echo "[OK] $1"; OK=$((OK + 1)); }
log_fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

# 1. Backup state.db (SQLite backup online — nao precisa parar o agente)
STATE_DB="$HOME_DIR/state.db"
if [ -f "$STATE_DB" ]; then
    BACKUP="$BACKUP_DIR/state_db_${TIMESTAMP}.db"
    # Usar .backup do SQLite (safe copy, nao corrompe se em uso)
    if python -c "
import sqlite3
src = sqlite3.connect(r'$STATE_DB')
dst = sqlite3.connect(r'$BACKUP')
src.backup(dst)
dst.close()
src.close()
" 2>/dev/null; then
        SIZE=$(stat -c%s "$BACKUP" 2>/dev/null || stat -f%z "$BACKUP" 2>/dev/null)
        SIZE_MB=$((SIZE / 1048576))
        log_ok "state.db -> backups/state_db_${TIMESTAMP}.db (${SIZE_MB}MB)"
    else
        log_fail "state.db backup falhou (locked?)"
    fi
else
    log_fail "state.db nao existe"
fi

# 2. Backup brain_v2.db
BRAIN="$HOME_DIR/workspace/brain_v2.db"
if [ -f "$BRAIN" ]; then
    BACKUP="$BACKUP_DIR/brain_v2_${TIMESTAMP}.db"
    if python -c "
import sqlite3, shutil
# brain_v2 e pequeno, copia direta e segura
shutil.copy2(r'$BRAIN', r'$BACKUP')
# valida
c = sqlite3.connect(r'$BACKUP')
c.execute('SELECT 1')
c.close()
" 2>/dev/null; then
        log_ok "brain_v2.db -> backups/brain_v2_${TIMESTAMP}.db"
    else
        log_fail "brain_v2.db backup falhou"
    fi
fi

# 3. Backup MEMORY.md + USER.md + SOUL.md
for f in MEMORY.md USER.md SOUL.md AGENTS.md; do
    SRC="$HOME_DIR/$f"
    if [ -f "$SRC" ]; then
        cp "$SRC" "$BACKUP_DIR/${f%.md}_${TIMESTAMP}.md" 2>/dev/null
        log_ok "$f -> backups/${f%.md}_${TIMESTAMP}.md"
    fi
done

# 4. Cleanup: remover backups mais antigos que KEEP_DAYS (CLAUDE AUDIT round 3: glob corretor)
if [ "$KEEP_DAYS" -gt 0 ] 2>/dev/null; then
    DELETED=$(find "$BACKUP_DIR" -name "*.db" -mtime +$KEEP_DAYS -delete -print 2>/dev/null | wc -l)
    DELETED_MD=$(find "$BACKUP_DIR" -name "*.md" -mtime +$KEEP_DAYS -delete -print 2>/dev/null | wc -l)
    TOTAL_DELETED=$((DELETED + DELETED_MD))
    if [ "$TOTAL_DELETED" -gt 0 ]; then
        echo "[CLEAN] $TOTAL_DELETED backups antigos removidos (>${KEEP_DAYS}d)"
    fi
fi

# 5. Contar backups restantes
TOTAL=$(find "$BACKUP_DIR" -name "*.db" -o -name "*.md" 2>/dev/null | wc -l)
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')

# RESUMO
echo ""
echo "=============================================="
echo "  BACKUP VITALS — $TIMESTAMP"
echo "  OK: $OK  FAIL: $FAIL"
echo "  Total backups: $TOTAL ($BACKUP_SIZE)"
echo "  Retencao: $KEEP_DAYS dias"
echo "=============================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
else
    exit 0
fi