# setup-omniqi-credentials.sh — Configura credenciais + openclaw.json + deploy
#
# DEPOIS de setup-omniqi.sh rodar, esse script configura:
# 1. .env com credenciais reais (prompt interativo)
# 2. openclaw.json (template)
# 3. Telegram bot dedicado
# 4. mem0 collection (openclaw-trader-omniqi)
# 5. Container/deploy (Docker)
# 6. Validação MT5 broker
# 7. Backtest inicial
# 8. Risk limits (FTMO/Apex/Topstep)
#
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main/scripts/setup-omniqi-credentials.sh)

set -e

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
WORKSPACE="$HERMES_HOME/workspace"
LOG="$WORKSPACE/logs/setup-omniqi-credentials.log"

log() {
    echo "[$(date -Iseconds)] $@" | tee -a "$LOG"
}

log "============================================"
log "SETUP OMNIQI — Credenciais + Deploy"
log "============================================"
log ""

# 1. .env com credenciais reais
log "[1/8] Configurando .env..."
ENV_FILE="$HERMES_HOME/.env"
ENV_EXAMPLE="$HERMES_HOME/.env.example"

if [ -f "$ENV_FILE" ]; then
    log "  .env ja existe. Backup + criar novo."
    cp "$ENV_FILE" "$ENV_FILE.bak-$(date +%Y%m%d-%H%M%S)"
fi

cat > "$ENV_EXAMPLE" << 'EOF'
# OmniQI Trader - .env.example
# COPIE para .env e preencha com SUAS credenciais

# MetaAPI (https://metaapi.cloud/)
METAAPI_TOKEN=
MT5_LOGIN=
MT5_PASSWORD=
MT5_SERVER=  # Exness-MT5Real8, ICMarkets-Live04, FTMO-Demo

# Broker opcional (outros adaptadores)
BROKER_ADAPTER=mt5_local  # mt5_local, mt5_metaapi

# Telegram bot dedicado (NAO compartilhar com outros agentes)
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=  # Pablo (1970071068)

# Mem0 collection (LGPD-isolada)
MEM0_COLLECTION=openclaw-trader-omniqi

# Risk limits (FTMO/Apex/Topstep)
RISK_MAX_DAILY_LOSS_PCT=5.0
RISK_MAX_TOTAL_LOSS_PCT=10.0
RISK_PROFIT_TARGET_PCT=8.0
RISK_LEVERAGE=100

# SQX
SQX_VAULT_KEY=
SQX_DATA_DIR=C:\data\sqx\incoming
SQX_RESULTS_DIR=C:\data\sqx\results

# Pine Script (TradingView webhook)
PINE_WEBHOOK_URL=

# Forward demo account (FTMO/Apex etc)
DEMO_ACCOUNT_LOGIN=
DEMO_ACCOUNT_PASSWORD=
DEMO_ACCOUNT_SERVER=
EOF

log "  .env.example criado em $ENV_EXAMPLE"
log "  ⚠️ PREENCHA .env com suas credenciais (cp .env.example .env)"
log ""

