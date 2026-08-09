#!/bin/bash
# neemias-vital-resources.sh
# Instala recursos vitais OPEN-SOURCE no agente Neemias (SQX / operador Anderson).
#
# Neemias e um agente EXTERNO (lab do Anderson). NAO recebe nada interno da Fabrica:
#   - nunca copia skills internas (anti-amnesia, agent-self-improvement,
#     boundary-external-agent, pre-create-check, fabrica-doctor-orchestrator, ...)
#   - nunca copia hooks internos, MEMORY da Fabrica, nem brain_v2.db
#   - MEMORY.md vai VAZIO; SOUL.md e generico (sem dados/topologia da Fabrica)
#
# O que este script instala (tudo open-source):
#   1. Diretorios: workspace/{scripts,backups,logs}
#   2. SOUL.md generico (identidade SQX/Anderson, sem dados da Fabrica)
#   3. MEMORY.md vazio
#   4. state.db com WAL + schema limpo (agent_evals, agent_traces, self_learn_lessons)
#   5. 4 scripts open-source: watchdog.sh, backup-vitals.sh, finops-aggregator.py, boundary-guard.py
#   6. checkpoints: ativados no config.yaml (com backup)
#
# Acesso via SSH (Windows Server remoto). Nunca sobrescreve arquivo pre-existente.

set -euo pipefail

# ============================================================
# CONFIG
# ============================================================
SSH="ssh -o IdentitiesOnly=yes -i $HOME/.ssh/id_ed25519_sec beta@100.103.213.58"
PY="python"                      # Python do Windows (nao python3)
BASE="C:/Users/Beta/.hermes"     # HERMES_HOME do Neemias (barras / funcionam no Windows)
SRC_SCRIPTS="$HOME/AppData/Local/hermes/workspace/scripts"  # origem dos 4 scripts open-source
LOG_PREFIX="[neemias-vitals]"
LOGFILE_LOCAL="$(mktemp)"

# Whitelist dos unicos scripts que podem ser copiados (open-source).
OSS_SCRIPTS=(watchdog.sh backup-vitals.sh finops-aggregator.py boundary-guard.py)

log() {
    local msg="$LOG_PREFIX $1"
    echo "$msg"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" >> "$LOGFILE_LOCAL"
}

# ---- helpers (programa via stdin p/ 'python -', imune ao quoting do shell remoto) ----

remote_mkdir() {   # $1 = path
    $SSH "$PY -" << PYEOF
import os
os.makedirs(r"$1", exist_ok=True)
PYEOF
}

remote_exists() {  # $1 = path ; exit 0 se existe, 1 se nao
    $SSH "$PY -" << PYEOF
import os, sys
sys.exit(0 if os.path.exists(r"$1") else 1)
PYEOF
}

write_remote_file() {   # $1 = target ; conteudo via stdin (base64 evita qualquer quoting)
    local b64
    b64="$(base64 -w0)"
    $SSH "$PY -" << PYEOF
import base64, os
target = r"$1"
os.makedirs(os.path.dirname(target), exist_ok=True)
open(target, "wb").write(base64.b64decode("$b64"))
PYEOF
}

# ============================================================
# FASE 0 — PREFLIGHT + DIRETORIOS
# ============================================================
log "FASE 0: Preflight + diretorios..."

# Sanity: o SSH responde?
if ! $SSH "$PY -c \"print('ok')\"" >/dev/null 2>&1; then
    log "  ERRO: SSH/python remoto indisponivel. Abortando."
    exit 1
fi
log "  SSH + python remoto OK"

# So os 3 diretorios de workspace. Sem skills/, sem hooks/ (nenhum interno vai pro Neemias).
for d in \
    "$BASE/workspace/scripts" \
    "$BASE/workspace/backups" \
    "$BASE/workspace/logs" ; do
    remote_mkdir "$d"
    log "  dir OK: $d"
done

# ============================================================
# FASE 1 — IDENTIDADE (SOUL.md generico + MEMORY.md VAZIO)
# ============================================================
log "FASE 1: Identidade (SOUL generico + MEMORY vazio)..."

# 1a. MEMORY.md VAZIO (sem nada da Fabrica). So um cabecalho neutro.
if remote_exists "$BASE/MEMORY.md"; then
    log "  MEMORY.md ja existe (skip)"
else
    write_remote_file "$BASE/MEMORY.md" << 'MEMEOF'
# MEMORY.md

<!-- Memoria local do agente. Comeca vazia; sera preenchida pelo proprio uso. -->
MEMEOF
    log "  MEMORY.md criado (vazio)"
fi

# 1b. SOUL.md generico — identidade SQX/Anderson, SEM dados/topologia da Fabrica.
if remote_exists "$BASE/SOUL.md"; then
    log "  SOUL.md ja existe (skip)"
else
    write_remote_file "$BASE/SOUL.md" << 'SOULEOF'
# SOUL.md — Neemias

## Quem sou
Sou o **Neemias**, agente de apoio ao pipeline **StrategyQuant X (SQX)** do
operador **Anderson**: backtests, otimizacoes, validacao BT-vs-Live e gestao de
portfolio.

## Missao
- Manter as estrategias SQX confiaveis: nada de recomendar so por backtest.
- Validar sempre com dados live antes de qualquer recomendacao (anti-overfit).
- Crescer sem regredir: cada entrega verificada por evidencia.

## Principios
- Nao decido sozinho acao irreversivel (deploy de EA, alterar portfolio/live):
  Anderson aprova.
- Nunca imprimir segredo/credencial.
- Trabalho local e auditavel; registro o que faco.

## Escala de acoes
- NUNCA rodar backtest em massa sem pedido.
- NUNCA alterar portfolio/live sem approval.
- NUNCA deletar state.db sem backup recente.
SOULEOF
    log "  SOUL.md criado (generico)"
