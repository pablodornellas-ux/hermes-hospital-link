#!/usr/bin/env python
"""session-snapshot.py — Salva contexto de fim de sessão em state.db.
Permite que próxima sessão "lembre" o que aconteceu nesta.

Uso:
    python session-snapshot.py              # cria snapshot
    python session-snapshot.py --list      # lista snapshots
    python session-snapshot.py --latest    # mostra o último

Estrutura:
    Tabela 'session_snapshots' em state.db:
      - id (autoincrement)
      - timestamp (ISO)
      - agent (hostname user)
      - summary (markdown)
      - tags (CSV)
      - mem_chars (int)

Hook Hermes-agent (se configurado):
    Adicionar em hooks/session-end/session-snapshot.py pra rodar automaticamente
"""
import sqlite3
import os
import json
import sys
import argparse
from datetime import datetime
from pathlib import Path


def find_state_db():
    for p in [
        Path(r'C:\Users\Dudy\AppData\Local\hermes\state.db'),
        Path.home() / 'AppData' / 'Local' / 'hermes' / 'state.db',
        Path.home() / '.hermes' / 'state.db',
        Path('/root/.hermes/state.db'),
    ]:
        if p.exists():
            return p
    return None


def ensure_table(con):
    """Cria tabela session_snapshots se não existir."""
    con.execute('''
        CREATE TABLE IF NOT EXISTS session_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            agent TEXT NOT NULL,
            summary TEXT NOT NULL,
            tags TEXT,
            mem_chars INTEGER DEFAULT 0
        )
    ''')
    con.commit()


def save_snapshot(agent, summary, tags=''):
    db = find_state_db()
    if not db:
        print('state.db nao encontrado')
        return 1

    con = sqlite3.connect(str(db), timeout=10)
    ensure_table(con)

    # Conta chars da MEMORY.md atual
    mem_chars = 0
    for fname in ['MEMORY.md', 'USER.md']:
        for p in [Path(r'C:\Users\Dudy\AppData\Local\hermes') / fname,
                  Path.home() / 'AppData' / 'Local' / 'hermes' / fname,
                  Path.home() / '.hermes' / fname]:
            if p.exists():
                mem_chars += p.stat().st_size

    con.execute(
        'INSERT INTO session_snapshots (timestamp, agent, summary, tags, mem_chars) VALUES (?, ?, ?, ?, ?)',
        (datetime.now().isoformat(), agent, summary, tags, mem_chars),
    )
    con.commit()
    con.close()

    print(f'✅ Snapshot salvo: {datetime.now().isoformat()}')
    print(f'  Agent: {agent}')
    print(f'  Tags: {tags or "(none)"}')
    print(f'  MEMORY.md + USER.md total: {mem_chars} bytes')
    print(f'  Summary ({len(summary)} chars):')
    print(f'  ---')
    print(summary[:500] + ('...' if len(summary) > 500 else ''))
    return 0


def list_snapshots(limit=10):
    db = find_state_db()
    if not db:
        print('state.db nao encontrado')
        return 1

    con = sqlite3.connect(str(db), timeout=10)
    ensure_table(con)

    cur = con.execute(
        'SELECT id, timestamp, agent, summary, tags, mem_chars FROM session_snapshots ORDER BY id DESC LIMIT ?',
        (limit,),
    )

    print(f'Últimos {limit} snapshots:')
    for row in cur:
        tags_str = (row[4] or '-')[:60]
        summary_short = (row[3] or '')[:80]
        print(f'  [{row[0]}] {row[1]} | {row[2]} | tags={tags_str} | mem={row[5]}B')
        print(f'           {summary_short}...')

    con.close()
    return 0


def latest_snapshot():
    db = find_state_db()
    if not db:
        print('state.db nao encontrado')
        return 1

    con = sqlite3.connect(str(db), timeout=10)
    ensure_table(con)

    cur = con.execute(
        'SELECT id, timestamp, agent, summary, tags, mem_chars FROM session_snapshots ORDER BY id DESC LIMIT 1'
    )
    row = cur.fetchone()
    con.close()

    if not row:
        print('Nenhum snapshot ainda')
        return 1

    print(f'=== ÚLTIMO SNAPSHOT [{row[0]}] ===')
    print(f'Timestamp: {row[1]}')
    print(f'Agent: {row[2]}')
    print(f'Tags: {row[4] or "(none)"}')
    print(f'MEMORY: {row[5]}B')
    print(f'Summary:')
    print(row[3])
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--list', action='store_true', help='Lista últimos 10 snapshots')
    parser.add_argument('--latest', action='store_true', help='Mostra o último snapshot')
    parser.add_argument('--summary', type=str, help='Texto do summary (pra criar novo)')
    parser.add_argument('--tags', type=str, default='', help='Tags CSV')
    parser.add_argument('--agent', type=str, default=os.environ.get('USER', 'unknown'), help='Nome do agente')

    args = parser.parse_args()

    if args.list:
        return list_snapshots()
    elif args.latest:
        return latest_snapshot()
    elif args.summary:
        return save_snapshot(args.agent, args.summary, args.tags)
    else:
        # Modo default: mostrar como usar
        print('Uso:')
        print('  python session-snapshot.py --summary "..." [--tags "tag1,tag2"]')
        print('  python session-snapshot.py --list')
        print('  python session-snapshot.py --latest')
        print()
        print('Exemplo (auto-save fim de sessão):')
        print('  python session-snapshot.py --summary "Hospital publicado + 8 tasks + scripts harmonize" --tags "hospital,automacao"')
        return 0


if __name__ == '__main__':
    sys.exit(main())