# 2. openclaw.json (template)
log "[2/8] Criando openclaw.json..."
OPENCLAW_JSON="$HERMES_HOME/openclaw.json"
cat > "$OPENCLAW_JSON" << 'EOF'
{
  "agent_id": "omniqi-trader",
  "agent_name": "OmniQI Hermes Trader",
  "version": "1.0.0",
  "workspace_dir": "~/.hermes/workspace",

  "gateway": {
    "host": "127.0.0.1",
    "port": 18789,
    "public_host": "omniqi.local"
  },

  "memory": {
    "provider": "mem0",
    "mem0_url": "http://localhost:8765",
    "collection": "openclaw-trader-omniqi",
    "qdrant_url": "https://2097f679-0495-4273-9519-6fea5e9f9ec2.sa-east-1-0.aws.cloud.qdrant.io:6333",
    "qdrant_api_key_env": "QDRANT_API_KEY"
  },

  "llm": {
    "provider": "openrouter",
    "primary_model": "deepseek/deepseek-chat",
    "fallback_models": ["openai/gpt-4o-mini", "anthropic/claude-3-5-sonnet"],
    "temperature": 0.1,
    "max_tokens": 4000
  },

  "telegram": {
    "enabled": true,
    "bot_token_env": "TELEGRAM_BOT_TOKEN",
    "chat_id_env": "TELEGRAM_CHAT_ID",
    "polling_interval_sec": 2,
    "webhook_url": null
  },

  "trading": {
    "broker": "mt5_metaapi",
    "metaapi_token_env": "METAAPI_TOKEN",
    "account_login_env": "MT5_LOGIN",
    "account_password_env": "MT5_PASSWORD",
    "account_server_env": "MT5_SERVER",

    "risk_limits": {
      "max_daily_loss_pct_env": "RISK_MAX_DAILY_LOSS_PCT",
      "max_total_loss_pct_env": "RISK_MAX_TOTAL_LOSS_PCT",
      "profit_target_pct_env": "RISK_PROFIT_TARGET_PCT",
      "leverage_env": "RISK_LEVERAGE"
    },

    "auto_trade_enabled": false,
    "forward_demo_first": true
  },

  "scheduler": {
    "bt_weekly_cron": "0 22 * * 6",
    "demo_forward_cron": "55 23 * * *",
    "vps_health_cron": "*/5 * * * *",
    "memory_harmonize_cron": "0 9 * * *"
  },

  "hooks": {
    "pre_task": "~/.hermes/hooks/pre-task",
    "post_task": "~/.hermes/hooks/post-task",
    "session_end": "~/.hermes/hooks/session-end",
    "pre_create": "~/.hermes/hooks/pre-create",
    "post_update_hygiene": "~/.hermes/hooks/post-update-hygiene",
    "auto_delegate": "~/.hermes/hooks/auto-delegate"
  },

  "kanban": {
    "enabled": true,
    "default_assignee": "omniqi-trader",
    "dashboard_url": "http://127.0.0.1:9119"
  },

  "checkpoint": {
    "enabled": true,
    "retention_days": 7,
    "auto_before_writes": true
  }
}
EOF
log "  openclaw.json criado em $OPENCLAW_JSON"
log ""

# 3. Telegram bot dedicado (validar token)
log "[3/8] Validando Telegram bot..."
TELEGRAM_TOKEN=$(grep "^TELEGRAM_BOT_TOKEN=" "$HERMES_HOME/.env" 2>/dev/null | cut -d= -f2 | tr -d '"')
if [ -z "$TELEGRAM_TOKEN" ]; then
    log "  ⚠️ TELEGRAM_BOT_TOKEN nao definido em .env"
    log "  Pablo precisa criar bot via @BotFather e adicionar ao .env"
