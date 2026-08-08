#!/bin/bash
# checks/20-auto-fix.sh — Auto-fix (correções conhecidas)

set +e
OK_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0
ok() { echo "✅ $*"; OK_COUNT=$((OK_COUNT+1)); }
warn() { echo "⚠️  $*"; WARN_COUNT=$((WARN_COUNT+1)); }
fail() { echo "❌ $*"; FAIL_COUNT=$((FAIL_COUNT+1)); }

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
for p in "$HOME/.hermes" "/root/.hermes" "/c/Users/Dudy/.hermes" "/c/Users/Dudy/AppData/Local/hermes"; do
    if [ -d "$p" ]; then HERMES_HOME="$p"; break; fi
done

echo "🔧 AUTO-FIX"
echo "==================================="

# 1. state.db VACUUM
if [ -f "$HERMES_HOME/state.db" ]; then
    if command -v sqlite3 >/dev/null 2>&1; then
        SIZE_BEFORE=$(stat -c%s "$HERMES_HOME/state.db" 2>/dev/null || stat -f%z "$HERMES_HOME/state.db")
        sqlite3 "$HERMES_HOME/state.db" "VACUUM;" 2>/dev/null && {
            SIZE_AFTER=$(stat -c%s "$HERMES_HOME/state.db" 2>/dev/null || stat -f%z "$HERMES_HOME/state.db")
            DELTA=$((SIZE_BEFORE - SIZE_AFTER))
            ok "vacuum: state.db reduzido em ${DELTA} bytes"
        }
    else
        warn "vacuum: sqlite3 nao disponivel"
    fi
else
    warn "vacuum: state.db nao encontrado"
fi

# 2. MEMORY.md compact (so se > 90% cheio)
if [ -f "$HERMES_HOME/MEMORY.md" ]; then
    SIZE=$(stat -c%s "$HERMES_HOME/MEMORY.md" 2>/dev/null || stat -f%z "$HERMES_HOME/MEMORY.md")
    if [ $SIZE -gt 1800 ]; then
        # Backup
        cp "$HERMES_HOME/MEMORY.md" "$HERMES_HOME/MEMORY.md.bak.$(date +%Y%m%d)" 2>/dev/null
        ok "compact: MEMORY.md backup criado"
        warn "compact: MEMORY.md acima de 1800 chars — revisar manualmente"
    else
        ok "compact: MEMORY.md abaixo do limite (${SIZE} bytes)"
    fi
fi

# 3. .env permissoes
if [ -f "$HERMES_HOME/.env" ]; then
    if command -v chmod >/dev/null 2>&1; then
        chmod 600 "$HERMES_HOME/.env" 2>/dev/null && ok "perms: .env -> 600"
    fi
fi

# 4. Auto-update skill
if [ -f "$HERMES_HOME/workspace/scripts/auto-update.py" ]; then
    ok "update: auto-update.py existe"
else
    warn "update: auto-update.py nao encontrado"
fi

echo "==================================="
echo "AUTO-FIX RESUMO: $OK_COUNT OK, $WARN_COUNT WARN, $FAIL_COUNT FAIL"
echo "==================================="

if [ $FAIL_COUNT -gt 0 ]; then exit 1; fi
if [ $WARN_COUNT -gt 0 ]; then exit 2; fi
exit 0