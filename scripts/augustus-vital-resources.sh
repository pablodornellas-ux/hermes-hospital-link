#!/bin/bash
# augustus-vital-resources.sh
# Aplica recursos vitais da Fábrica no Augustus (sem sobrescrever o que ele já tem)
# Baseado no diagnóstico Abraão vs Augustus (09-08-2026)

set -euo pipefail

CONTAINER="augustus-hermes-standalone"
REMOTE="/root/.hermes"
LOG_PREFIX="[augustus-vitals]"

log() { echo "$LOG_PREFIX $1"; }

# ============================================================
# FASE 1 — ARQUIVOS DE IDENTIDADE (criar se nao existem)
# ============================================================

log "FASE 1: Arquivos de identidade..."

# 1a. MEMORY.md (camada L1 - so se nao existir)
if ! docker exec $CONTAINER test -f $REMOTE/MEMORY.md; then
    docker exec $CONTAINER bash -c "cat > $REMOTE/MEMORY.md << 'MEMEOF'
# MEMORY.md — Augustus (Guardian/Diretor de Ops)

## Ambiente
- Container: augustus-hermes-standalone:v010-pw
- Volume: augustus-hermes-home
- Plataforma: Hermes-Agent em Docker (WSL Ubuntu)
- state.db: ~882MB

## Memoria estruturada
- mem0-server: NAO rodando local (acessar via API remoto)
- brain_v2.db: instalar em workspace/

## Skills
- 110 SKILL.md (95 arquivadas + 15 ativas)
- Skills ativas: roteador, wargame, session-handoff, memory-audit, session-statusline, delivery-closure, solfortes-ops, etc

## Hooks
- ZERO hooks ativos (instalar)

## Cron
- 23 jobs configurados, ~1 ativo

## Licoes criticas
- L043: boundary externo vs interno (LGPD)
- M-004: parar loop quando ferramenta nao responde
- E-017: loop auditado com Claude Code
- R-03: recuperarMemoria antes de agir
MEMEOF
"
    log "  MEMORY.md criado"
else
    log "  MEMORY.md ja existe (skip)"
fi

# 1b. USER.md (preferencias do operador)
if ! docker exec $CONTAINER test -f $REMOTE/USER.md; then
    docker exec $CONTAINER bash -c "cat > $REMOTE/USER.md << 'USEREOF'
# USER.md — Operador do Augustus

## Usuario primario
- Nome: Matheus (operador Telegram)
- Empresa: Solfortes
- Papel: Diretor operacional, aprova medicamentos tecnicos

## Preferencias de comunicacao
- Resposta concisa (default)
- Bullet points para dados estruturados
- Markdown para Telegram
- Sempre confirmar antes de acoes irreversiveis

## Permissoes (estado 2026-06-16)
- Egress: liberado (allow-all) — decisao do operador
- Gate de approval (007): desligado — decisao do operador
- Install de pacotes: liberado — decisao do operador
- Chromium: baked

## Idiomas
- PT-BR (default)
- EN (tecnico)

## Escala de acoes
- NUNCA derrubar o container sem approval
- NUNCA deletar state.db sem backup <24h
- NUNCA desligar guardas de infra (S03) sozinho
USEREOF
"
    log "  USER.md criado"
else
    log "  USER.md ja existe (skip)"
fi

# ============================================================
# FASE 2 — SCRIPTS DE MEMORIA E SELF-IMPROVEMENT
# ============================================================

log "FASE 2: Scripts de memoria + self-improvement..."

# 2a. Criar workspace/scripts/ se nao existir
docker exec $CONTAINER mkdir -p $REMOTE/workspace/scripts/

# 2b. Funcao helper: copia script via stdin
copy_script() {
    local name=$1
    local local_path=$2
    if docker exec $CONTAINER test -f $REMOTE/workspace/scripts/$name; then
        log "  $name ja existe (skip)"
    else
        docker exec -i $CONTAINER bash -c "cat > $REMOTE/workspace/scripts/$name" < "$local_path"
        docker exec $CONTAINER chmod +x $REMOTE/workspace/scripts/$name
        log "  $name instalado"
    fi
}

# 2c. agent_eval.py (scora output do agente)
# 2d. self_learn.py (diff output vs aprovado → aprende regras)
# 2e. agent_trace.py (tracing de tool calls)
# 2f. memory-smart-add.py (dedup + versionamento)
# 2g. harmonize_memory.py (check L1-L7)
# 2h. memory-purify.py (limpa duplicatas)
# 2i. session-snapshot.py (snapshot fim de sessao)

# NOTE: Estes scripts serao copiados pelo dispatcher Abraão via docker cp

# ============================================================
# FASE 3 — HOOKS (criar estrutura vazia primeiro)
# ============================================================

log "FASE 3: Hooks..."

# 3a. Criar diretorios de hooks
for hook in pre-task post-task session-end pre-create post-update-hygiene; do
    docker exec $CONTAINER mkdir -p $REMOTE/hooks/$hook/
    log "  hooks/$hook/ criado"
done

# NOTE: Os handler.py serao copiados pelo dispatcher via docker cp

# ============================================================
# FASE 4 — SKILLS VITAIS (da Fabrica)
# ============================================================

log "FASE 4: Skills vitais..."

# 4a. anti-amnesia (anti-esquecimento operacional)
# 4b. boundary-external-agent (L043 LGPD)
# 4c. pre-create-check (verifica antes de criar)
# 4d. agent-self-improvement (eval + self-learn + trace)
# 4e. fleet-diagnostics (diagnostico de frota)
# 4f. memory-layer-architecture (L1-L7)
# 4g. kanban-checkpoint (gestao de tasks)
# 4h. claude-code-expert (CLI Claude Code)
# 4i. dedupe (remove duplicatas)