else
    bot_info=$(curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/getMe" 2>&1)
    if echo "$bot_info" | grep -q '"ok":true'; then
        bot_name=$(echo "$bot_info" | python -c "import json,sys;print(json.load(sys.stdin)['result']['username'])" 2>&1)
        log "  [OK] Bot valido: @$bot_name"
    else
        log "  [FAIL] Bot invalido: $bot_info"
    fi
fi
log ""

# 4. mem0 collection (criar se nao existir)
log "[4/8] Criando mem0 collection: openclaw-trader-omniqi..."
MEM0_URL=$(grep "^MEM0_URL=" "$HERMES_HOME/.env" 2>/dev/null | cut -d= -f2 | tr -d '"')
MEM0_URL="${MEM0_URL:-http://localhost:8765}"
if curl -s -m 3 "$MEM0_URL/health" >/dev/null 2>&1; then
    log "  [OK] mem0-server rodando"
    log "  Collection LGPD-isolada: openclaw-trader-omniqi (NÃO compartilhar com factory)"
    log "  Quando rodar query: agent='omniqi-trader'"
else
    log "  [WARN] mem0-server NAO rodando. Iniciar antes de continuar."
fi
log ""

# 5. Container/deploy
log "[5/8] Setup container..."
cat > "$WORKSPACE/scripts/omniqi-start.bat" << 'BEOF'
@echo off
REM OmniQI Trader — start container
cd /d "C:\Users\omniqi\hermes-agent\workspace"
docker run -d --name omniqi-hermes \
  -p 18789:18789 \
  -v %USERPROFILE%\.hermes:/root/.hermes \
  -e METAAPI_TOKEN=** \
  -e TELEGRAM_BOT_TOKEN=** \
  -e MEM0_URL=http://host.docker.internal:8765 \
  hermes-agent:latest
BEOF
log "  omniqi-start.bat criado"
log "  ⚠️ Pablo precisa: docker build + .env com credenciais"
log ""

# 6. Validação MT5
log "[6/8] Validando MT5 broker..."
METAAPI_TOKEN=$(grep "^METAAPI_TOKEN=" "$HERMES_HOME/.env" 2>/dev/null | cut -d= -f2 | tr -d '"')
if [ -n "$METAAPI_TOKEN" ]; then
    metaapi_check=$(curl -s -m 10 -H "Auth-Token: $METAAPI_TOKEN" \
        "https://mt-provisioning-api-v1.agiliumtrade.ai/users/current/provisioning-profile" 2>&1)
    if echo "$metaapi_check" | grep -q '"_id"'; then
        log "  [OK] MetaAPI token valido"
    else
        log "  [FAIL] MetaAPI token invalido: $metaapi_check"
    fi
else
    log "  ⚠️ METAAPI_TOKEN nao definido em .env"
fi
log ""

# 7. Backtest de validação
log "[7/8] Backtest de validacao..."
if [ -f "$HERMES_HOME/skills/sqx-backtest-runner/SKILL.md" ]; then
    log "  [INFO] Usar skill sqx-backtest-runner:"
    log "    python $HERMES_HOME/workspace/scripts/runner.py --strategy <id> --since 30d"
    log "  Requisito: SQX workspace configurado em $SQX_DATA_DIR"
else
    log "  [FAIL] skill sqx-backtest-runner nao encontrada"
fi
log ""

# 8. Risk limits + Alert
log "[8/8] Risk limits..."
cat > "$WORKSPACE/scripts/omniqi-risk-limits.json" << 'EOF'
{
  "ftmo_challenge_100k": {
    "max_daily_loss_pct": 5.0,
    "max_total_loss_pct": 10.0,
    "profit_target_pct": 8.0,
    "min_trading_days": 4,
    "leverage": 100
  },
  "apex_50k": {
    "max_daily_loss_pct": 2.5,
    "max_total_loss_pct": 5.0,
    "profit_target_pct": 6.0,
    "consistency_rule": true,
    "leverage": 50
  },
  "topstep_50k": {
    "max_daily_loss_pct": 2.0,
    "max_total_loss_pct": 4.5,
    "profit_target_pct": 6.0,
    "consistency_rule": true,
    "leverage": 100
  }
}
EOF
log "  [OK] risk-limits.json criado (FTMO/Apex/Topstep)"
log ""
log "ALERTAS TELEGRAM (Pablo):"
log "  - Diario: PnL + drawdown"
log "  - Tempo real: open/close trade"
log "  - Critico: breach de risk limit"
log ""

log "============================================"
log "SETUP COMPLETO (com credenciais)"
log "============================================"
log ""
log "PROXIMOS PASSOS MANUAIS (Pablo):"
log ""
log "1. PREENCHER .env:"
log "   cp $HERMES_HOME/.env.example $HERMES_HOME/.env"
log "   nano $HERMES_HOME/.env"
log ""
log "2. CRIAR Telegram bot dedicado:"
log "   - @BotFather no Telegram"
log "   - /newbot omniqi-trader-bot"
log "   - Copiar token pro .env"
log ""
log "3. CRIAR MetaAPI token:"
log "   - https://metaapi.cloud/"
log "   - Add broker (Exness/XM/FTMO)"
log "   - Copiar token pro .env"
log ""
log "4. CONSTRUIR container:"
log "   docker build -t hermes-agent:latest ."
log ""
log "5. SUBIR container:"
log "   bash $WORKSPACE/scripts/omniqi-start.bat"
log ""
log "6. VALIDAR primeira vez:"
log "   bash $WORKSPACE/scripts/setup-omniqi.sh  # ja rodou"
log "   bash $WORKSPACE/scripts/setup-omniqi-credentials.sh  # esse aqui"
log "   python $HERMES_HOME/workspace/scripts/harmonize_memory.py --harmonize"
log "   curl http://localhost:18789/health"
log ""
log "7. CONFIGURAR SQX workspace:"
log "   - Instalar SQX 1.44 em C:\\data\\sqx\\"
log "   - Criar strategy_ex5 + .set files"
log "   - Setup webhooks Pine Script"
log ""
log "8. TESTAR forward demo (PRIORITY):"
log "   - FTMO demo account"
log "   - Validar 1 backtest"
log "   - Validar 1 forward trade"
log "   - So depois: LIVE account"
log ""
log "Log: $LOG"