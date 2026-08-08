#!/usr/bin/env python
"""state-db-vacuum.py — VACUUM do state.db via Python (sem depender de sqlite3 CLI).
Idempotente. Roda weekly via Task AbraaoVacuum (mensal dia 1 04:00).
"""
import os
import sqlite3
import sys
from pathlib import Path


def find_state_db():
    for p in [
        Path.home() / 'AppData' / 'Local' / 'hermes' / 'state.db',
        Path('/c/Users/Dudy/AppData/Local/hermes/state.db'),
        Path.home() / '.hermes' / 'state.db',
        Path('/root/.hermes/state.db'),
    ]:
        if p.exists():
            return p
    return None


def main():
    db = find_state_db()
    if not db:
        print('state.db nao encontrado')
        return 1

    size_before = os.path.getsize(db) / 1024 / 1024
    print(f'Antes:  {size_before:.2f}MB ({db})')

    try:
        con = sqlite3.connect(str(db), timeout=30)
        con.execute('VACUUM')
        con.execute('PRAGMA wal_checkpoint(TRUNCATE)')
        con.close()
    except sqlite3.Error as e:
        print(f'VACUUM falhou: {e}')
        return 1

    size_after = os.path.getsize(db) / 1024 / 1024
    delta = size_before - size_after
    print(f'Depois: {size_after:.2f}MB')
    print(f'Reduzido: {delta:.2f}MB')

    # Limpar WAL
    wal = db.parent / (db.name + '-wal')
    if wal.exists():
        wal_size = os.path.getsize(wal) / 1024 / 1024
        print(f'WAL: {wal_size:.2f}MB (foi truncado pelo checkpoint)')

    return 0


if __name__ == '__main__':
    sys.exit(main())