fi

# ============================================================
# FASE 2 — state.db (WAL + 3 tabelas, schema limpo)
# ============================================================
log "FASE 2: state.db (WAL + agent_evals/agent_traces/self_learn_lessons)..."

$SSH "$PY -" << 'PYEOF'
import sqlite3
conn = sqlite3.connect(r"C:/Users/Beta/.hermes/state.db")
conn.execute("PRAGMA journal_mode=WAL")

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
mode = conn.execute("PRAGMA journal_mode").fetchone()[0]
conn.close()
print("state.db OK (journal_mode=%s)" % mode)
PYEOF
log "  state.db: WAL + 3 tabelas OK"

# ============================================================
# FASE 3 — SCRIPTS OPEN-SOURCE (SO os 4 da whitelist)
# ============================================================
log "FASE 3: Scripts open-source (whitelist de 4)..."

for s in "${OSS_SCRIPTS[@]}"; do
    src="$SRC_SCRIPTS/$s"
    dst="$BASE/workspace/scripts/$s"
    if [ ! -f "$src" ]; then
        log "  ERRO: fonte open-source ausente: $src (skip)"
        continue
    fi
    if remote_exists "$dst"; then
        log "  $s ja existe no Neemias (skip)"
        continue
    fi
    write_remote_file "$dst" < "$src"
    log "  $s copiado (open-source)"
done

# ============================================================
# FASE 4 — ATIVAR CHECKPOINTS no config.yaml (com backup)
# ============================================================
log "FASE 4: Ativar checkpoints no config.yaml..."

TS="$(date '+%Y%m%d-%H%M%S')"
$SSH "$PY -" << PYEOF
import os, shutil
base = r"C:/Users/Beta/.hermes"
cfg  = os.path.join(base, "config.yaml")
bak  = os.path.join(base, "workspace", "backups", "config.yaml.$TS")
if not os.path.exists(cfg):
    print("config.yaml NAO encontrado (skip)")
else:
    shutil.copy(cfg, bak)
    txt = open(cfg, encoding="utf-8").read()
    if "checkpoints:" in txt:
        print("checkpoints ja presente no config.yaml (skip) — backup em %s" % bak)
    else:
        if not txt.endswith("\n"):
            txt += "\n"
        txt += "\ncheckpoints:\n  enabled: true\n  interval_tasks: 5\n  keep_last: 10\n"
        open(cfg, "w", encoding="utf-8").write(txt)
        print("checkpoints ativado no config.yaml (backup: %s)" % bak)
PYEOF
log "  config.yaml processado (backup em workspace/backups/config.yaml.$TS)"

# ============================================================
# FASE 5 — RELATORIO + UPLOAD DO LOG
# ============================================================
log "FASE 5: Relatorio..."

echo ""
echo "==============================================="
echo "  NEEMIAS VITAL RESOURCES — DIAGNOSTICO POS"
echo "==============================================="
echo ""

$SSH "$PY -" << 'PYEOF'
import os, sqlite3
BASE = r"C:/Users/Beta/.hermes"
def ok(p): return "OK" if os.path.exists(os.path.join(BASE, p)) else "FALTA"

print("IDENTIDADE:")
for f in ["SOUL.md", "MEMORY.md"]:
    print("  %-12s %s" % (f + ":", ok(f)))

print("\nDIRETORIOS:")
for d in ["workspace/scripts", "workspace/backups", "workspace/logs"]:
    print("  %-22s %s" % (d + ":", ok(d)))

print("\nSCRIPTS OPEN-SOURCE:")
for s in ["watchdog.sh", "backup-vitals.sh", "finops-aggregator.py", "boundary-guard.py"]:
    print("  %-26s %s" % (s + ":", ok("workspace/scripts/%s" % s)))

print("\nSTATE.DB:")
sp = os.path.join(BASE, "state.db")
print("  state.db:", os.path.getsize(sp) if os.path.exists(sp) else "FALTA", "bytes")
try:
    conn = sqlite3.connect(sp)
    for t in ["agent_evals", "agent_traces", "self_learn_lessons"]:
        try:
            c = conn.execute("SELECT COUNT(*) FROM %s" % t).fetchone()[0]
            print("  %-22s %s rows" % (t + ":", c))
        except Exception:
            print("  %-22s NAO existe" % (t + ":"))
    print("  journal_mode:", conn.execute("PRAGMA journal_mode").fetchone()[0])
    conn.close()
except Exception as e:
    print("  erro:", e)

print("\nCONFIG:")
cfg = os.path.join(BASE, "config.yaml")
if os.path.exists(cfg):
    has = "checkpoints:" in open(cfg, encoding="utf-8").read()
    print("  config.yaml checkpoints:", "ATIVO" if has else "AUSENTE")
else:
    print("  config.yaml: FALTA")
PYEOF

log "PRONTO. Neemias com recursos vitais open-source (sem nada interno da Fabrica)."

# Upload do log completo (append) para workspace/logs/neemias-bootstrap.log
LOG_B64="$(base64 -w0 < "$LOGFILE_LOCAL")"
$SSH "$PY -" << PYEOF
import base64, os
target = r"C:/Users/Beta/.hermes/workspace/logs/neemias-bootstrap.log"
os.makedirs(os.path.dirname(target), exist_ok=True)
with open(target, "ab") as f:
    f.write(base64.b64decode("$LOG_B64"))
    f.write(b"\n")
print("log gravado em", target)
PYEOF

rm -f "$LOGFILE_LOCAL"
echo ""
echo "$LOG_PREFIX Log completo em: $BASE/workspace/logs/neemias-bootstrap.log"
