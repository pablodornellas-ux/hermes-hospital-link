#!/usr/bin/env python
"""Hook: session-end — Auto-snapshot ao fim de sessão.

Rodado pelo Hermes-agent quando sessão termina (ou manualmente).
Salva contexto resumido em state.db pra próxima sessão ter continuidade.
"""
import os
import sys
import subprocess
from datetime import datetime
from pathlib import Path


HERMES_HOME = Path(os.environ.get('HERMES_HOME', r'C:\Users\Dudy\AppData\Local\hermes'))


def main():
    # Pega info da sessão atual via env vars do Hermes
    agent = os.environ.get('HERMES_AGENT', 'unknown')
    summary = os.environ.get('HERMES_SESSION_SUMMARY', '')

    if not summary:
        # Auto-summary genérico
        summary = (
            f"Sessao {agent} terminou em {datetime.now().isoformat()} "
            f"sem summary explicito. Verificar context-snapshot manual se precisar."
        )

    # Chama o session-snapshot.py
    snapshot_script = HERMES_HOME / 'workspace' / 'scripts' / 'session-snapshot.py'
    if not snapshot_script.exists():
        print(f'session-snapshot.py nao encontrado em {snapshot_script}')
        return 1

    try:
        result = subprocess.run(
            ['python', str(snapshot_script), '--summary', summary, '--agent', agent],
            capture_output=True, text=True, timeout=30,
        )
        print(result.stdout)
        if result.returncode != 0:
            print(f'ERR: {result.stderr}')
            return result.returncode
        return 0
    except Exception as e:
        print(f'EXC: {e}')
        return 1


if __name__ == '__main__':
    sys.exit(main())