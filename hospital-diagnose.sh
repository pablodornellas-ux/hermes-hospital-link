#!/bin/bash
# hospital-diagnose.sh — Hospital dos Agentes de IA (versão pública v2.0)
#
# CORRIGIDO: aponta pra repo público (hermes-hospital-link) em vez do privado
# ADICIONADO: estrutura em 2 camadas (base + especialidade)
# ADICIONADO: --fix / --quick / --layer=X / --tag=X
#
# Tags disponíveis:
#   v1.0.0-2026-08-08 (fixo)
#   main (rolling - última)
#
# USO:
#   bash <(curl -fsSL https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main/hospital-diagnose.sh)
#   bash <(curl -fsSL https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main/hospital-diagnose.sh) --fix
#   bash <(curl -fsSL .../main/hospital-diagnose.sh) --layer=augustus
#
# ESPECIALIDADES:
#   --layer=augustus  → Diretor Solfortes
#   --layer=salomao   → Orquestrador Diz a Bíblia Cortes
#   --layer=trader    → Trader OmniQI

set -e

GITHUB_USER="pablodornellas-ux"
GITHUB_REPO="hermes-hospital-link"
BRANCH="${BRANCH:-main}"
HERMES_HOME="${HERMES_HOME:-/root/.hermes}"

# Parse args
FIX_MODE=0
QUICK_MODE=0
LAYER="all"
for arg in "$@"; do
    case $arg in
        --fix) FIX_MODE=1 ;;
        --quick) QUICK_MODE=1 ;;
        --layer=*) LAYER="${arg#*=}" ;;
        --tag=*) BRANCH="${arg#*=}" ;;
        --augustus|--solfortes) LAYER="augustus" ;;
        --salomao|--diz-a-biblia) LAYER="salomao" ;;
        --trader|--omniqi) LAYER="trader" ;;
        --help|-h)
            echo "Uso: hospital-diagnose.sh [OPÇÕES]"
            echo
            echo "Opções:"
            echo "  --fix                    Aplica auto-fix após diagnóstico"
            echo "  --quick                  Apenas checagens system (não soul)"
            echo "  --layer=NOME             Só uma camada (base|augustus|salomao|trader)"
            echo "  --tag=VERSÃO             Fixar versão (ex: v1.0.0-2026-08-08)"
            echo "  --augustus / --solfortes Alias --layer=augustus"
            echo "  --salomao / --diz-a-biblia Alias --layer=salomao"
            echo "  --trader / --omniqi Alias --layer=trader"
            echo
            echo "Tags: https://github.com/$GITHUB_USER/$GITHUB_REPO/tags"
            exit 0
            ;;
    esac
done

echo "==================================="
echo "🏥 HERMES HOSPITAL v2.0"
echo "==================================="
echo "Data: $(date -Iseconds)"
echo "Hostname: $(hostname)"
echo "Source: github.com/$GITHUB_USER/$GITHUB_REPO@$BRANCH"
echo "Layer: $LAYER"
echo "Mode: $([ $FIX_MODE -eq 1 ] && echo 'FIX' || echo 'CHECK')$([ $QUICK_MODE -eq 1 ] && echo '+QUICK' || echo '')"
echo

# Detectar HERMES_HOME (multi-platform)
detect_home() {
    if [ -d "$HERMES_HOME" ]; then return; fi
    for path in "$HOME/.hermes" "/root/.hermes" "/c/Users/Administrator/.hermes" "/home/$(whoami)/.hermes"; do
        if [ -d "$path" ]; then
            HERMES_HOME="$path"
            export HERMES_HOME
            return
        fi
    done
}
detect_home
echo "Hermes Home: $HERMES_HOME"
echo

# Setup tmpdir
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Helper: baixar check
dl() {
    local f="$1"
    curl -fsSL "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/checks/$f.sh" -o "$f.sh" 2>/dev/null
}

# =============================================
# CAMADA 1 — BASE (todos os agentes Hermes)
# =============================================
if [ "$LAYER" = "all" ] || [ "$LAYER" = "base" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 CAMADA 1 — BASE (todos os agentes)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Tentar baixar checks individuais; se não existir, ainda roda diagnóstico local
    if dl "00-install"; then bash 00-install.sh; fi
    if [ $QUICK_MODE -eq 0 ] && dl "01-memory"; then bash 01-memory.sh; fi
    if [ $QUICK_MODE -eq 0 ] && dl "02-skills"; then bash 02-skills.sh; fi
    if [ $QUICK_MODE -eq 0 ] && dl "03-tools"; then bash 03-tools.sh; fi
    if [ $QUICK_MODE -eq 0 ] && dl "04-hooks"; then bash 04-hooks.sh; fi
    if [ $QUICK_MODE -eq 0 ] && dl "05-routines"; then bash 05-routines.sh; fi
    if [ $QUICK_MODE -eq 0 ] && dl "06-security"; then bash 06-security.sh; fi
    if dl "07-health"; then bash 07-health.sh; fi

    echo
fi

# =============================================
# CAMADA 2 — ESPECIALIDADES
# =============================================
case $LAYER in
    all|augustus)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "👤 CAMADA 2 — AUGUSTUS (Solfortes)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if dl "10-augustus"; then bash 10-augustus.sh; fi
        echo
        ;;
esac

case $LAYER in
    all|salomao)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎬 CAMADA 2 — SALOMÃO (Diz a Bíblia Cortes)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if dl "11-salomao"; then bash 11-salomao.sh; fi
        echo
        ;;
esac

case $LAYER in
    all|trader)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📈 CAMADA 2 — TRADER OMNIQI"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if dl "12-trader"; then bash 12-trader.sh; fi
        echo
        ;;
esac

# =============================================
# AUTO-FIX
# =============================================
if [ $FIX_MODE -eq 1 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 AUTO-FIX"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if dl "20-auto-fix"; then bash 20-auto-fix.sh; fi
    echo
fi

# =============================================
# REPORT
# =============================================
echo "==================================="
echo "📊 REPORT"
echo "==================================="
mkdir -p "$HERMES_HOME/workspace/reports" 2>/dev/null || true
REPORT="$HERMES_HOME/workspace/reports/doctor-$(date +%Y-%m-%d).md"

cat > "$REPORT" 2>/dev/null << EOF
# Hospital Report - $(date -Iseconds)

- Agent: $(hostname)
- Layer: $LAYER
- Mode: $([ $FIX_MODE -eq 1 ] && echo 'FIX' || echo 'CHECK')

See live output above.

---
Generated by hospital-diagnose.sh v2.0
EOF

echo "Report salvo em: $REPORT"
echo
echo "Próximos passos:"
echo "  - Ver report: cat $REPORT"
echo "  - Auto-update skills: python ~/.hermes/workspace/scripts/auto-update.py"
echo "  - Tags: https://github.com/$GITHUB_USER/$GITHUB_REPO/tags"
echo
echo "Link permanente:"
echo "  https://github.com/$GITHUB_USER/$GITHUB_REPO"

# Cleanup
rm -rf "$TMPDIR"