#!/bin/bash
# factory-cron.sh — Cron unificado da fabrica (sequencial, nao paralelo)
# CLAUDE AUDIT E-017: writes paralelos quebram gate. Sequencial.
# Roda no Abraao. Itera nos: watchdog → backup → finops.

set -euo pipefail

HR="${HERMES_HOME:-$HOME/AppData/Local/hermes}"
[ ! -d "$HR" ] && HR="$HOME/.hermes"
SCRIPTS="$HR/workspace/scripts"
LOG="$HR/workspace/logs/factory-cron.log"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

mkdir -p "$(dirname "$LOG")"

log() { echo "[$TIMESTAMP] $1" | tee -a "$LOG"; }

log "=== FACTORY CRON START ==="

# --- NO 1: ABRAAO (local) ---
log "--- ABRAAO ---"
log "watchdog..."
bash "$SCRIPTS/watchdog.sh" 2>&1 | tail -3 >> "$LOG"
log "backup..."
bash "$SCRIPTS/backup-vitals.sh" >> "$LOG" 2>&1
log "finops..."
python "$SCRIPTS/finops-aggregator.py" --days 1 2>&1 | tail -5 >> "$LOG"

# --- NO 2: AUGUSTUS (WSL Docker) ---
log "--- AUGUSTUS ---"
# Verificar se container ta UP
AUG_STATUS=$(powershell.exe -c "wsl -d Ubuntu -- bash -lc 'docker inspect --format={{.State.Status}} augustus-hermes-standalone 2>/dev/null'" 2>&1 | tr -d '\r\n')
if [ "$AUG_STATUS" = "running" ]; then
    log "container UP. watchdog..."
    # Rodar watchdog via base64 pipe (CRLF-safe)
    if [ -f "$SCRIPTS/watchdog.sh" ]; then
        B64=$(base64 -w0 "$SCRIPTS/watchdog.sh" 2>/dev/null || base64 "$SCRIPTS/watchdog.sh")
        echo "$B64" | base64 -d | powershell.exe -c "wsl -d Ubuntu -- bash -lc 'docker exec -i augustus-hermes-standalone bash'" 2>&1 | tail -3 >> "$LOG"
    fi
    log "finops..."
    if [ -f "$SCRIPTS/finops-aggregator.py" ]; then
        B64=$(base64 -w0 "$SCRIPTS/finops-aggregator.py" 2>/dev/null || base64 "$SCRIPTS/finops-aggregator.py")
        echo "$B64" | base64 -d | powershell.exe -c "wsl -d Ubuntu -- bash -lc 'docker exec -i augustus-hermes-standalone python3 -'" -- --days 1 2>&1 | tail -5 >> "$LOG"
    fi
else
    log "WARN: Augustus container $AUG_STATUS — pulando"
fi

# --- NO 3: NEEMIAS (SSH) ---
log "--- NEEMIAS ---"
SSH_KEY="$HOME/.ssh/id_ed25519_sec"
if [ -f "$SSH_KEY" ]; then
    NEEMIAS_OK=$(ssh -o ConnectTimeout=5 -o IdentitiesOnly=yes -i "$SSH_KEY" beta@100.103.213.58 'echo OK' 2>/dev/null || echo "OFFLINE")
    if [ "$NEEMIAS_OK" = "OK" ]; then
        log "SSH OK. Diagnostico rapido..."
        ssh -o IdentitiesOnly=yes -i "$SSH_KEY" beta@100.103.213.58 'ls ~/.hermes/SOUL.md 2>&1' >> "$LOG" 2>&1
    else
        log "WARN: Neemias OFFLINE"
    fi
else
    log "WARN: SSH key nao existe"
fi

# --- NO 4: OMNIQI ---
log "--- OMNIQI ---"
log "assincrono (repo) — sem acesso direto"

# --- RESUMO ---
log "=== FACTORY CRON DONE ==="
log "Log: $LOG"