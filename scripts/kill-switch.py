#!/usr/bin/env python3
"""kill-switch.py — Guarda FinOps: corta um agente que estoura custo ou taxa.

- check_cost(agent, limit_usd): custo do DIA (via finops-aggregator) > limit -> disable + alerta.
- disable_agent(agent) / enable_agent(agent): liga/desliga em agent_status (state.db).
- rate_limit(agent, max_calls_per_hour): conta agent_traces da ultima hora; se estoura -> disable + alerta.

CLI:
    python kill-switch.py check_cost <agent> <limit_usd>
    python kill-switch.py disable <agent>
    python kill-switch.py enable <agent>
    python kill-switch.py rate_limit <agent> <max_calls_per_hour>
    python kill-switch.py status [agent]
"""
import sqlite3
import os
import sys
import json
import importlib.util
from pathlib import Path
from datetime import datetime, timedelta

# Detecta HERMES_HOME (mesmo fallback do finops-aggregator / watchdog)
if os.environ.get('HERMES_HOME') and Path(os.environ['HERMES_HOME'], 'state.db').exists():
    HERMES_HOME = Path(os.environ['HERMES_HOME'])
elif os.name == 'nt' and Path(os.environ.get('LOCALAPPDATA', ''), 'hermes', 'state.db').exists():
    HERMES_HOME = Path(os.environ['LOCALAPPDATA'], 'hermes')
elif Path.home().joinpath('.hermes', 'state.db').exists():
    HERMES_HOME = Path.home() / '.hermes'
else:
    HERMES_HOME = Path(os.environ.get('LOCALAPPDATA', str(Path.home()))) / 'hermes'
    HERMES_HOME.mkdir(parents=True, exist_ok=True)

STATE_DB = HERMES_HOME / 'state.db'
SCRIPT_DIR = Path(__file__).resolve().parent


