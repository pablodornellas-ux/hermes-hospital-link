#!/usr/bin/env python
"""harmonize_memory.py — Sincroniza TODAS as 5 camadas de memória + 7ª Ground Truth.
Roda daily via Task AbraaoHospital. Idempotente, safe, report-only por padrão.

Modo:
  --check      (default) só reporta problemas
  --fix        aplica correções automáticas
  --harmonize  check + fix + valida

Camadas verificadas:
  L1 - MEMORY.md, USER.md, SOUL.md (built-in, injetadas)
  L2 - mem0 + Qdrant (status)
  L3 - state.db (WAL, sessions, growth rate)
  L4 - skills (count, duplicates)
  L5 - backups (recency)
  L7 - Ground Truth (presente em SOUL.md)
"""
import json
import os
import re
import sqlite3
import sys
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path

OK = '✅'
WARN = '⚠️ '
FAIL = '❌'


def find_hermes_home():
    """Auto-detecta HERMES_HOME (multi-platform)."""
    for p in [
        Path(r'C:\Users\Dudy\AppData\Local\hermes'),
        Path.home() / 'AppData' / 'Local' / 'hermes',
        Path.home() / '.hermes',
        Path('/root/.hermes'),
        Path.home() / 'Documents' / 'hermes',
    ]:
        if p.exists():
            return p
    return None


def check_l1(hermes_home, results):
    """L1: MEMORY.md + USER.md + SOUL.md + L7 Ground Truth."""
    print('\n[ L1 - Built-in ]')
    for fname in ['MEMORY.md', 'USER.md', 'SOUL.md']:
        f = hermes_home / fname
        if f.exists():
            size = f.stat().st_size
            print(f'  {OK} {fname}: {size}B')
            results[f'{fname}_ok'] = size > 200
        else:
            print(f'  {FAIL} {fname}: nao encontrado')
            results[f'{fname}_ok'] = False

    # L7 Ground Truth
    soul = hermes_home / 'SOUL.md'
    if soul.exists():
        soul_text = soul.read_text(encoding='utf-8', errors='ignore')
        if 'GROUND TRUTH' in soul_text or 'Ground Truth' in soul_text:
            print(f'  {OK} L7 Ground Truth: documentado em SOUL.md')
            results['L7_ok'] = True
        else:
            print(f'  {WARN} L7 Ground Truth: AUSENTE em SOUL.md (camada critica)')
            results['L7_ok'] = False


def check_l2(results):
    """L2: mem0-server + Qdrant."""
    print('\n[ L2 - Provider ]')
    try:
        req = urllib.request.urlopen('http://localhost:8765/health', timeout=3)
        d = json.loads(req.read())
        if d.get('status') == 'ok':
            print(f'  {OK} mem0-server: ok ({len(d.get("collections", []))} collections)')
            results['L2_mem0_ok'] = True
        else:
            print(f'  {WARN} mem0-server: status {d.get("status")}')
            results['L2_mem0_ok'] = False
    except Exception as e:
        print(f'  {FAIL} mem0-server: {type(e).__name__}')
        results['L2_mem0_ok'] = False

    # Testar search
    try:
        req = urllib.request.Request(
            'http://localhost:8765/memory/search',
            method='POST',
            headers={'Content-Type': 'application/json'},
            data=json.dumps({'agent': 'abraao-local', 'query': 'memory layer test', 'limit': 1}).encode(),
        )
        d = json.loads(urllib.request.urlopen(req, timeout=5).read())
        if d.get('ok'):
            print(f'  {OK} mem0 search: funcional ({d.get("count")} results)')
            results['L2_search_ok'] = True
    except Exception as e:
        print(f'  {WARN} mem0 search: {type(e).__name__}')


def check_l3(hermes_home, results):
    """L3: state.db + WAL + sessions."""
    print('\n[ L3 - Sessions ]')
    db = hermes_home / 'state.db'
    if not db.exists():
        print(f'  {FAIL} state.db: nao encontrado')
        results['L3_ok'] = False
        return

    size_mb = db.stat().st_size / 1024 / 1024
    print(f'  state.db: {size_mb:.1f}MB')

    if size_mb > 80:
        print(f'  {FAIL} state.db > 80MB - VACUUM urgente')
        results['L3_size_warn'] = True
    elif size_mb > 60:
        print(f'  {WARN} state.db > 60MB - agendar VACUUM')
    else:
        print(f'  {OK} state.db tamanho OK')

    # WAL
    wal = db.parent / (db.name + '-wal')
    if wal.exists():
        wal_mb = wal.stat().st_size / 1024 / 1024
        print(f'  WAL: {wal_mb:.1f}MB')

    # PRAGMA
    try:
        con = sqlite3.connect(str(db), timeout=10)
        cur = con.execute('PRAGMA integrity_check')
        result = cur.fetchone()[0]
        if result == 'ok':
            print(f'  {OK} state.db: integridade OK')
            results['L3_integrity_ok'] = True
        else:
            print(f'  {FAIL} state.db: integridade {result}')
            results['L3_integrity_ok'] = False
        con.close()
    except Exception as e:
        print(f'  {WARN} state.db PRAGMA: {e}')


