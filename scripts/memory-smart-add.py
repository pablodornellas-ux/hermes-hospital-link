#!/usr/bin/env python
"""memory-smart-add.py — Cliente wrapper com dedup + versionamento.

EM VEZ DE mexer no mem0-server.py (risco de quebrar), implementa a lógica
NO CLIENTE, antes de chamar o servidor.

Funcionalidades:
1. Dedup: busca antes de salvar, se score > 0.85 = skip
2. Rule versioning: auto-incrementa rule_version por tipo=rule
3. Supersede: aceita lista de IDs antigos a marcar como superseded_by

Uso:
    python memory-smart-add.py --content "..." --metadata '{"type":"rule",...}'
    python memory-smart-add.py --rule "Regras do Hospital" --content "..."
    python memory-smart-add.py --update "ABC123" "DEF456" --content "nova versao da regra X"
"""
import argparse
import hashlib
import json
import os
import re
import sys
import urllib.request
from pathlib import Path


MEM0_URL = os.environ.get('MEM0_URL', 'http://localhost:8765')
DEDUP_THRESHOLD = float(os.environ.get('MEM0_DEDUP_THRESHOLD', '0.85'))


def mem0_search(query, agent, limit=5):
    try:
        req = urllib.request.Request(
            f'{MEM0_URL}/memory/search',
            method='POST',
            headers={'Content-Type': 'application/json'},
            data=json.dumps({'agent': agent, 'query': query, 'limit': limit}).encode(),
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read())
    except Exception as e:
        print(f'  ERR mem0_search: {e}', file=sys.stderr)
        return {'results': []}


def mem0_add(content, agent, metadata=None, supersedes=None):
    try:
        payload = {
            'agent': agent,
            'content': content,
            'metadata': metadata or {},
        }
        if supersedes:
            payload['supersedes'] = supersedes

        req = urllib.request.Request(
            f'{MEM0_URL}/memory/add',
            method='POST',
            headers={'Content-Type': 'application/json'},
            data=json.dumps(payload).encode(),
        )
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return {'ok': False, 'error': e.read().decode()[:200]}
    except Exception as e:
        return {'ok': False, 'error': str(e)}


def get_next_rule_version(agent, query):
    """Conta quantas regras existem pra incrementar versão."""
    result = mem0_search(query, agent, limit=30)
    rules = [r for r in result.get('results', []) if r.get('metadata', {}).get('type') == 'rule']
    versions = [r.get('metadata', {}).get('rule_version', 0) for r in rules]
    return max(versions + [0]) + 1


def smart_add(content, agent='abraao-local', metadata=None, force=False, supersedes=None):
    """Smart add com dedup + versionamento automático."""

    metadata = metadata or {}
    metadata['added_by'] = agent
    metadata['added_at'] = __import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat()

    # 2. DEDUP (a menos que --force)
    if not force:
        result = mem0_search(content[:500], agent, limit=3)
        if result.get('results'):
            top = result['results'][0]
            top_score = top.get('score', 0)
            if top_score >= DEDUP_THRESHOLD:
                print(f'⚠️  DUPLICATA DETECTADA (score={top_score:.3f})')
                print(f'   Top result: {top.get("id", "?")[:30]}... | score {top_score:.3f}')
                print(f'   Title: {top.get("metadata", {}).get("title", "?")[:60]}')
                print()
                print('   Opções:')
                print(f'   --force       : salva mesmo assim')
                print(f'   --update OLD  : marca OLD como superseded e salva a nova')
                print()
                return {
                    'ok': False,
                    'deduplicated': True,
                    'existing_id': top.get('id'),
                    'existing_score': top_score,
                    'message': f'Content similar to existing memory (score={top_score:.3f})',
                }

    # 2b. RULE VERSIONING (sempre, mesmo com --force)
    if metadata.get('type') == 'rule':
        # Conta versoes baseado no conteudo com [RULE vN] marker
        existing = mem0_search(f'[RULE v', agent, limit=50)
        versions = []
        for r in existing.get('results', []):
            title = r.get('metadata', {}).get('title', '')
            # Extrai vN do titulo
            match = re.search(r'v(\d+)', title)
            if match:
                versions.append(int(match.group(1)))
        next_v = max(versions + [0]) + 1
        if 'rule_version' not in metadata:
            metadata['rule_version'] = next_v
        # Adiciona tag de versão no conteúdo
        content = f'[RULE v{metadata["rule_version"]}] {content}'

    # 3. SALVA
    result = mem0_add(content, agent, metadata=metadata, supersedes=supersedes)

    if result.get('ok'):
        new_id = result.get('memory_id', '?')
        print(f'✅ SAVED')
        print(f'   ID: {new_id}')
        print(f'   Collection: {result.get("collection", "?")}')
        if metadata.get('type') == 'rule':
            print(f'   Rule version: {metadata["rule_version"]}')
        if supersedes:
            print(f'   Supersedes: {len(supersedes)} old IDs')

    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--content', '-c', help='Conteúdo da memória')
    parser.add_argument('--agent', '-a', default='abraao-local', help='Agent ID')
    parser.add_argument('--metadata', '-m', help='JSON metadata')
    parser.add_argument('--force', '-f', action='store_true', help='Pular dedup')
    parser.add_argument('--rule', action='store_true', help='Marcar como rule (auto versiona)')
    parser.add_argument('--update', nargs='+', metavar='OLD_ID', help='IDs a marcar como superseded')
    parser.add_argument('--title', help='Title do metadata')

    args = parser.parse_args()

    if not args.content:
        # Ler do stdin
        print('Digite o conteúdo (Ctrl+D quando terminar):')
        args.content = sys.stdin.read().strip()

    if not args.content:
        print('ERRO: conteúdo vazio')
        sys.exit(1)

    # Parse metadata
    metadata = {}
    if args.metadata:
        metadata = json.loads(args.metadata)
    if args.title:
        metadata['title'] = args.title
    if args.rule:
        metadata['type'] = 'rule'

    # Smart add
    result = smart_add(
        args.content,
        agent=args.agent,
        metadata=metadata,
        force=args.force,
        supersedes=args.update,
    )

    sys.exit(0 if result.get('ok') else 1)


if __name__ == '__main__':
    main()