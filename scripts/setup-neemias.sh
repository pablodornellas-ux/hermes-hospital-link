#!/bin/bash
# setup-neemias.sh — Setup do Hermes-Agent Neemias (ambiente Anderson)
#
# IDENTIDADE:
# - Neemias = trader do Anderson Medeiros
# - Maquina: BETA (Windows Server, 100.103.213.58)
# - SQX: 1.44 Full em C:\Users\Beta\Desktop\SQX_144_Full\
# - MCP server: :8765 (read-only, monitora/start/stop projeto)
# - Projeto: APROVA FTMO SWING (9 familias F1-F9, XAUUSD)
# - NAO e OmniQI! NAO e Abraao! E um trader SOB Anderson.
#
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main/scripts/setup-neemias.sh)
#
# Faz:
# 1. Diagnostico inicial (BETA-specifico)
# 2. Baixa Hospital link + 6 scripts manutencao
# 3. Instala skills FTMO/SQX/MT5 (especificas do trader)
# 4. Cria setup-neemias.bat (Task Scheduler Windows)
# 5. Configura memoria FTMO + Anderson (LGPD-isolado)
# 6. Auto-update continuo (busca recursos Neemias)
# 7. Reporta estado final

set -e

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
WORKSPACE="$HERMES_HOME/workspace"
FTMO_DIR="$WORKSPACE/ftmo_pipeline"
LOG="$WORKSPACE/logs/setup-neemias.log"
HERMES_REPO="https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main"

mkdir -p "$WORKSPACE/logs"
mkdir -p "$FTMO_DIR"

log() {
    echo "[$(date -Iseconds)] $@" | tee -a "$LOG"
}

log "============================================"
log "SETUP NEEMIAS — Hermes-Agent (Anderson)"
log "HERMES_HOME: $HERMES_HOME"
log "BETA IP: 100.103.213.58"
log "============================================"
log ""

# 0. Identidade (NÃO confundir com OmniQI/Abraao)
log "[0/8] Identidade:"
log "  Agente: NEEMIAS"
log "  Owner: ANDERSON MEDEIROS (nao Pablo direto)"
log "  Ambiente: BETA (Windows Server 100.103.213.58)"
log "  Projeto: APROVA FTMO SWING (9 familias)"
log "  SQX: 1.44 Full"
log "  Diferenca vs OmniQI: NEEMIAS = ambiente Anderson, OMNIQI = Pablo direto"
log ""

# 1. DIAGNÓSTICO INICIAL
log "[1/8] Diagnostico inicial..."
check() {
    if command -v "$1" >/dev/null 2>&1; then
        log "  [OK] $1"
    else
        log "  [FAIL] $1 NAO encontrado"
    fi
}
check python3 || check python
check curl
check git

# 2. HOSPITAL + SCRIPTS MANUTENCAO
log ""
log "[2/8] Baixando Hospital + scripts..."
mkdir -p "$WORKSPACE/scripts"
mkdir -p "$FTMO_DIR/scripts"
for script in hospital-diagnose.sh hospital-harmonize.sh harmonize_memory.py memory-purify.py memory-smart-add.py state-db-vacuum.py session-snapshot.py; do
    if curl -fsSL "$HERMES_REPO/scripts/$script" -o "$WORKSPACE/scripts/$script" 2>/dev/null; then
        chmod +x "$WORKSPACE/scripts/$script" 2>/dev/null
        cp "$WORKSPACE/scripts/$script" "$FTMO_DIR/scripts/" 2>/dev/null
        log "  [OK] $script"
    else
        log "  [FAIL] $script"
    fi
done

# 3. SKILLS ESPECÍFICAS (FTMO/SQX/MT5)
log ""
log "[3/8] Baixando skills especificas do Neemias..."
for skill in ftmo-builder-pipeline sqx-backtest-runner mt5-broker-connection pine-script-generator anti-amnesia dedupe pre-create-check kanban-checkpoint; do
    mkdir -p "$HERMES_HOME/skills/$skill"
    if curl -fsSL "$HERMES_REPO/skills/$skill/SKILL.md" -o "$HERMES_HOME/skills/$skill/SKILL.md" 2>/dev/null; then
        log "  [OK] skill/$skill"
    else
        log "  [FAIL] skill/$skill"
    fi
done

# Skill claude-code (oficial Hermes-Agent)
mkdir -p "$HERMES_HOME/skills/claude-code"
if curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/skills/autonomous-ai-agents/claude-code/SKILL.md" -o "$HERMES_HOME/skills/claude-code/SKILL.md" 2>/dev/null; then
    log "  [OK] skill/claude-code (oficial Hermes)"
fi

