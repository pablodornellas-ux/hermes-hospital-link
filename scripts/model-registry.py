#!/usr/bin/env python3
"""model-registry.py — Registro versionado de modelos por agente (state.db).

Cada agente aponta para um par (alias -> model/provider). Trocar de modelo
NUNCA apaga o anterior: gera nova versao ativa e mantem o historico, para que
`rollback` volte determinístico à versao anterior (version-1).

Funcs (tambem expostas via CLI):
    register(agent, alias, model, provider)  -> ativa nova versao
    activate(agent, alias)                    -> reativa um alias ja registrado
    rollback(agent)                           -> volta para version-1
    list_active()                             -> um registro ativo por agente
    ab_assign(agent, alias_a, alias_b)        -> marca dois aliases em A/B

CLI:
    python model-registry.py register <agent> <alias> <model> <provider>
    python model-registry.py activate <agent> <alias>
    python model-registry.py rollback <agent>
    python model-registry.py list_active
    python model-registry.py ab_assign <agent> <alias_a> <alias_b>
"""
import sqlite3
import os
import sys
import json
from pathlib import Path
from datetime import datetime

# Detecta HERMES_HOME (mesmo fallback do finops-aggregator / watchdog)
if os.environ.get('HERMES_HOME') and Path(os.environ['HERMES_HOME'], 'state.db').exists():
    HERMES_HOME = Path(os.environ['HERMES_HOME'])
elif os.name == 'nt' and Path(os.environ.get('LOCALAPPDATA', ''), 'hermes', 'state.db').exists():
    HERMES_HOME = Path(os.environ['LOCALAPPDATA'], 'hermes')
elif Path.home().joinpath('.hermes', 'state.db').exists():
    HERMES_HOME = Path.home() / '.hermes'
else:
    # Ainda permite criar o DB no local canonico do Windows
    HERMES_HOME = Path(os.environ.get('LOCALAPPDATA', str(Path.home()))) / 'hermes'
    HERMES_HOME.mkdir(parents=True, exist_ok=True)

STATE_DB = HERMES_HOME / 'state.db'


def _conn():
    conn = sqlite3.connect(str(STATE_DB))
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = _conn()
    conn.execute('''
        CREATE TABLE IF NOT EXISTS model_registry (
            id INTEGER PRIMARY KEY,
            timestamp TEXT,
            agent TEXT,
            alias TEXT,
            model TEXT,
            provider TEXT,
            active INTEGER DEFAULT 1,
            version INTEGER DEFAULT 1,
            metrics TEXT
        )
    ''')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_registry_agent ON model_registry(agent)')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_registry_active ON model_registry(agent, active)')
    conn.commit()
    conn.close()


def _max_version(conn, agent):
    row = conn.execute(
        'SELECT COALESCE(MAX(version), 0) AS v FROM model_registry WHERE agent = ?',
        (agent,)
    ).fetchone()
    return row['v']


def register(agent, alias, model, provider):
    """Registra uma nova versao ativa para o agente e desativa as anteriores."""
    init_db()
    conn = _conn()
    version = _max_version(conn, agent) + 1
    # Desativa tudo do agente antes de ativar a nova versao
    conn.execute('UPDATE model_registry SET active = 0 WHERE agent = ?', (agent,))
    conn.execute('''
        INSERT INTO model_registry (timestamp, agent, alias, model, provider, active, version, metrics)
        VALUES (?, ?, ?, ?, ?, 1, ?, ?)
    ''', (datetime.now().isoformat(), agent, alias, model, provider, version, json.dumps({})))
    conn.commit()
    conn.close()
    print(f"OK register: {agent} -> {alias} ({model} @ {provider}) v{version} [active]")
    return version


def activate(agent, alias):
    """Reativa a versao mais recente de um alias ja registrado para o agente."""
    init_db()
    conn = _conn()
    row = conn.execute('''
        SELECT id, version, model, provider FROM model_registry
        WHERE agent = ? AND alias = ?
        ORDER BY version DESC LIMIT 1
    ''', (agent, alias)).fetchone()
    if not row:
        conn.close()
        print(f"ERRO: alias '{alias}' nao registrado para agente '{agent}'")
        return None
    conn.execute('UPDATE model_registry SET active = 0 WHERE agent = ?', (agent,))
    conn.execute('UPDATE model_registry SET active = 1 WHERE id = ?', (row['id'],))
    conn.commit()
    conn.close()
    print(f"OK activate: {agent} -> {alias} ({row['model']} @ {row['provider']}) v{row['version']}")
    return row['version']


