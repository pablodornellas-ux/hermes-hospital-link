#!/bin/bash
# watchdog.sh — Liveness probe do agente Hermes
# CLAUDE AUDIT round 2: "nada garante o agente vivo"
# Verifica: gateway respondendo, mem0 alive, state.db acessivel, disk space
# Uso: bash watchdog.sh [--alert]
# Sair: 0=OK, 1=WARN, 2=CRIT

set -euo pipefail

# Detecta HERMES_HOME (CLAUDE AUDIT round 3: ${VAR:-} nao quebra com set -u)
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

WARN_COUNT=0
CRIT_COUNT=0

log_ok()   { echo "[OK] $1"; }
log_warn() { echo "[WARN] $1"; WARN_COUNT=$((WARN_COUNT + 1)); }
log_crit() { echo "[CRIT] $1"; CRIT_COUNT=$((CRIT_COUNT + 1)); }

# 1. Gateway respondendo (localhost:18789)
if curl -s -m 5 http://localhost:18789/health 2>/dev/null | grep -q "ok\|healthy"; then
    log_ok "gateway :18789 respondendo"
else
    log_warn "gateway :18789 nao responde (pode ser intencional)"
fi

# 2. mem0-server alive (localhost:8765)
if curl -s -m 3 http://localhost:8765/health 2>/dev/null | grep -q '"status".*"ok"'; then
    log_ok "mem0-server :8765 alive"
else
    log_warn "mem0-server :8765 offline"
fi

# 3. state.db acessivel
STATE_DB="$HOME_DIR/state.db"
if [ -f "$STATE_DB" ]; then
    SIZE=$(stat -c%s "$STATE_DB" 2>/dev/null || stat -f%z "$STATE_DB" 2>/dev/null)
    SIZE_MB=$((SIZE / 1048576))
    # Testar leitura
    if python -c "import sqlite3; c=sqlite3.connect('$STATE_DB'); c.execute('SELECT 1'); c.close()" 2>/dev/null; then
        log_ok "state.db acessivel (${SIZE_MB}MB)"
    else
        log_crit "state.db corrompido ou locked"
    fi
    # Aviso se >500MB
    if [ "$SIZE_MB" -gt 500 ]; then
        log_warn "state.db ${SIZE_MB}MB (considerar VACUUM)"
    fi
else
    log_crit "state.db nao existe"
fi

# 4. MEMORY.md nao saturada
MEM_FILE="$HOME_DIR/MEMORY.md"
if [ -f "$MEM_FILE" ]; then
    MEM_SIZE=$(stat -c%s "$MEM_FILE" 2>/dev/null || stat -f%z "$MEM_FILE" 2>/dev/null)
    if [ "$MEM_SIZE" -gt 2000 ]; then
        MEM_PCT=$((MEM_SIZE * 100 / 2200))
        log_warn "MEMORY.md ${MEM_PCT}% cheio (${MEM_SIZE}/2200B)"
    else
        log_ok "MEMORY.md OK (${MEM_SIZE}B)"
    fi
else
    log_crit "MEMORY.md nao existe"
fi

# 5. Disk space (C: ou /home)
if [ -d "/c" ]; then
    AVAIL=$(df -m /c 2>/dev/null | awk 'NR==2{print $4}')
else
    AVAIL=$(df -m / 2>/dev/null | awk 'NR==2{print $4}')
fi
if [ -n "$AVAIL" ] && [ "$AVAIL" -lt 8000 ]; then
    log_crit "disk livre ${AVAIL}MB (<8GB gate do Claude Code)"
elif [ -n "$AVAIL" ]; then
    log_ok "disk livre ${AVAIL}MB"
fi

# 6. brain_v2.db (se existir)
BRAIN="$HOME_DIR/workspace/brain_v2.db"
if [ -f "$BRAIN" ]; then
    log_ok "brain_v2.db existe"
else
    log_warn "brain_v2.db nao encontrado (recomendado)"
fi

# 7. Hooks ativos
HOOKS_DIR="$HOME_DIR/hooks"
if [ -d "$HOOKS_DIR" ]; then
    HOOK_COUNT=$(find "$HOOKS_DIR" -name handler.py 2>/dev/null | wc -l)
    if [ "$HOOK_COUNT" -ge 3 ]; then
        log_ok "hooks: $HOOK_COUNT ativos"
    else
        log_warn "hooks: $HOOK_COUNT (recomendado >= 3)"
    fi
fi

# 8. Cron jobs
CRON_FILE="$HOME_DIR/cron/jobs.json"
if [ -f "$CRON_FILE" ]; then
    CRON_COUNT=$(python -c "import json; d=json.load(open('$CRON_FILE')); print(len(d))" 2>/dev/null || echo 0)
    if [ "$CRON_COUNT" -gt 0 ]; then
        log_ok "cron: $CRON_COUNT jobs"
    else
        log_warn "cron: 0 jobs"
    fi
fi

# RESUMO (CLAUDE AUDIT round 3: score clamp >= 0)
TOTAL_CHECKS=8
SCORE=$(( TOTAL_CHECKS - CRIT_COUNT - WARN_COUNT / 2 ))
[ "$SCORE" -lt 0 ] && SCORE=0
echo ""
echo "=============================================="
echo "  WATCHDOG SCORE: $SCORE/$TOTAL_CHECKS"
echo "  CRIT: $CRIT_COUNT  WARN: $WARN_COUNT  OK: $(( TOTAL_CHECKS - CRIT_COUNT - WARN_COUNT ))"
echo "=============================================="

if [ "$CRIT_COUNT" -gt 0 ]; then
    exit 2
elif [ "$WARN_COUNT" -gt 2 ]; then
    exit 1
else
    exit 0
fi