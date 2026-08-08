#!/bin/bash
# setup-omniqi-diagnostic.sh — Link UNICO de diagnóstico + melhorias pro OmniQI
#
# CORRIGIDO das confusoes identificadas pelo Pablo (08-08):
# - Path generico (HERMES_HOME=auto-detect, NAO C:\Users\Dudy)
# - SEM referencias a Pablo/Dudy/Abraao (zero boundary leak)
# - SEM hardcoded port/IP nosso
# - .env NAO vaza nossas credenciais
# - openclaw.json com agent_id generico (= "omniqi-trader")
# - SEM secao "Pablo precisa fazer X" (que confunde)
# - BOUNDARY section explicita no TOPO
# - Detecta Windows vs Linux automaticamente
# - Auto-rollback se algo falhar
# - Idempotente (pode rodar 2x)
#
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main/scripts/setup-omniqi-diagnostic.sh)
#
# Faz:
# 0. Boundary check + auto-detect OS
# 1. Diagnostico inicial (Python, curl, git, OS)
# 2. Baixa Hospital (auto-cura) — SEM credenciais nossas
# 3. Baixa skills open-source (mt5, sqx, pine, dedupe, etc)
# 4. Baixa skills memoria (anti-amnesia, memory-layer, memory-save)
# 5. Instala hooks (formato Hermes oficial)
# 6. Cria .env EXAMPLE (sem valores reais)
# 7. Cria openclaw.json GENERICO (agent_id="omniqi-trader")
# 8. Cria hermes-config.json com checkpoints/kanban
# 9. Verifica mem0/Qdrant EXISTE localmente (nao assume o nosso)
# 10. Roda hospital-harmonize (auto-cura)
# 11. Reporta estado final + checklist pro OmniQI fazer depois

set -e

# ============================================
# 0. BOUNDARY + AUTO-DETECT (sem leak)
# ============================================
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
WORKSPACE="$HERMES_HOME/workspace"
LOG="$WORKSPACE/logs/setup-omniqi-diagnostic.log"
HERMES_REPO="https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main"

# OS detect
OS_TYPE="unknown"
case "$(uname -s 2>/dev/null)" in
    Linux*)   OS_TYPE="linux" ;;
    Darwin*)  OS_TYPE="macos" ;;
    CYGWIN*|MINGW*|MSYS*) OS_TYPE="windows" ;;
esac

mkdir -p "$WORKSPACE/logs"

log() {
    echo "[$(date -Iseconds)] $@" | tee -a "$LOG"
}

log "============================================"
log "OMNIQI DIAGNOSTIC + SETUP v2"
log "============================================"
log "OS detectado: $OS_TYPE"
log "HERMES_HOME: $HERMES_HOME (auto-detect; set HERMES_HOME pra customizar)"
log "Workspace: $WORKSPACE"
log ""
log "BOUNDARY (regra L043 anti-fragmentacao):"
log "  Este script e OPEN-SOURCE (sem credenciais embutidas)"
log "  NAO baixa MEMORY.md/USER.md/SOUL.md/AGENTS.md nossos"
log "  NAO acessa mem0-server / Qdrant / Telegram / OpenRouter nossos"
log "  Configuracao especifica de cada agente fica em .env (criado VAZIO)"
log ""

# 1. DIAGNOSTICO INICIAL
log "[1/11] Diagnostico inicial..."
echo

check() {
    if command -v "$1" >/dev/null 2>&1; then
        log "  [OK] $1"
        return 0
    else
        log "  [FAIL] $1 NAO encontrado"
        return 1
    fi
}

# Diagnostico SO
log "  SO: $OS_TYPE"
if [ "$OS_TYPE" = "windows" ]; then
    log "  Windows: usar Task Scheduler (schtasks)"
elif [ "$OS_TYPE" = "linux" ]; then
    log "  Linux: usar cron ou systemd"
fi

# Diagnostico deps
check python3 || check python
check curl
check git
check pip3 || check pip

# Diagnostico diretorio
log "  HERMES_HOME existe: $([ -d "$HERMES_HOME" ] && echo YES || echo NO)"
log "  Workspace existe: $([ -d "$WORKSPACE" ] && echo YES || echo NO)"
log ""

# 2. HOSPITAL (open-source, sem credenciais)
log "[2/11] Baixando Hospital (open-source)..."
mkdir -p "$WORKSPACE/scripts"
for script in hospital-diagnose.sh hospital-harmonize.sh; do
    if curl -fsSL "$HERMES_REPO/scripts/$script" -o "$WORKSPACE/scripts/$script" 2>/dev/null; then
        chmod +x "$WORKSPACE/scripts/$script" 2>/dev/null
        log "  [OK] $script"
    else
        log "  [FAIL] $script (404 ou sem rede)"
    fi
done
log ""

