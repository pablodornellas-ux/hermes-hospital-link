#!/usr/bin/env python
"""Hook: pre-llm - prompt-injection-guard (Anti-injection).

Intercepta o input do usuario ANTES de ir pro LLM. Se detectar padroes de
prompt-injection, BLOQUEIA (exit 1) e registra em workspace/logs/prompt-injection.log.
Se limpo, deixa passar (exit 0).

Hook contract:
  - Input do usuario chega por env (HERMES_INPUT / HERMES_USER_INPUT / HERMES_PROMPT /
    HERMES_MESSAGE / HERMES_TASK) e/ou por stdin.
  - exit 0 = limpo (permite passar).
  - exit 1 = injection detectada (bloqueia).

Estrutura igual aos outros hooks: HERMES_HOME com fallback Windows, workspace/ subdir.
"""
import base64
import binascii
import os
import re
import sys
from datetime import datetime
from pathlib import Path


HERMES_HOME = Path(os.environ.get('HERMES_HOME', r'C:\Users\Dudy\AppData\Local\hermes'))
LOG_FILE = HERMES_HOME / 'workspace' / 'logs' / 'prompt-injection.log'


# (nome do padrao, regex). Ordem = prioridade de report.
PATTERNS = [
    ('ignore-instructions', re.compile(
        r'ignore\s+(previous|all|above|as\s+instrucoes|acima|todas)|'
        r'ignore\s+all|ignora\s+(as\s+instrucoes|acima|tudo)|'
        r'disregard\s+(previous|all|the\s+above)',
        re.IGNORECASE)),

    ('role-hijack', re.compile(
        r'you\s+are\s+now\b|act\s+as\b|finge\s+que\s+voce\b|'
        r'pretend\s+(to\s+be|you\s+are)|voce\s+agora\s+e\b|'
        r'from\s+now\s+on\s+you\b',
        re.IGNORECASE)),

    ('fake-system-message', re.compile(
        r'(^|\n)\s*system\s*:|<\s*system\s*>|\[\s*system\s*\]|'
        r'<\|\s*system\s*\|>',
        re.IGNORECASE)),

    ('reveal-prompt', re.compile(
        r'reveal\s+your\s+(instructions|prompt|system)|'
        r'show\s+(me\s+)?your\s+(prompt|instructions|system)|'
        r'mostra(r)?\s+(as\s+)?tuas\s+instrucoes|'
        r'print\s+your\s+(prompt|instructions)|'
        r'what\s+(is|are)\s+your\s+(system\s+)?(prompt|instructions)',
        re.IGNORECASE)),

    # linha que e SO delimitador (### ou ---), usada pra simular fim de prompt
    ('delimiter-injection', re.compile(
        r'(^|\n)\s*(#{3,}|-{3,})\s*(\n|$)')),

    # execute / run command seguido de codigo shell/python
    ('exec-command', re.compile(
        r'\b(execute|run\s+command|rode|executa|exec)\b[\s\S]{0,40}?'
        r'(rm\s+-rf|sudo\s+|curl\s+|wget\s+|os\.system|subprocess|'
        r'import\s+os|eval\s*\(|exec\s*\(|powershell|/bin/sh|bash\s+-c)',
        re.IGNORECASE)),
]

# base64 tratado a parte (precisa validar que decodifica)
B64_RE = re.compile(r'[A-Za-z0-9+/]{50,}={0,2}')


def detect_base64(text):
    """Retorna o trecho suspeito se houver base64 valido (>=50 chars) que decodifica."""
    for m in B64_RE.finditer(text):
        chunk = m.group(0)
        try:
            decoded = base64.b64decode(chunk, validate=True)
            # decodificou pra algo nao-trivial -> payload embutido
            if len(decoded) >= 20:
                return chunk[:60]
        except (binascii.Error, ValueError):
            continue
    return None


def detect(text):
    """Retorna (nome_padrao, trecho) do primeiro match, ou None se limpo."""
    for name, rx in PATTERNS:
        m = rx.search(text)
        if m:
            snippet = m.group(0).strip().replace('\n', ' ')[:60]
            return name, snippet
    b64 = detect_base64(text)
    if b64:
        return 'base64-payload', b64
    return None


def read_input():
    """Coleta o input do usuario de env vars e stdin."""
    parts = []
    for var in ('HERMES_INPUT', 'HERMES_USER_INPUT', 'HERMES_PROMPT',
                'HERMES_MESSAGE', 'HERMES_TASK'):
        val = os.environ.get(var)
        if val:
            parts.append(val)
    # stdin so se env vars nao retornaram nada (CLAUDE AUDIT: evita hang em pipe vazio)
    if not parts:
        try:
            if not sys.stdin.isatty():
                stdin_data = sys.stdin.read()
                if stdin_data:
                    parts.append(stdin_data)
        except Exception:
            pass
    return '\n'.join(parts)


def log_block(pattern, snippet, text):
    """Registra o bloqueio em workspace/logs/prompt-injection.log."""
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        agent = os.environ.get('HERMES_AGENT', os.environ.get('USERNAME', 'unknown'))
        with LOG_FILE.open('a', encoding='utf-8') as f:
            f.write(
                f'[{datetime.now().isoformat()}] BLOCKED agent={agent} '
                f'pattern={pattern} snippet="{snippet}" '
                f'input="{text[:200].replace(chr(10), " ")}"\n'
            )
    except Exception as e:
        print(f'[prompt-injection-guard] falha ao gravar log: {e}')


def main():
    text = read_input()
    if not text.strip():
        # nada pra escanear -> permite
        sys.exit(0)

    hit = detect(text)
    if hit:
        pattern, snippet = hit
        print(f'[BLOCKED] prompt-injection: {pattern} :: {snippet}')
        log_block(pattern, snippet, text)
        sys.exit(1)

    sys.exit(0)


if __name__ == '__main__':
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        # Hook NAO deve quebrar o fluxo por erro proprio -> fail-open, mas avisa.
        print(f'[prompt-injection-guard] erro interno (fail-open): {e}')
        sys.exit(0)
