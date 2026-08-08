#!/bin/bash
# checks/10-augustus.sh — Camada 2: Augustus (Diretor Solfortes)
# Verifica: Telegram polling + Atanazio health + container Augustus

set +e

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

ok() { echo "✅ $*"; OK_COUNT=$((OK_COUNT+1)); }
warn() { echo "⚠️  $*"; WARN_COUNT=$((WARN_COUNT+1)); }
fail() { echo "❌ $*"; FAIL_COUNT=$((FAIL_COUNT+1)); }

echo "👤 AUGUSTUS — Diretor Solfortes"
echo "==================================="

# 1. Container Augustus rodando?
if command -v docker >/dev/null 2>&1; then
    # Tenta WSL primeiro
    AUGUSTUS_STATE=$(wsl -d Ubuntu -- docker ps --filter "name=augustus-hermes-standalone" --format "{{.Status}}" 2>/dev/null | head -1)
    if echo "$AUGUSTUS_STATE" | grep -q "Up"; then
        ok "container: augustus-hermes-standalone UP"
    elif [ -z "$AUGUSTUS_STATE" ]; then
        fail "container: augustus-hermes-standalone nao existe (precisa recriar)"
    else
        fail "container: augustus-hermes-standalone DOWN ($AUGUSTUS_STATE)"
    fi
else
    warn "container: docker nao disponivel no PATH"
fi

# 2. Atanazio (nucleo HTTP)
ATANAZIO_HEALTH=$(curl -fsS -m 3 http://localhost:18794/health 2>&1 || echo "FAIL")
if echo "$ATANAZIO_HEALTH" | grep -q "ok"; then
    ok "atanazio: nucleo :18794 respondendo"
else
    warn "atanazio: nucleo :18794 nao responde (ou outra porta)"
fi

# 3. Evolution API
EVOLUTION_HEALTH=$(curl -fsS -m 3 http://localhost:18793/ 2>&1 || echo "FAIL")
if echo "$EVOLUTION_HEALTH" | grep -qE "Welcome|Evolution"; then
    ok "evolution: API :18793 respondendo"
else
    warn "evolution: API :18793 nao responde"
fi

# 4. Telegram token
if grep -q "TELEGRAM_BOT_TOKEN" "${HERMES_HOME:-$HOME/.hermes}/.env" 2>/dev/null; then
    ok "telegram: TELEGRAM_BOT_TOKEN configurado"
else
    fail "telegram: TELEGRAM_BOT_TOKEN nao encontrado"
fi

# 5. Telegram sem proxy SQUID (causa raiz do bug de polling)
if grep -qE "HTTP_PROXY|HTTPS_PROXY" "${HERMES_HOME:-$HOME/.hermes}/.env" 2>/dev/null; then
    warn "telegram: proxy SQUID configurado (causa timeout Telegram)"
else
    ok "telegram: sem proxy SQUID (Telegram deve funcionar)"
fi

echo "==================================="
echo "AUGUSTUS RESUMO: $OK_COUNT OK, $WARN_COUNT WARN, $FAIL_COUNT FAIL"
echo "==================================="

if [ $FAIL_COUNT -gt 0 ]; then exit 1; fi
if [ $WARN_COUNT -gt 0 ]; then exit 2; fi
exit 0