# 4. SETUP-NEEMIAS.BAT (Task Scheduler Windows)
log ""
log "[4/8] Criando setup-neemias.bat..."
cat > "$WORKSPACE/scripts/NeemiasHospital.bat" << 'BEOF'
@echo off
REM NeemiasHospital - daily 09:00 - harmonize_memory + dedup
cd /d "C:\Users\Beta\hermes-agent\workspace"
python "C:\Users\Beta\hermes-agent\workspace\scripts\hospital-harmonize.sh" 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Neemias Hospital completed at %date% %time%
) else (
    echo [ERR] Neemias Hospital failed at %date% %time% >> "C:\Users\Beta\hermes-agent\workspace\logs\neemias-hospital-errors.log"
)
BEOF
log "  [OK] NeemiasHospital.bat criado (configurar Task Scheduler manualmente)"

# 5. MEMORIA ESPECÍFICA (LGPD-isolado)
log ""
log "[5/8] Configurando memoria especifica do Neemias..."
mkdir -p "$HERMES_HOME/workspace/neemias"
cat > "$HERMES_HOME/workspace/neemias/MEMORY.md" << 'EOF'
# MEMORY.md — Neemias (Hermes-Agent Trader do Anderson)

## Identidade
- **Agente:** Neemias (NAO e OmniQI/Abraao)
- **Owner:** Anderson Medeiros (cliente)
- **Ambiente:** BETA Windows Server (100.103.213.58)
- **SQX:** 1.44 Full em C:\Users\Beta\Desktop\SQX_144_Full\
- **MCP:** :8765 read-only (11 tools)
- **Projeto atual:** APROVA FTMO SWING (9 familias F1-F9 XAUUSD)

## Boundary rules (Anderson)
- Anderson decide trades (NAO Pablo direto)
- Neemias minera estrategias e faz BT
- Pablo monitora + audita (sem trade authority)
- Telegram SO Anderson (Pablo nao interfere)

## Projeto APROVA FTMO SWING
- Finalizado 2026-08-06 (Pablo decidiu NAO criar F11)
- 9 familias: F1-F9 XAUUSD daytrade
- Fitness: FTMO_Fit (media geometrica, gate 3.5% DD)
- Anti-overfit: 5 salvaguardas (S1-S5)
- Regime detection: cross-validation granular P/L/S
EOF
log "  [OK] MEMORY.md criado (Anderson-isolado)"

# 6. AUTO-UPDATE CONTINUO
log ""
log "[6/8] Configurando auto-update..."
cat > "$WORKSPACE/scripts/NeemiasAutoUpdate.bat" << 'BEOF'
@echo off
REM NeemiasAutoUpdate - weekly Seg 09:00
cd /d "C:\Users\Beta\hermes-agent\workspace"
python "C:\Users\Beta\hermes-agent\workspace\scripts\auto-update-claude-resources.py" 2>&1
BEOF
log "  [OK] NeemiasAutoUpdate.bat criado"

# 7. MEM0 + QDRANT (LGPD-isolado)
log ""
log "[7/8] Verificando mem0 + Qdrant..."
if curl -s -m 3 http://localhost:8765/health >/dev/null 2>&1; then
    log "  [OK] mem0-server rodando em :8765"
    log "  Collection sugerida: openclaw-neemias (LGPD-isolado)"
else
    log "  [WARN] mem0-server NAO rodando"
fi

# 8. HOSPITAL AUTO-CURA
log ""
log "[8/8] Rodando Hospital (auto-cura)..."
if [ -f "$WORKSPACE/scripts/hospital-harmonize.sh" ]; then
    bash "$WORKSPACE/scripts/hospital-harmonize.sh" 2>&1 | tee -a "$LOG" | tail -10
fi

log ""
log "============================================"
log "SETUP NEEMIAS COMPLETO"
log "============================================"
log ""
log "DIFERENCAS VS OMNIQI (NAO CONFUNDIR):"
log "  - Neemias: ambiente Anderson, FTMO, BETA"
log "  - OmniQI: ambiente Pablo, OmniQI, Windows local"
log ""
log "PROXIMOS PASSOS:"
log "1. Anderson adiciona pubkey SSH:"
log "   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGuaaHm8EYOoqRB5srEDUmUsyeEpqJRfhjIZWo17algj abraao-local@fabrica-sec"
log "   Destino: C:\\Users\\Beta\\.ssh\\authorized_keys"
log ""
log "2. Configurar Task Scheduler (Windows):"
log "   schtasks /Create /TN NeemiasHospital /TR NeemiasHospital.bat /SC DAILY /ST 09:00"
log "   schtasks /Create /TN NeemiasAutoUpdate /TR NeemiasAutoUpdate.bat /SC WEEKLY /D MON /ST 09:00"
log ""
log "3. Validar SQX + MCP:"
log "   curl http://localhost:8765/health  # se MCP local"
log ""
log "4. Continuar mineracao de estrategias:"
log "   - F1-F9: ja finalizadas (Anderson APROVOU 2026-08-06)"
log "   - Proximas: F11? (Pablo vetou em 2026-08-06)"
log "   - Outras: reversao pura, mean-reversion, momentum, etc"
log ""
log "5. memory-smart-add (dedup + versioning):"
log "   python $WORKSPACE/scripts/memory-smart-add.py --rule --title '...' --content '...'"
log ""
log "Log: $LOG"
log "============================================"