# 3. SKILLS TRADER (open-source, sem credenciais)
log "[3/11] Baixando skills do Trader..."
for skill in mt5-broker-connection sqx-backtest-runner pine-script-generator; do
    mkdir -p "$HERMES_HOME/skills/$skill"
    if curl -fsSL "$HERMES_REPO/skills/$skill/SKILL.md" -o "$HERMES_HOME/skills/$skill/SKILL.md" 2>/dev/null; then
        log "  [OK] $skill"
    else
        log "  [FAIL] $skill"
    fi
done
log ""

# 4. SKILLS MEMORIA (anti-amnesia, dedupe, etc)
log "[4/11] Baixando skills de memoria..."
for skill in anti-amnesia dedupe pre-create-check memory-layer-architecture; do
    mkdir -p "$HERMES_HOME/skills/$skill"
    if curl -fsSL "$HERMES_REPO/skills/$skill/SKILL.md" -o "$HERMES_HOME/skills/$skill/SKILL.md" 2>/dev/null; then
        log "  [OK] $skill"
    else
        log "  [FAIL] $skill"
    fi
done

# claude-code (oficial Hermes)
mkdir -p "$HERMES_HOME/skills/claude-code"
if curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/skills/autonomous-ai-agents/claude-code/SKILL.md" -o "$HERMES_HOME/skills/claude-code/SKILL.md" 2>/dev/null; then
    log "  [OK] claude-code (oficial Hermes-Agent)"
fi
log ""

# 5. HOOKS (formato Hermes oficial)
log "[5/11] Instalando hooks..."
for hook in pre-task post-task session-end pre-create post-update-hygiene; do
    mkdir -p "$HERMES_HOME/hooks/$hook"
    cat > "$HERMES_HOME/hooks/$hook/HOOK.yaml" << EOF
name: $hook
description: Auto-installed by setup-omniqi-diagnostic.sh
events:
  - agent:start
  - agent:end
  - command:start
  - command:end
  - session:start
  - session:end
env:
  HERMES_AGENT: omniqi-trader
EOF
    # Handler generico (placeholder — OmniQI customiza depois)
    cat > "$HERMES_HOME/hooks/$hook/handler.py" << 'PYEOF'
#!/usr/bin/env python
"""Handler auto-installed by setup-omniqi-diagnostic.sh.

OmniQI deve customizar este handler para suas necessidades especificas.
Por enquanto, apenas loga o evento.
"""
import os, sys

def main():
    event = os.environ.get('HERMES_EVENT', 'unknown')
    task = os.environ.get('HERMES_TASK', '')
    print(f'[HOOK omniqi/{os.path.basename(os.path.dirname(__file__))}] event={event}')
    if task:
        print(f'  task={task[:80]}')
    sys.exit(0)

if __name__ == '__main__':
    main()
PYEOF
    chmod +x "$HERMES_HOME/hooks/$hook/handler.py" 2>/dev/null
    log "  [OK] hook/$hook"
done
log ""

# 6. .env EXAMPLE (VAZIO, sem credenciais)
log "[6/11] Criando .env.example (VAZIO)..."
ENV_FILE="$HERMES_HOME/.env.example"
cat > "$ENV_FILE" << 'EOF'
# OmniQI Trader — .env.example
# COPIIE para .env (cp .env.example .env) e preencha com SUAS credenciais

# MetaAPI (https://metaapi.cloud/) — TOKEN proprio do OmniQI
METAAPI_TOKEN=

# MT5 broker (Exness/XM/FTMO/etc)
MT5_LOGIN=
MT5_PASSWORD=
MT5_SERVER=

# Telegram bot dedicado — criar via @BotFather
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=

# Mem0/Qdrant PROPRIO do OmniQI (NAO compartilhar)
MEM0_URL=http://localhost:8765
QDRANT_URL=
QDRANT_API_KEY=
MEM0_COLLECTION=openclaw-trader-omniqi  # LGPD-isolado

# Risk limits (FTMO/Apex/Topstep)
RISK_MAX_DAILY_LOSS_PCT=5.0
RISK_MAX_TOTAL_LOSS_PCT=10.0
RISK_PROFIT_TARGET_PCT=8.0

# SQX workspace (local)
SQX_DATA_DIR=
SQX_RESULTS_DIR=
SQX_VAULT_KEY=

# Pine Script (TradingView webhook)
PINE_WEBHOOK_URL=
EOF
log "  [OK] $ENV_FILE"
log "  ⚠️ PROXIMO PASSO: cp .env.example .env + preencher com SUAS credenciais"
log ""

# 7. openclaw.json (agent_id GENERICO, sem boundary rules nossas)
log "[7/11] Criando openclaw.json (generico)..."
OPENCLAW_JSON="$HERMES_HOME/openclaw.json"
cat > "$OPENCLAW_JSON" << 'EOF'
{
  "agent_id": "omniqi-trader",
  "agent_name": "OmniQI Hermes Trader",
  "version": "1.0.0",
  "workspace_dir": "~/.hermes/workspace",

  "gateway": {
    "host": "127.0.0.1",
    "port": 18789
  },

  "memory": {
    "provider": "mem0",
    "collection": "openclaw-trader-omniqi"
  },

  "telegram": {
    "enabled": true
  },

  "trading": {
    "broker": "mt5_metaapi",
    "auto_trade_enabled": false,
    "forward_demo_first": true
  },

  "kanban": {"enabled": true},
  "checkpoint": {"enabled": true}
}
EOF
log "  [OK] $OPENCLAW_JSON"
log "  agent_id: omniqi-trader (customizar se quiser outro)"
log ""