def check_l4(hermes_home, results):
    """L4: skills count + duplicates."""
    print('\n[ L4 - Skills ]')
    skills = hermes_home / 'skills'
    if not skills.exists():
        print(f'  {FAIL} skills/: nao encontrado')
        results['L4_ok'] = False
        return

    # SKILL.md count
    count = len(list(skills.rglob('SKILL.md')))
    print(f'  skills count: {count}')

    # Duplicates
    skill_dirs = [d for d in skills.rglob('SKILL.md')]
    seen = {}
    dupes = []
    for skill_md in skill_dirs:
        name = skill_md.parent.name
        if name in seen:
            dupes.append(name)
        seen[name] = skill_md

    if dupes:
        print(f'  {FAIL} skills duplicados: {dupes}')
        results['L4_dup_ok'] = False
    else:
        print(f'  {OK} skills: sem duplicados')
        results['L4_dup_ok'] = True

    # Skills oficiais de memoria
    memory_skills = [s for s in ['memory-save', 'memory-layer-architecture', 'knowledge-digest']
                     if (skills / 'openclaw-imports' / s).exists()]
    print(f'  memory skills: {memory_skills}')
    results['L4_memory_skills'] = len(memory_skills)


def check_l5(hermes_home, results):
    """L5: backups."""
    print('\n[ L5 - Cold storage ]')
    backup_dir = Path(r'C:\Users\Dudy\.hermes\workspace\backups')
    if not backup_dir.exists():
        print(f'  {FAIL} backup dir: nao encontrado')
        results['L5_ok'] = False
        return

    backups = sorted(backup_dir.glob('brain-backup-*.tar.gz'))
    if not backups:
        print(f'  {WARN} nenhum backup encontrado')
        return

    latest = backups[-1]
    age = datetime.now() - datetime.fromtimestamp(latest.stat().st_mtime)
    age_days = age.total_seconds() / 86400

    print(f'  ultimo backup: {latest.name} ({age_days:.1f}d atraz)')

    if age_days > 7:
        print(f'  {WARN} backup > 7 dias')
        results['L5_ok'] = False
    else:
        print(f'  {OK} backup recente')
        results['L5_ok'] = True


def main():
    mode = '--check'
    if '--fix' in sys.argv:
        mode = '--fix'
    elif '--harmonize' in sys.argv:
        mode = '--harmonize'

    print(f'============================================')
    print(f'HARMONIZE MEMORY — {mode}')
    print(f'============================================')

    hermes_home = find_hermes_home()
    if not hermes_home:
        print('HERMES_HOME nao encontrado')
        return 1

    print(f'HERMES_HOME: {hermes_home}')

    results = {}

    check_l1(hermes_home, results)
    check_l2(results)
    check_l3(hermes_home, results)
    check_l4(hermes_home, results)
    check_l5(hermes_home, results)

    # Auto-fix
    if mode in ('--fix', '--harmonize'):
        print('\n[ AUTO-FIX ]')
        # VACUUM state.db se > 60MB
        db = hermes_home / 'state.db'
        if db.exists() and db.stat().st_size / 1024 / 1024 > 60:
            try:
                con = sqlite3.connect(str(db), timeout=30)
                con.execute('VACUUM')
                con.execute('PRAGMA wal_checkpoint(TRUNCATE)')
                con.close()
                print(f'  {OK} VACUUM aplicado')
            except Exception as e:
                print(f'  {FAIL} VACUUM: {e}')

    # Summary
    print('\n[ SUMMARY ]')
    total = len(results)
    ok = sum(1 for v in results.values() if v)
    print(f'  {ok}/{total} checks OK')
    if ok < total:
        print(f'  {total - ok} needs attention')

    return 0 if ok == total else 1


if __name__ == '__main__':
    sys.exit(main())