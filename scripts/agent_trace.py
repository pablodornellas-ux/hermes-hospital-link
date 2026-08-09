#!/usr/bin/env python3
"""agent_trace.py — Tracing de tool calls em state.db.
Baseado em AgentOps pattern (session replay) + Judgeval (OpenTelemetry).
Zero custo, local, sem API externa.

Features:
  - Decorator @trace_tool para instrumentar functions
  - Salva cada call (tool, args, duration, result_size) em state.db
  - Stats: top tools, avg duration, total calls
  - Replay: re-roda traces de uma sessao

Uso:
    # Como modulo
    from agent_trace import trace_tool
    
    @trace_tool('brain-lookup')
    def brain_lookup(query): ...

    # CLI (stats)
    python agent_trace.py --stats
    python agent_trace.py --top 10
    python agent_trace.py --slow 10
"""
import sqlite3
import os
import sys
import json
import time
import functools
from pathlib import Path
from datetime import datetime, timedelta

HERMES_HOME = Path(os.environ.get('HERMES_HOME', os.path.expanduser('~/.hermes')))
STATE_DB = HERMES_HOME / 'state.db'


def init_db():
    """Cria tabela agent_traces se nao existir."""
    conn = sqlite3.connect(str(STATE_DB))
    conn.execute('''
        CREATE TABLE IF NOT EXISTS agent_traces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            session_id TEXT,
            agent TEXT DEFAULT 'abraao',
            tool TEXT,
            args TEXT,
            duration_ms INTEGER,
            result_size INTEGER,
            success INTEGER DEFAULT 1,
            error TEXT
        )
    ''')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_traces_tool ON agent_traces(tool)')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_traces_session ON agent_traces(session_id)')
    conn.commit()
    conn.close()


def trace_tool(tool_name: str, agent: str = None):
    """Decorator: traceia functions (tool calls).
    
    Args:
        tool_name: nome da tool (ex: 'brain-lookup', 'mem0-search')
        agent: nome do agente (default: HERMES_AGENT env ou 'abraao')
    """
    def decorator(fn):
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            agent_name = agent or os.environ.get('HERMES_AGENT', 'abraao')
            session_id = os.environ.get('HERMES_SESSION_ID', 'unknown')
            start = time.time()
            success = 1
            error_msg = None

            try:
                result = fn(*args, **kwargs)
                return result
            except Exception as e:
                success = 0
                error_msg = str(e)[:500]
                raise
            finally:
                duration = time.time() - start
                save_trace(
                    tool_name=tool_name,
                    agent=agent_name,
                    session_id=session_id,
                    args_str=str(args)[:500] if args else '',
                    duration_ms=int(duration * 1000),
                    result_size=len(str(result)) if 'result' in locals() and result else 0,
                    success=success,
                    error=error_msg
                )
        return wrapper
    return decorator


