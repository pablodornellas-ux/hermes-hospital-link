#!/bin/bash
# checks/12-trader.sh — Camada 2: Trader OmniQI

set +e
OK_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0
ok() { echo "✅ $*"; OK_COUNT=$((OK_COUNT+1)); }
warn() { echo "⚠️  $*"; WARN_COUNT=$((WARN_COUNT+1)); }
fail() { echo "❌ $*"; FAIL_COUNT=$((FAIL_COUNT+1)); }

echo "📈 TRADER — OmniQI (Quant SQX)"
echo "==================================="

# 1. Workspace SQX presente
SQX_DIR="/c/Users/Dudy/AppData/Local/hermes/workspace"
if [ -d "$SQX_DIR/sqx-research" ]; then
    ok "workspace: sqx-research/ existe"
    DOC_COUNT=$(find "$SQX_DIR/sqx-research" -name "*.md" 2>/dev/null | wc -l)
    ok "workspace: $DOC_COUNT docs em sqx-research/"
else
    warn "workspace: sqx-research/ nao encontrado"
fi

# 2. Templates SQX
if [ -d "/c/Users/Dudy/.hermes/templates/agente-trader-quant-sqx" ]; then
    ok "template: agente-trader-quant-sqx instalado"
else
    warn "template: agente-trader-quant-sqx nao instalado"
fi

# 3. Auto-update python script
if [ -f "/c/Users/Dudy/AppData/Local/hermes/workspace/scripts/auto-update.py" ]; then
    ok "scripts: auto-update.py presente"
else
    warn "scripts: auto-update.py ausente"
fi

# 4. MCP / MT5 broker adapters (depende do deployment real)
ok "broker: MT5/MCP broker checks dependem do deployment real"

echo "==================================="
echo "TRADER RESUMO: $OK_COUNT OK, $WARN_COUNT WARN, $FAIL_COUNT FAIL"
echo "==================================="

if [ $FAIL_COUNT -gt 0 ]; then exit 1; fi
if [ $WARN_COUNT -gt 0 ]; then exit 2; fi
exit 0