def rollback(agent):
    """Volta para a versao anterior: desativa a atual (active=1) e ativa version-1."""
    init_db()
    conn = _conn()
    current = conn.execute(
        'SELECT id, version, alias FROM model_registry WHERE agent = ? AND active = 1 ORDER BY version DESC LIMIT 1',
        (agent,)
    ).fetchone()
    if not current:
        conn.close()
        print(f"ERRO: nenhuma versao ativa para agente '{agent}'")
        return None
    prev = conn.execute(
        'SELECT id, version, alias, model, provider FROM model_registry WHERE agent = ? AND version = ? LIMIT 1',
        (agent, current['version'] - 1)
    ).fetchone()
    if not prev:
        conn.close()
        print(f"ERRO: nao ha versao anterior (v{current['version'] - 1}) para '{agent}' — rollback abortado")
        return None
    conn.execute('UPDATE model_registry SET active = 0 WHERE id = ?', (current['id'],))
    conn.execute('UPDATE model_registry SET active = 1 WHERE id = ?', (prev['id'],))
    conn.commit()
    conn.close()
    print(f"OK rollback: {agent} v{current['version']} ({current['alias']}) -> v{prev['version']} ({prev['alias']}: {prev['model']} @ {prev['provider']})")
    return prev['version']


def list_active():
    """Um registro ativo por agente."""
    init_db()
    conn = _conn()
    rows = conn.execute('''
        SELECT agent, alias, model, provider, version, timestamp
        FROM model_registry WHERE active = 1
        ORDER BY agent
    ''').fetchall()
    conn.close()
    if not rows:
        print("Nenhum modelo ativo registrado.")
        return []
    print(f"{'Agente':<15} {'Alias':<18} {'Modelo':<24} {'Provider':<14} {'Ver':>4}")
    print('-' * 80)
    out = []
    for r in rows:
        print(f"{r['agent']:<15} {r['alias']:<18} {(r['model'] or '')[:24]:<24} {(r['provider'] or '')[:14]:<14} {r['version']:>4}")
        out.append(dict(r))
    return out


def ab_assign(agent, alias_a, alias_b):
    """Marca dois aliases do agente num teste A/B: ambos ativos, tag em metrics."""
    init_db()
    conn = _conn()
    ids = {}
    for grp, alias in (('A', alias_a), ('B', alias_b)):
        row = conn.execute('''
            SELECT id, model, provider FROM model_registry
            WHERE agent = ? AND alias = ?
            ORDER BY version DESC LIMIT 1
        ''', (agent, alias)).fetchone()
        if not row:
            conn.close()
            print(f"ERRO: alias '{alias}' (grupo {grp}) nao registrado para '{agent}'")
            return None
        ids[grp] = (row['id'], alias, row['model'], row['provider'])
    # Desativa o resto, ativa os dois do A/B e taggeia metrics
    conn.execute('UPDATE model_registry SET active = 0 WHERE agent = ?', (agent,))
    for grp, (rid, alias, model, provider) in ids.items():
        metrics = json.dumps({'ab_group': grp, 'ab_peer': alias_b if grp == 'A' else alias_a})
        conn.execute('UPDATE model_registry SET active = 1, metrics = ? WHERE id = ?', (metrics, rid))
    conn.commit()
    conn.close()
    print(f"OK ab_assign: {agent} A={ids['A'][1]} ({ids['A'][2]}) vs B={ids['B'][1]} ({ids['B'][2]})")
    return {'A': ids['A'][1], 'B': ids['B'][1]}


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return

    cmd = args[0]
    if cmd == 'register':
        if len(args) < 5:
            print("Uso: model-registry.py register <agent> <alias> <model> <provider>")
            sys.exit(1)
        register(args[1], args[2], args[3], args[4])
    elif cmd == 'activate':
        if len(args) < 3:
            print("Uso: model-registry.py activate <agent> <alias>")
            sys.exit(1)
        activate(args[1], args[2])
    elif cmd == 'rollback':
        if len(args) < 2:
            print("Uso: model-registry.py rollback <agent>")
            sys.exit(1)
        rollback(args[1])
    elif cmd == 'list_active':
        list_active()
    elif cmd == 'ab_assign':
        if len(args) < 4:
            print("Uso: model-registry.py ab_assign <agent> <alias_a> <alias_b>")
            sys.exit(1)
        ab_assign(args[1], args[2], args[3])
    elif cmd in ('-h', '--help'):
        print(__doc__)
    else:
        print(f"Comando desconhecido: {cmd}")
        print("Use: register | activate | rollback | list_active | ab_assign")
        sys.exit(1)


if __name__ == '__main__':
    main()