def save_trace(tool_name, agent, session_id, args_str, duration_ms, result_size, success=1, error=None):
    """Salva trace em state.db."""
    init_db()
    conn = sqlite3.connect(str(STATE_DB))
    conn.execute('''
        INSERT INTO agent_traces (session_id, agent, tool, args, duration_ms, result_size, success, error)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', (session_id, agent, tool_name, args_str, duration_ms, result_size, success, error))
    conn.commit()
    conn.close()


def stats_top(limit=10):
    """Top tools por frequencia."""
    init_db()
    if not STATE_DB.exists():
        print('state.db nao encontrado')
        return

    conn = sqlite3.connect(str(STATE_DB))
    try:
        rows = conn.execute('''
            SELECT tool, COUNT(*) as calls, AVG(duration_ms) as avg_ms,
                   SUM(duration_ms) as total_ms,
                   SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) as failures
            FROM agent_traces
            GROUP BY tool
            ORDER BY calls DESC
            LIMIT ?
        ''', (limit,)).fetchall()

        if not rows:
            print('Nenhum trace registrado ainda.')
            return

        print('=== TOP TOOLS ===')
        print(f'{"Tool":30s} {"Calls":>6s} {"Avg ms":>8s} {"Total":>10s} {"Fails":>6s}')
        print('-' * 65)
        for tool, calls, avg_ms, total_ms, failures in rows:
            print(f'{tool:30s} {calls:6d} {avg_ms:8.0f} {total_ms:10d} {failures:6d}')
    finally:
        conn.close()


def stats_slow(limit=10):
    """Tools mais lentos (avg duration)."""
    init_db()
    if not STATE_DB.exists():
        print('state.db nao encontrado')
        return

    conn = sqlite3.connect(str(STATE_DB))
    try:
        rows = conn.execute('''
            SELECT tool, COUNT(*) as calls, AVG(duration_ms) as avg_ms,
                   MAX(duration_ms) as max_ms
            FROM agent_traces
            GROUP BY tool
            ORDER BY avg_ms DESC
            LIMIT ?
        ''', (limit,)).fetchall()

        if not rows:
            print('Nenhum trace registrado ainda.')
            return

        print('=== SLOWEST TOOLS ===')
        print(f'{"Tool":30s} {"Calls":>6s} {"Avg ms":>8s} {"Max ms":>8s}')
        print('-' * 55)
        for tool, calls, avg_ms, max_ms in rows:
            print(f'{tool:30s} {calls:6d} {avg_ms:8.0f} {max_ms:8d}')
    finally:
        conn.close()


def stats_session(session_id: str):
    """Mostra todos os traces de uma sessao."""
    init_db()
    if not STATE_DB.exists():
        print('state.db nao encontrado')
        return

    conn = sqlite3.connect(str(STATE_DB))
    try:
        rows = conn.execute('''
            SELECT timestamp, tool, duration_ms, result_size, success, error
            FROM agent_traces
            WHERE session_id = ?
            ORDER BY id
        ''', (session_id,)).fetchall()

        if not rows:
            print(f'Sem traces pra sessao {session_id}')
            return

        print(f'=== SESSION {session_id} ({len(rows)} tool calls) ===')
        total_ms = 0
        for i, (ts, tool, dur, size, succ, err) in enumerate(rows, 1):
            total_ms += dur
            status = 'OK' if succ else f'ERR: {err}'
            print(f'  {i:3d}. [{tool:25s}] {dur:5d}ms  {size:6d}B  {status}')
        print(f'\n  Total: {total_ms}ms ({total_ms/1000:.1f}s)')
    finally:
        conn.close()


def stats_failures(limit=10):
    """Mostra falhas recentes."""
    init_db()
    if not STATE_DB.exists():
        print('state.db nao encontrado')
        return

    conn = sqlite3.connect(str(STATE_DB))
    try:
        rows = conn.execute('''
            SELECT timestamp, tool, duration_ms, error
            FROM agent_traces
            WHERE success = 0
            ORDER BY timestamp DESC
            LIMIT ?
        ''', (limit,)).fetchall()

        if not rows:
            print('Nenhuma falha registrada. ✅')
            return

        print('=== RECENT FAILURES ===')
        for ts, tool, dur, err in rows:
            print(f'  [{ts}] {tool:25s} {dur:5d}ms')
            print(f'    ERR: {err}')
    finally:
        conn.close()


def main():
    args = sys.argv[1:]

    if not args or args[0] == '--stats' or args[0] == '--top':
        limit = int(args[1]) if len(args) > 1 and args[1].isdigit() else 10
        stats_top(limit)
        return

    if args[0] == '--slow':
        limit = int(args[1]) if len(args) > 1 and args[1].isdigit() else 10
        stats_slow(limit)
        return

    if args[0] == '--session':
        if len(args) < 2:
            print('Uso: agent_trace.py --session <session_id>')
            sys.exit(1)
        stats_session(args[1])
        return

    if args[0] == '--failures':
        limit = int(args[1]) if len(args) > 1 and args[1].isdigit() else 10
        stats_failures(limit)
        return

    if args[0] in ['-h', '--help']:
        print(__doc__)
        return

    print(f'Argumento desconhecido: {args[0]}')
    print('Use --stats, --top N, --slow N, --session ID, --failures N')
    sys.exit(1)


if __name__ == '__main__':
    main()