# NOTE: Skills serao copiadas pelo dispatcher via docker cp

# ============================================================
# FASE 5 — brain_v2.db (memoria FTS5)
# ============================================================

log "FASE 5: brain_v2.db..."

if ! docker exec $CONTAINER test -f $REMOTE/workspace/brain_v2.db; then
    # Criar schema vazio
    docker exec $CONTAINER bash -c "python3 -c \"
import sqlite3
conn = sqlite3.connect('/root/.hermes/workspace/brain_v2.db')
conn.execute('''CREATE TABLE IF NOT EXISTS lessons (
    id TEXT PRIMARY KEY,
    timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    agent TEXT,
    title TEXT,
    content TEXT
)''')
conn.execute('CREATE VIRTUAL TABLE IF NOT EXISTS lessons_fts USING fts5(id, title, content)')
conn.commit()
conn.close()
print('brain_v2.db criado')
\""
    log "  brain_v2.db criado"
else
    log "  brain_v2.db ja existe (skip)"
fi

# ============================================================
# FASE 6 — agent_evals + agent_traces (tabelas state.db)
# ============================================================

log "FASE 6: Tabelas de eval + trace em state.db..."

docker exec $CONTAINER bash -c "python3 -c \"
import sqlite3
conn = sqlite3.connect('/root/.hermes/state.db')

# evals
conn.execute('''CREATE TABLE IF NOT EXISTS agent_evals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    agent TEXT,
    output TEXT,
    expected TEXT,
    score INTEGER,
    factual INTEGER,
    completeness INTEGER,
    style INTEGER,
    issues TEXT,
    approved INTEGER,
    metrics TEXT
)''')

# traces
conn.execute('''CREATE TABLE IF NOT EXISTS agent_traces (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT,
    agent TEXT,
    tool TEXT,
    args TEXT,
    duration_ms INTEGER,
    result_size INTEGER,
    success INTEGER DEFAULT 1,
    error TEXT
)''')
conn.execute('CREATE INDEX IF NOT EXISTS idx_traces_tool ON agent_traces(tool)')
conn.execute('CREATE INDEX IF NOT EXISTS idx_traces_session ON agent_traces(session_id)')

# self_learn
conn.execute('''CREATE TABLE IF NOT EXISTS self_learn_lessons (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    agent TEXT,
    type TEXT,
    rule TEXT,
    evidence TEXT,
    confidence REAL
)''')

conn.commit()
conn.close()
print('Tabelas criadas em state.db')
\""
    log "  Tabelas agent_evals + agent_traces + self_learn_lessons criadas"

# ============================================================
# FASE 7 — RELATORIO
# ============================================================

log "FASE 7: Relatorio..."
echo ""
echo "==============================================="
echo "  AUGUSTUS VITAL RESOURCES — DIAGNOSTICO POS"
echo "==============================================="
echo ""

# Contar
docker exec $CONTAINER bash -c "
echo 'IDENTIDADE:'
echo \"  MEMORY.md: \$([ -f /root/.hermes/MEMORY.md ] && echo OK || echo FALTA)\"
echo \"  USER.md: \$([ -f /root/.hermes/USER.md ] && echo OK || echo FALTA)\"
echo \"  SOUL.md: \$([ -f /root/.hermes/SOUL.md ] && echo OK || echo FALTA)\"
echo \"  AGENTS.md: \$([ -f /root/.hermes/AGENTS.md ] && echo OK || echo FALTA)\"
echo ''
echo 'MEMORIA:'
echo \"  brain_v2.db: \$([ -f /root/.hermes/workspace/brain_v2.db ] && echo OK || echo FALTA)\"
echo \"  state.db: \$(ls -la /root/.hermes/state.db 2>/dev/null | awk '{print \$5}') bytes\"
echo ''
echo 'SKILLS:'
echo \"  Total: \$(find /root/.hermes/skills -name SKILL.md 2>/dev/null | wc -l)\"
echo \"  Ativas: \$(find /root/.hermes/skills -name SKILL.md -not -path '*/.archive/*' 2>/dev/null | wc -l)\"
echo ''
echo 'HOOKS:'
echo \"  Diretorios: \$(ls /root/.hermes/hooks/ 2>/dev/null | wc -l)\"
echo \"  Handlers: \$(find /root/.hermes/hooks -name handler.py 2>/dev/null | wc -l)\"
echo ''
echo 'SCRIPTS:'
echo \"  Scripts: \$(ls /root/.hermes/workspace/scripts/*.py 2>/dev/null | wc -l)\"
echo ''
echo 'TASK ARTIFACTS:'
echo \"  TASK_STATE.json: \$([ -f /root/.hermes/TASK_STATE.json ] && echo OK || echo FALTA)\"
echo \"  TASK_BACKLOG.md: \$([ -f /root/.hermes/TASK_BACKLOG.md ] && echo OK || echo FALTA)\"
echo \"  DECISIONS.md: \$([ -f /root/.hermes/DECISIONS.md ] && echo OK || echo FALTA)\"
echo \"  EVIDENCE.md: \$([ -f /root/.hermes/EVIDENCE.md ] && echo OK || echo FALTA)\"
echo \"  LAST_CHECKPOINT.md: \$([ -f /root/.hermes/LAST_CHECKPOINT.md ] && echo OK || echo FALTA)\"
echo ''
echo 'EVAL TRACE TABLES (state.db):'
python3 -c \"
import sqlite3
conn = sqlite3.connect('/root/.hermes/state.db')
for t in ['agent_evals', 'agent_traces', 'self_learn_lessons']:
    try:
        c = conn.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]
        print(f'  {t}: {c} rows')
    except:
        print(f'  {t}: NAO existe')
\"
"

log "PRONTO. Augustus agora tem os recursos vitais da Fabrica."