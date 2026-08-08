#!/bin/bash
# setup-neemias.sh — Setup do Neemias (trader do Anderson Medeiros, ambiente BETA)
#
# BOUNDARY CRÍTICO (regra L043 + 10.7 anti-fragmentação):
# - Neemias = EXTERNO (não tem acesso à nossa mem0/Qdrant)
# - NÃO baixa MEMORY.md/USER.md/SOUL.md/AGENTS.md (são particulares nossos)
# - NÃO baixa nada que tenha 'Pablo'/'pablodornellas' como owner
# - NÃO baixa scripts que dependam de QDRANT_API_KEY ou OPENROUTER_API_KEY
# - Coleção LGPD-isolada DELE: openclaw-neemias (NÃO openclaw-factory)
#
# Identidade:
# - Owner: Anderson Medeiros (cliente)
# - Ambiente: BETA Windows Server (100.103.213.58)
# - SQX: 1.44 Full em C:\Users\Beta\Desktop\SQX_144_Full\
# - MCP: :8765 read-only (11 tools)
# - Projeto: APROVA FTMO SWING (9 familias F1-F9 XAUUSD)
#
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main/scripts/setup-neemias.sh)

set -e

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
WORKSPACE="$HERMES_HOME/workspace"
LOG="$WORKSPACE/logs/setup-neemias.log"
HERMES_REPO="https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main"

mkdir -p "$WORKSPACE/logs"

log() {
    echo "[$(date -Iseconds)] $@" | tee -a "$LOG"
}

log "============================================"
log "SETUP NEEMIAS — Hermes-Agent (Anderson)"
log "BOUNDARY: NAO acessa mem0/Qdrant do Pablo"
log "HERMES_HOME: $HERMES_HOME"
log "============================================"
log ""

# 0. Identidade (NAO confundir com OmniQI/Abraao)
log "[0/8] Identidade:"
log "  Agente: NEEMIAS (EXTERNO - ambiente Anderson)"
log "  Owner: Anderson Medeiros"
log "  Ambiente: BETA Windows Server (100.103.213.58)"
log "  Projeto: APROVA FTMO SWING (9 familias)"
log "  SQX: 1.44 Full"
log ""
log "  ⚠️ BOUNDARY: Neemias usa SO mem0/Qdrant PROPRIO dele"
log "     - Colecao: openclaw-neemias (LGPD-isolado)"
log "     - NAO compartilha com openclaw-factory (Pablo)"
log "     - NAO baixa MEMORY.md/USER.md/SOUL.md/AGENTS.md (particulares)"
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

# 2. SCRIPTS DE MANUTENCAO (open-source, sem secrets)
log ""
log "[2/8] Baixando scripts de manutencao (open-source)..."
mkdir -p "$WORKSPACE/scripts"
# Apenas scripts SEM credenciais embutidas
for script in hospital-diagnose.sh hospital-harmonize.sh harmonize_memory.py memory-purify.py memory-smart-add.py state-db-vacuum.py session-snapshot.py; do
    if curl -fsSL "$HERMES_REPO/scripts/$script" -o "$WORKSPACE/scripts/$script" 2>/dev/null; then
        chmod +x "$WORKSPACE/scripts/$script" 2>/dev/null
        log "  [OK] $script"
    else
        log "  [FAIL] $script"
    fi
done

log ""
log "  ⚠️ NAO baixa: auto-update.py, hospital_run.py (usam secrets nossos)"

# 3. SKILLS ESPECÍFICAS (FTMO/SQX/MT5 — sem credenciais)
log ""
log "[3/8] Baixando skills especificas (FTMO/SQX/MT5)..."
for skill in ftmo-builder-pipeline sqx-backtest-runner mt5-broker-connection pine-script-generator anti-amnesia dedupe pre-create-check kanban-checkpoint; do
    mkdir -p "$HERMES_HOME/skills/$skill"
    if curl -fsSL "$HERMES_REPO/skills/$skill/SKILL.md" -o "$HERMES_HOME/skills/$skill/SKILL.md" 2>/dev/null; then
        log "  [OK] skill/$skill"
    else
        log "  [FAIL] skill/$skill"
    fi
done

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

# 5. MEMORY.md ESPECÍFICO (NAO baixa do nosso!)
log ""
log "[5/8] Criando MEMORY.md ESPECIFICO do Neemias (Anderson-isolado)..."
mkdir -p "$HERMES_HOME/workspace/neemias"
cat > "$HERMES_HOME/workspace/neemias/MEMORY.md" << 'EOF'
# MEMORY.md — Neemias (Hermes-Agent Trader do Anderson)

