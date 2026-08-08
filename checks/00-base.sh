#!/bin/bash
# checks/00-base.sh — Camada 1: Diagnóstico Base (todos Hermes-agents)
# Saída: ✅ OK | ❌ FAIL | ⚠️ WARNING
# Exit 0 = tudo OK, 1 = tem FAIL, 2 = só WARNING

set +e

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

ok() { echo "✅ $*"; OK_COUNT=$((OK_COUNT+1)); }
warn() { echo "⚠️  $*"; WARN_COUNT=$((WARN_COUNT+1)); }
fail() { echo "❌ $*"; FAIL_COUNT=$((FAIL_COUNT+1)); }

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_HOME="${HERMES_HOME:-/root/.hermes}"

# Auto-detect (ordem de prioridade: oficial primeiro)
for p in "/c/Users/Dudy/AppData/Local/hermes" "$HOME/.hermes" "/root/.hermes" "/c/Users/Administrator/.hermes" "/home/$(whoami)/.hermes" "/c/Users/Dudy/.hermes"; do
    if [ -d "$p" ]; then HERMES_HOME="$p"; break; fi
done

echo "🔍 BASE — Hermes Home: $HERMES_HOME"
echo "==================================="

# 00-install
if command -v hermes >/dev/null 2>&1; then
    HERMES_VER=$(hermes --version 2>/dev/null | head -1)
    ok "00-install: $HERMES_VER"
else
    fail "00-install: 'hermes' CLI nao encontrado no PATH"
fi

# 01-memory
for f in MEMORY.md USER.md; do
    if [ -f "$HERMES_HOME/$f" ]; then
        SIZE=$(stat -c%s "$HERMES_HOME/$f" 2>/dev/null || stat -f%z "$HERMES_HOME/$f")
        SIZE_KB=$((SIZE / 1024))
        if [ $SIZE_KB -gt 5 ]; then
            ok "01-memory: $f (${SIZE_KB}KB)"
        else
            warn "01-memory: $f muito pequeno (${SIZE_KB}KB)"
        fi
    else
        warn "01-memory: $f nao encontrado"
    fi
done

# state.db
if [ -f "$HERMES_HOME/state.db" ]; then
    DB_SIZE_MB=$(( $(stat -c%s "$HERMES_HOME/state.db" 2>/dev/null || stat -f%z "$HERMES_HOME/state.db") / 1024 / 1024 ))
    if [ $DB_SIZE_MB -gt 80 ]; then
        warn "01-memory: state.db ${DB_SIZE_MB}MB (acima de 80MB, considerar vacuum)"
    else
        ok "01-memory: state.db ${DB_SIZE_MB}MB"
    fi
else
    warn "01-memory: state.db nao encontrado"
fi

# 02-skills
SKILLS_DIR="$HERMES_HOME/skills"
if [ -d "$SKILLS_DIR" ]; then
    SKILL_COUNT=$(find "$SKILLS_DIR" -name "SKILL.md" 2>/dev/null | wc -l)
    ok "02-skills: $SKILL_COUNT skills encontradas"
else
    warn "02-skills: pasta skills/ nao encontrada"
fi

# 03-tools (built-in é responsabilidade do Hermes-agent, nao verificavel aqui)
ok "03-tools: tools built-in (Read/Write/Bash/Grep/Glob) - depende do gateway"

# 04-hooks
HOOKS_DIR="$HERMES_HOME/hooks"
if [ -d "$HOOKS_DIR" ]; then
    HOOK_COUNT=$(find "$HOOKS_DIR" -type f 2>/dev/null | wc -l)
    if [ $HOOK_COUNT -gt 0 ]; then
        ok "04-hooks: $HOOK_COUNT arquivos em hooks/"
    else
        warn "04-hooks: hooks/ vazia"
    fi
else
    warn "04-hooks: pasta hooks/ nao encontrada"
fi

# 05-routines (Task Scheduler Windows OU cron Linux)
ROUTINE_COUNT=0
if command -v schtasks >/dev/null 2>&1; then
    ROUTINE_COUNT=$(schtasks /Query /FO LIST 2>/dev/null | grep -c "TaskName")
elif command -v crontab >/dev/null 2>&1; then
    ROUTINE_COUNT=$(crontab -l 2>/dev/null | grep -cE "^[0-9*]")
fi
if [ $ROUTINE_COUNT -gt 0 ]; then
    ok "05-routines: $ROUTINE_COUNT tarefas agendadas"
else
    warn "05-routines: nenhuma tarefa agendada encontrada"
fi

# 06-security
if [ -f "$HERMES_HOME/.env" ]; then
    PERMS=$(stat -c%a "$HERMES_HOME/.env" 2>/dev/null || stat -f%Lp "$HERMES_HOME/.env")
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "400" ]; then
        ok "06-security: .env com permissoes $PERMS"
    else
        warn "06-security: .env com permissoes $PERMS (deveria ser 600)"
    fi
else
    warn "06-security: .env nao encontrado"
fi

# secrets/ separado
if [ -d "$HERMES_HOME/secrets" ]; then
    ok "06-security: pasta secrets/ existe"
else
    warn "06-security: pasta secrets/ nao existe"
fi

# 07-health
DISK_FREE=$(df -BG "$HERMES_HOME" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')
DISK_FREE_GB=${DISK_FREE:-0}
if [ "$DISK_FREE_GB" -ge 5 ]; then
    ok "07-health: disco ${DISK_FREE_GB}GB livres"
else
    fail "07-health: pouco espaco em disco (${DISK_FREE_GB}GB)"
fi

# Gateway health (porta 18789)
if curl -fsS -m 3 http://localhost:18789/health >/dev/null 2>&1; then
    ok "07-health: gateway :18789 respondendo"
else
    warn "07-health: gateway :18789 nao responde (pode estar down)"
fi

# Telegram config
if grep -q "TELEGRAM_BOT_TOKEN" "$HERMES_HOME/.env" 2>/dev/null; then
    ok "07-health: TELEGRAM_BOT_TOKEN configurado"
else
    warn "07-health: TELEGRAM_BOT_TOKEN nao configurado"
fi

# Resumo
echo "==================================="
echo "BASE RESUMO: $OK_COUNT OK, $WARN_COUNT WARN, $FAIL_COUNT FAIL"
echo "==================================="

if [ $FAIL_COUNT -gt 0 ]; then exit 1; fi
if [ $WARN_COUNT -gt 0 ]; then exit 2; fi
exit 0