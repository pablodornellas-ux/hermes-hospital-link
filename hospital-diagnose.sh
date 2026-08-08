#!/bin/bash
# diagnose.sh — Augustus ir no Hospital
# Como rodar:
#   bash <(curl -fsSL https://raw.githubusercontent.com/pablodornellas-ux/hermes-agent-templates/main/scripts/diagnose.sh)
# OU local:
#   bash /opt/nucleo/diagnose.sh

set -e

HERMES_HOME="${HERMES_HOME:-/root/.hermes}"
GITHUB_USER="pablodornellas-ux"
GITHUB_REPO="hermes-agent-templates"

echo "==================================="
echo "🏥 HERMES HOSPITAL - DIAGNOSE"
echo "==================================="
echo
echo "Data: $(date -Iseconds)"
echo "Hostname: $(hostname)"
echo "Hermes Home: $HERMES_HOME"
echo

# 1. Baixar scripts do Hospital
echo "[1] Baixando doctor-agent..."
mkdir -p /tmp/hermes-hospital
cd /tmp/hermes-hospital

curl -fsSL "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/templates/doctor-agent/scripts/hermes-doctor.py" -o hermes-doctor.py 2>/dev/null || \
curl -fsSL "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/templates/doctor-agent/scripts/hermes-doctor.py" -o hermes-doctor.py

if [ ! -f hermes-doctor.py ]; then
    echo "❌ Falha ao baixar hermes-doctor.py"
    echo "   Vou tentar via clone..."
    git clone --depth 1 "https://github.com/$GITHUB_USER/$GITHUB_REPO.git" hospital 2>&1 | tail -3
    if [ -f hospital/templates/doctor-agent/scripts/hermes-doctor.py ]; then
        cp hospital/templates/doctor-agent/scripts/hermes-doctor.py .
    fi
fi

if [ ! -f hermes-doctor.py ]; then
    echo "❌ Não foi possível baixar. Verifique:"
    echo "   - Conexão internet"
    echo "   - Acesso a github.com"
    echo "   - Token GitHub (se repo for privado)"
    exit 1
fi

echo "✅ Download OK ($(wc -l < hermes-doctor.py) linhas)"
echo

# 2. Rodar diagnóstico
echo "[2] Rodando diagnóstico..."
echo
python3 hermes-doctor.py --quick
RESULT=$?

echo
echo "==================================="
echo "📋 RESULTADO"
echo "==================================="
if [ $RESULT -eq 0 ]; then
    echo "✅ Score >= 80 (HEALTHY)"
    echo "   Tudo OK!"
else
    echo "⚠️ Score < 80 (WARNING ou CRITICAL)"
    echo
    echo "Report salvo em: $HERMES_HOME/workspace/reports/doctor-*.md"
    echo
    echo "Próximos passos - FASE 3 (auto-fix):"
    echo "  python3 hermes-doctor.py --fix"
fi
echo
echo "Link permanente:"
echo "  https://github.com/$GITHUB_USER/$GITHUB_REPO/tree/main/templates/doctor-agent"
echo
echo "Report:"
echo "  https://github.com/$GITHUB_USER/$GITHUB_REPO/blob/main/templates/doctor-agent/README.md"