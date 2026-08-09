#!/usr/bin/env python3
"""
finops-aggregator.py — Agrega custo de tokens por agente/modelo/dia
CLAUDE AUDIT E-017: script read-only. Copia state.db antes de ler.
Uso: python finops-aggregator.py [--agent <name>] [--days 7] [--csv] [--json]
"""

import sqlite3
import argparse
import json
import os
import shutil
import tempfile
from datetime import datetime, timedelta
from collections import defaultdict
from pathlib import Path

# Detecta HERMES_HOME (CLAUDE AUDIT: fallback como watchdog)
if os.environ.get('HERMES_HOME') and Path(os.environ['HERMES_HOME'], 'state.db').exists():
    HERMES_HOME = Path(os.environ['HERMES_HOME'])
elif os.name == 'nt' and Path(os.environ.get('LOCALAPPDATA', ''), 'hermes', 'state.db').exists():
    HERMES_HOME = Path(os.environ['LOCALAPPDATA'], 'hermes')
elif Path.home().joinpath('.hermes', 'state.db').exists():
    HERMES_HOME = Path.home() / '.hermes'
else:
    print("ERRO: state.db nao encontrado")
    exit(2)

STATE_DB = HERMES_HOME / 'state.db'


def aggregate(seconds_db: Path, agent_filter: str = None, days: int = 7) -> list:
    """Agrega custo do state.db. Read-only (copia primeiro)."""
    # Copia para temp (nao trava o DB em producao)
    tmp = Path(tempfile.gettempdir()) / f'finops_{os.getpid()}.db'
    shutil.copy2(seconds_db, tmp)

    conn = sqlite3.connect(str(tmp))
    conn.row_factory = sqlite3.Row

    # Data limite
    since = (datetime.now() - timedelta(days=days)).isoformat()

    # Query: sessions tem estimated_cost_usd, model, billing_provider, started_at
    # CLAUDE AUDIT: profile_name pode ser NULL, started_at e epoch float (nao ISO)
    query = """
        SELECT
            COALESCE(profile_name, 'default') as agent,
            COALESCE(model, 'unknown') as model,
            COALESCE(billing_provider, 'unknown') as provider,
            DATE(datetime(started_at, 'unixepoch')) as date,
            COUNT(*) as sessions,
            SUM(estimated_cost_usd) as cost,
            SUM(input_tokens) as input_tokens,
            SUM(output_tokens) as output_tokens,
            SUM(COALESCE(cache_read_tokens, 0)) as cache_read,
            SUM(COALESCE(cache_write_tokens, 0)) as cache_write,
            SUM(COALESCE(reasoning_tokens, 0)) as reasoning,
            SUM(api_call_count) as api_calls
        FROM sessions
        WHERE started_at >= ?
    """
    # since em epoch float
    import time
    since_epoch = time.time() - (days * 86400)
    params = [since_epoch]
    if agent_filter:
        query += " AND profile_name LIKE ?"
        params.append(f'%{agent_filter}%')

    query += " GROUP BY agent, model, date ORDER BY date DESC, cost DESC"

    rows = conn.execute(query, params).fetchall()
    conn.close()
    os.remove(tmp)

    return [dict(r) for r in rows]


def format_table(data: list) -> str:
    """Formata como tabela ASCII."""
    if not data:
        return "Sem dados no periodo."

    lines = []
    lines.append(f"{'Data':<12} {'Agente':<15} {'Modelo':<25} {'Sessoes':>7} {'Custo USD':>10} {'In/Out tokens':>15}")
    lines.append("-" * 90)

    total_cost = 0
    total_sessions = 0

    for r in data:
        cost = r['cost'] or 0
        tokens = f"{r['input_tokens'] or 0}/{r['output_tokens'] or 0}"
        lines.append(
            f"{r['date'] or '?':<12} "
            f"{r['agent'] or '?':<15} "
            f"{(r['model'] or '?')[:25]:<25} "
            f"{r['sessions'] or 0:>7} "
            f"{cost:>10.4f} "
            f"{tokens:>15}"
        )
        total_cost += cost
        total_sessions += r['sessions'] or 0

    lines.append("-" * 90)
    lines.append(f"{'TOTAL':<12} {'':<15} {'':<25} {total_sessions:>7} {total_cost:>10.4f}")

    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description='FinOps aggregator — custo por agente/modelo/dia')
    parser.add_argument('--agent', help='Filtrar por agente (substring)')
    parser.add_argument('--days', type=int, default=7, help='Quantos dias olhar (default 7)')
    parser.add_argument('--csv', action='store_true', help='Output CSV')
    parser.add_argument('--json', action='store_true', help='Output JSON')
    args = parser.parse_args()

    data = aggregate(STATE_DB, agent_filter=args.agent, days=args.days)

    if args.json:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    elif args.csv:
        if data:
            keys = data[0].keys()
            print(','.join(keys))
            for r in data:
                print(','.join(str(r[k] or '') for k in keys))
    else:
        print(f"\nFinOps — {args.days} dias (state.db: {STATE_DB})\n")
        print(format_table(data))


if __name__ == '__main__':
    main()