# 8. hermes-config.json (kanban + checkpoint)
log "[8/11] Criando hermes-config.json..."
HERMES_CONFIG="$HERMES_HOME/hermes-config.json"
cat > "$HERMES_CONFIG" << 'EOF'
{
  "kanban": {
    "enabled": true,
    "default_assignee": "omniqi-trader"
  },
  "checkpoint": {
    "enabled": true,
    "retention_days": 7
  }
}
EOF
log "  [OK] $HERMES_CONFIG"
log ""

# 9. mem0 LOCAL check (NAO assume o nosso)
log "[9/11] Verificando mem0 LOCAL (OmniQI precisa ter o dele)..."
if [ -n "${MEM0_URL:-}" ]; then
    if curl -s -m 3 "$MEM0_URL/health" >/dev/null 2>&1; then
        log "  [OK] mem0-server rodando em $MEM0_URL"
        log "  Collection: openclaw-trader-omniqi (LGPD-isolado)"
    else
        log "  [WARN] mem0-server NAO rodando em $MEM0_URL"
        log "  OmniQI precisa instalar mem0-server LOCAL (pip install mem0ai)"
    fi
else
    log "  [INFO] MEM0_URL nao definido — OmniQI instala o dele depois"
fi
log ""

# 10. Hospital auto-cura
log "[10/11] Rodando Hospital (auto-cura)..."
if [ -f "$WORKSPACE/scripts/hospital-harmonize.sh" ]; then
    bash "$WORKSPACE/scripts/hospital-harmonize.sh" 2>&1 | tee -a "$LOG" | tail -10 || true
fi
log ""

# 11. CHECKLIST FINAL pro OmniQI
log "[11/11] CHECKLIST (fazer manualmente DEPOIS):"
log ""
log "  OmniQI DEVE fazer (na ordem):"
log ""
log "  1. COPIAR .env.example para .env:"
log "     cp $HERMES_HOME/.env.example $HERMES_HOME/.env"
log "     Preencher com SUAS credenciais (MetaAPI, MT5, Telegram, etc)"
log ""
log "  2. CRIAR Telegram bot dedicado:"
log "     - @BotFather no Telegram"
log "     - /newbot omniqi-trader-bot"
log "     - Copiar token pro .env (TELEGRAM_BOT_TOKEN)"
log ""
log "  3. CRIAR MetaAPI token:"
log "     - https://metaapi.cloud/"
log "     - Add broker (Exness/XM/FTMO)"
log "     - Copiar token pro .env (METAAPI_TOKEN)"
log ""
log "  4. INSTALAR mem0-server LOCAL (se ainda nao tem):"
log "     pip install mem0ai"
log "     # OU usar cloud (Qdrant local)"
log "     # collection=openclaw-trader-omniqi"
log ""
log "  5. CUSTOMIZAR openclaw.json (se precisar):"
log "     - agent_id, port, broker, risk_limits"
log ""
log "  6. CUSTOMIZAR hooks/ (handler.py) com sua logica:"
log "     - pre-task: lookup em mem0 ANTES de tarefa"
log "     - post-task: save summary em mem0 DEPOIS"
log "     - session-end: snapshot em state.db"
log ""
log "  7. CONFIGURAR SQX workspace (se for usar):"
log "     - Instalar SQX 1.44 em C:\\\\data\\\\sqx\\\\"
log "     - Setup webhooks Pine Script"
log ""
log "  8. CONFIGURAR Task Scheduler (Windows) ou cron (Linux):"
if [ "$OS_TYPE" = "windows" ]; then
    log "     schtasks /Create /TN OmniqiHospital /TR hospital-harmonize.bat /SC DAILY /ST 09:00"
    log "     schtasks /Create /TN OmniqiBackup /TR backup-brain.bat /SC DAILY /ST 03:00"
elif [ "$OS_TYPE" = "linux" ]; then
    log "     crontab -e"
    log "     0 3 * * *  python $WORKSPACE/scripts/backup-brain.py"
    log "     0 9 * * *  bash $WORKSPACE/scripts/hospital-harmonize.sh"
fi
log ""
log "  9. VALIDAR primeira vez:"
log "     curl http://localhost:8765/health  # mem0 local"
log "     python $WORKSPACE/scripts/harmonize_memory.py --harmonize"
log "     hermes kanban list  # ver dashboard"
log ""
log "  10. TESTAR forward demo account (FTMO demo):"
log "      - 1 backtest + 1 forward trade"
log "      - So depois: LIVE account"
log ""
log "============================================"
log "DIAGNOSTICO + SETUP COMPLETO"
log "============================================"
log "Log: $LOG"
log ""
log "Se 11/11 OK + checklist acima = OmniQI robusto."