#!/bin/bash
# hospital-harmonize.sh — Pipeline completo de manutenção pra QUALQUER Hermes-agent
# Uso:
#   bash <(curl -fsSL https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main/scripts/hospital-harmonize.sh)
#
# O que faz:
# 1. Baixa Hospital + scripts de manutenção
# 2. Roda harmonize_memory.py (check L1-L7)
# 3. Roda state-db-vacuum.py (se necessário)
# 4. Roda diagnóstico Hospital
# 5. Reporta score final

set -e

REPO="pablodornellas-ux/hermes-hospital-link"
BRANCH="${BRANCH:-main}"
WORKDIR=$(mktemp -d)
cd "$WORKDIR"

echo "============================================"
echo "🏥 HOSPITAL HARMONIZE — Pipeline completo"
echo "============================================"
echo "Timestamp: $(date -Iseconds)"
echo "Hostname: $(hostname)"
echo

# 1. Baixar scripts
echo "[1] Baixando scripts de manutenção..."
mkdir -p scripts
curl -fsSL "https://raw.githubusercontent.com/$REPO/$BRANCH/scripts/harmonize_memory.py" -o scripts/harmonize_memory.py
curl -fsSL "https://raw.githubusercontent.com/$REPO/$BRANCH/scripts/state-db-vacuum.py" -o scripts/state-db-vacuum.py

if [ ! -f scripts/harmonize_memory.py ]; then
    echo "❌ Falha ao baixar scripts"
    exit 1
fi

echo "✅ Scripts baixados"
echo

# 2. Detectar Python
PYTHON=$(command -v python3 || command -v python)
if [ -z "$PYTHON" ]; then
    echo "❌ Python não encontrado (instale Python 3.10+)"
    exit 1
fi

echo "Python: $PYTHON"
echo

# 3. Rodar harmonize (com auto-fix)
echo "[2] Rodando harmonize_memory.py --harmonize..."
echo "============================================"
$PYTHON scripts/harmonize_memory.py --harmonize
HARMONIZE_EXIT=$?
echo

# 4. Rodar VACUUM adicional se necessário
if [ $HARMONIZE_EXIT -ne 0 ]; then
    echo "[3] Rodando VACUUM adicional..."
    echo "============================================"
    $PYTHON scripts/state-db-vacuum.py
    echo
fi

# 5. Relatório final
echo "============================================"
echo "📊 RESUMO"
echo "============================================"
if [ $HARMONIZE_EXIT -eq 0 ]; then
    echo "✅ Memoria harmônica — todas as camadas operacionais"
    echo
    echo "Próximas ações:"
    echo "  - Daily 09:00: rodar este script via Task Scheduler"
    echo "  - Se state.db > 60MB: VACUUM será automático"
    echo "  - Se MEMORY.md > 80%: rodar --harmonize de novo"
else
    echo "⚠️ Há itens precisando atenção. Veja log acima."
fi
echo
echo "Scripts disponíveis em: https://github.com/$REPO/tree/main/scripts"
echo "Documentação: https://github.com/$REPO/blob/main/skills/memory-layer-architecture/SKILL.md"

# Limpar
rm -rf "$WORKDIR"