## Identidade
- **Agente:** Neemias
- **Owner:** Anderson Medeiros (cliente)
- **Ambiente:** BETA Windows Server (100.103.213.58)
- **SQX:** 1.44 Full em C:\Users\Beta\Desktop\SQX_144_Full\
- **MCP:** :8765 read-only (11 tools)
- **Projeto atual:** APROVA FTMO SWING (9 familias F1-F9 XAUUSD)

## BOUNDARY (importante)
- Neemias NÃO acessa mem0/Qdrant do Pablo (openclaw-factory)
- Colecao ISOLADA: openclaw-neemias
- Hospital link é open-source (pode usar)
- MAS: AGENTS.md/MEMORY.md/USER.md/SOUL.md do Pablo NAO baixa
- Scripts com secrets (auto-update.py, hospital_run.py) NAO baixa

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
log "  [OK] MEMORY.md criado (Anderson-isolado, NAO baixa do nosso)"

# 6. AUTO-UPDATE (LOCAL apenas, nao compartilha com nosso Hospital)
log ""
log "[6/8] Configurando auto-update LOCAL (nao compartilha com nosso Hospital)..."
cat > "$WORKSPACE/scripts/NeemiasAutoUpdate.bat" << 'BEOF'
@echo off
REM NeemiasAutoUpdate - weekly Seg 09:00
REM ATUALIZA SO SCRIPTS/SKILLS OPEN-SOURCE (nao baixa nossos arquivos)
cd /d "C:\Users\Beta\hermes-agent\workspace"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main/scripts/harmonize_memory.py' -OutFile 'C:\Users\Beta\hermes-agent\workspace\scripts\harmonize_memory.py'"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/pablodornellas-ux/hermes-hospital-link/main/scripts/memory-purify.py' -OutFile 'C:\Users\Beta\hermes-agent\workspace\scripts\memory-purify.py'"
BEOF
log "  [OK] NeemiasAutoUpdate.bat criado (so baixa scripts open-source, NAO MEMORY/USER/SOUL)"

# 7. MEM0/QDRANT (LOCAL dele, NAO o nosso!)
log ""
log "[7/8] ⚠️ BOUNDARY MEM0/QDRANT:"
log "  Neemias precisa ter PROPRIO mem0-server local"
log "  Se ainda nao tem, instalar separado:"
log "  - pip install mem0ai"
log "  - Setup proprio: collection=openclaw-neemias"
log "  - Qdrant proprio ou local file storage"
log ""
log "  NAO PODE usar nosso QDRANT_API_KEY (Pablo)"
log "  NAO PODE usar nosso MEM0_URL (localhost:8765 = Pablo)"
log ""
if curl -s -m 3 http://localhost:8765/health >/dev/null 2>&1; then
    log "  [WARN] localhost:8765 detectado (= Pablo). Neemias precisa de PORTA DIFERENTE."
fi

# 8. HOSPITAL AUTO-CURA (open-source, NAO usa secrets)
log ""
log "[8/8] Rodando Hospital (open-source, NAO usa secrets)..."
if [ -f "$WORKSPACE/scripts/hospital-harmonize.sh" ]; then
    bash "$WORKSPACE/scripts/hospital-harmonize.sh" 2>&1 | tee -a "$LOG" | tail -10
fi

log ""
log "============================================"
log "SETUP NEEMIAS COMPLETO (com BOUNDARY correto)"
log "============================================"
log ""
log "BOUNDARY (regra L043):"
log "  ✅ Colecao: openclaw-neemias (LGPD-isolado)"
log "  ✅ NAO baixa MEMORY.md/USER.md/SOUL.md/AGENTS.md nossos"
log "  ✅ NAO usa nosso QDRANT_API_KEY/MEM0_URL"
log "  ✅ NAO baixa scripts com secrets (auto-update.py, hospital_run.py)"
log ""
log "PROXIMOS PASSOS:"
log "1. Anderson instala mem0-server PROPRIO dele (porta diferente)"
log "2. Configurar Qdrant local (ou cloud Anderson)"
log "3. schtasks /Create /TN NeemiasHospital /TR NeemiasHospital.bat /SC DAILY /ST 09:00"
log "4. schtasks /Create /TN NeemiasAutoUpdate /TR NeemiasAutoUpdate.bat /SC WEEKLY /D MON /ST 09:00"
log "5. Validar SQX + MCP:"
log "   curl http://localhost:8765/health  # MCP do BETA"
log ""
log "6. Continuar mineracao de estrategias (Anderson decide):"
log "   - F1-F9: ja finalizadas (Anderson APROVOU 2026-08-06)"
log "   - Proximas: F11? (Pablo vetou em 2026-08-06, Anderson decide)"
log "   - Outras: reversao pura, mean-reversion, momentum, etc"
log ""
log "Log: $LOG"
log "============================================"