def _load_finops():
    """Importa finops-aggregator.py (nome com hifen -> importlib)."""
    path = SCRIPT_DIR / 'finops-aggregator.py'
    if not path.exists():
        return None
    spec = importlib.util.spec_from_file_location('finops_aggregator', str(path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _conn():
    conn = sqlite3.connect(str(STATE_DB))
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = _conn()
    conn.execute('''
        CREATE TABLE IF NOT EXISTS agent_status (
            agent TEXT PRIMARY KEY,
            status TEXT DEFAULT 'enabled',
            reason TEXT,
            updated_at TEXT
        )
    ''')
    conn.commit()
    conn.close()


def _alert(msg):
    """Log + alerta. Escreve em kill-switch.log ao lado do state.db."""
    line = f"[{datetime.now().isoformat()}] {msg}"
    print(f"[ALERTA] {msg}")
    try:
        with open(HERMES_HOME / 'kill-switch.log', 'a', encoding='utf-8') as f:
            f.write(line + '\n')
    except OSError:
        pass


def disable_agent(agent, reason='kill-switch'):
    """Marca agente como disabled em agent_status."""
    init_db()
    conn = _conn()
    conn.execute('''
        INSERT INTO agent_status (agent, status, reason, updated_at)
        VALUES (?, 'disabled', ?, ?)
        ON CONFLICT(agent) DO UPDATE SET status='disabled', reason=excluded.reason, updated_at=excluded.updated_at
    ''', (agent, reason, datetime.now().isoformat()))
    conn.commit()
    conn.close()
    _alert(f"AGENTE DESABILITADO: {agent} — {reason}")
    return True


def enable_agent(agent):
    """Reabilita agente em agent_status."""
    init_db()
    conn = _conn()
    conn.execute('''
        INSERT INTO agent_status (agent, status, reason, updated_at)
        VALUES (?, 'enabled', 'manual enable', ?)
        ON CONFLICT(agent) DO UPDATE SET status='enabled', reason='manual enable', updated_at=excluded.updated_at
    ''', (agent, datetime.now().isoformat()))
    conn.commit()
    conn.close()
    print(f"OK enable: {agent} reabilitado")
    return True


def is_disabled(agent):
    init_db()
    conn = _conn()
    row = conn.execute('SELECT status FROM agent_status WHERE agent = ?', (agent,)).fetchone()
    conn.close()
    return bool(row) and row['status'] == 'disabled'


def check_cost(agent, limit_usd):
    """Se custo do DIA de hoje > limit_usd, desabilita o agente."""
    limit_usd = float(limit_usd)
    finops = _load_finops()
    if finops is None:
        _alert("finops-aggregator.py nao encontrado — check_cost abortado")
        return None

    # aggregate(days=1) traz linhas com 'date' (YYYY-MM-DD) e 'cost'
    rows = finops.aggregate(finops.STATE_DB, agent_filter=agent, days=1)
    today = datetime.now().strftime('%Y-%m-%d')
    cost_today = sum((r.get('cost') or 0) for r in rows if r.get('date') == today)

    over = cost_today > limit_usd
    print(f"check_cost: {agent} custo_hoje=${cost_today:.4f} limite=${limit_usd:.2f} -> {'ESTOUROU' if over else 'ok'}")
    if over:
        disable_agent(agent, reason=f"custo ${cost_today:.4f} > limite ${limit_usd:.2f} em {today}")
    return {'agent': agent, 'cost_today': cost_today, 'limit': limit_usd, 'over': over}


def rate_limit(agent, max_calls_per_hour):
    """Conta agent_traces do agente na ultima hora; se > max, desabilita."""
    max_calls = int(max_calls_per_hour)
    init_db()
    conn = _conn()
    # agent_traces.timestamp e TEXT (CURRENT_TIMESTAMP, UTC 'YYYY-MM-DD HH:MM:SS')
    since = (datetime.utcnow() - timedelta(hours=1)).strftime('%Y-%m-%d %H:%M:%S')
    try:
        row = conn.execute('''
            SELECT COUNT(*) AS n FROM agent_traces
            WHERE agent = ? AND timestamp >= ?
        ''', (agent, since)).fetchone()
        calls = row['n'] if row else 0
    except sqlite3.OperationalError:
        # tabela agent_traces ainda nao existe
        calls = 0
    conn.close()

    over = calls > max_calls
    print(f"rate_limit: {agent} calls_ultima_hora={calls} max={max_calls} -> {'ESTOUROU' if over else 'ok'}")
    if over:
        disable_agent(agent, reason=f"rate limit {calls} calls/h > max {max_calls}")
    return {'agent': agent, 'calls': calls, 'max': max_calls, 'over': over}


def show_status(agent=None):
    init_db()
    conn = _conn()
    if agent:
        rows = conn.execute('SELECT * FROM agent_status WHERE agent = ?', (agent,)).fetchall()
    else:
        rows = conn.execute('SELECT * FROM agent_status ORDER BY agent').fetchall()
    conn.close()
    if not rows:
        print("Nenhum status registrado (todos enabled por padrao).")
        return
    print(f"{'Agente':<15} {'Status':<10} {'Atualizado':<26} Motivo")
    print('-' * 80)
    for r in rows:
        print(f"{r['agent']:<15} {r['status']:<10} {(r['updated_at'] or ''):<26} {r['reason'] or ''}")


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return

    cmd = args[0]
    if cmd == 'check_cost':
        if len(args) < 3:
            print("Uso: kill-switch.py check_cost <agent> <limit_usd>")
            sys.exit(1)
        check_cost(args[1], args[2])
    elif cmd == 'disable':
        if len(args) < 2:
            print("Uso: kill-switch.py disable <agent>")
            sys.exit(1)
        reason = ' '.join(args[2:]) if len(args) > 2 else 'manual disable'
        disable_agent(args[1], reason=reason)
    elif cmd == 'enable':
        if len(args) < 2:
            print("Uso: kill-switch.py enable <agent>")
            sys.exit(1)
        enable_agent(args[1])
    elif cmd == 'rate_limit':
        if len(args) < 3:
            print("Uso: kill-switch.py rate_limit <agent> <max_calls_per_hour>")
            sys.exit(1)
        rate_limit(args[1], args[2])
    elif cmd == 'status':
        show_status(args[1] if len(args) > 1 else None)
    elif cmd in ('-h', '--help'):
        print(__doc__)
    else:
        print(f"Comando desconhecido: {cmd}")
        print("Use: check_cost | disable | enable | rate_limit | status")
        sys.exit(1)


if __name__ == '__main__':
    main()
