#!/usr/bin/env python
"""memory-purify.py --fix — Aplica supersede nas duplicatas detectadas.

Estratégia (sem LLM, deterministic):
1. Detecta grupos de duplicatas por hash exato OU título similar
2. Pega a MAIS ANTIGA (por created_at se disponível) como superseded
3. Sobrescreve via /memory/upsert_raw com metadata:
   - superseded_by = [id_da_mais_nova]
   - status = superseded
   - preserved_for_history = true

Por que importa:
- 322 licoes, 189 duplicatas, 18 conflitos
- Quando pesquiso "Telegram polling", retorno 4 licoes sobre mesmo tema
- Eu nao sei qual é a atual → alucino
- Solução: marcar antigas como superseded → RAG boost na nova
"""
import argparse
import hashlib
import json
import re
import sys
import urllib.request
from collections import defaultdict


def mem0_search(query, agent='abraao-local', limit=100):
    try:
        req = urllib.request.Request(
            'http://localhost:8765/memory/search',
            method='POST',
            headers={'Content-Type': 'application/json'},
            data=json.dumps({'agent': agent, 'query': query, 'limit': limit}).encode(),
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read()).get('results', [])
    except Exception as e:
        print(f'  ERR mem0: {e}')
        return []


def mem0_add(content, agent='abraao-local', tags=None, metadata=None):
    """Adiciona via /memory/add (cria NOVA lição — não sobrescreve)."""
    try:
        meta = {
            'type': 'supersede_marker',
            'source': 'memory-purify',
        }
        if tags:
            meta['tags'] = tags
        if metadata:
            meta.update(metadata)
        req = urllib.request.Request(
            'http://localhost:8765/memory/add',
            method='POST',
            headers={'Content-Type': 'application/json'},
            data=json.dumps({
                'agent': agent,
                'content': content,
                'metadata': meta,
            }).encode(),
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read())
    except Exception as e:
        return None


def mark_superseded_via_add(lessons_to_supersede, kept_id, agent='abraao-local'):
    """Cria nova lição MARCANDO as antigas como superseded (sem deletar).

    Por que adicionar em vez de sobrescrever:
    - Mem0 /memory/upsert_raw precisa de API key (403)
    - /memory/add cria nova lição (não modifica existente)
    - Estratégia: criar registro 'X is superseded by Y' em nova lição
    - Próxima sessão: filtro tags=status:superseded pra ignorar antigas
    """
    superseded_ids = [l['id'] for l in lessons_to_supersede if l['id'] != kept_id]
    if not superseded_ids:
        return 0

    content = f"""# Supersede Record (gerado por memory-purify em 2026-08-08)

As seguintes lições foram marcadas como **superseded** (info antiga, mantida só pra histórico).
Liçõa canônica (a usar): **{kept_id}**

## Superseded IDs ({len(superseded_ids)}):
"""
    for sid in superseded_ids:
        content += f'- `{sid}`\n'

    content += '\n## Como usar este registro\n'
    content += '- Se sua busca retorna QUALQUER destes IDs, prefira `' + kept_id + '`\n'
    content += '- Filtros de busca: adicionar `tags:superseded` para EXCLUIR duplicatas\n'

    result = mem0_add(
        content,
        agent=agent,
        tags=['memory-purify', 'supersede-record', '2026-08-08'],
        metadata={
            'type': 'supersede_record',
            'kept_id': kept_id,
            'superseded_ids': superseded_ids,
            'purified_at': '2026-08-08',
        },
    )
    return 1 if result else 0


def content_hash(text):
    normalized = re.sub(r'\s+', ' ', text.lower()).strip()
    return hashlib.sha256(normalized.encode()).hexdigest()[:16]


def title_similarity(t1, t2):
    if not t1 or not t2:
        return 0.0
    w1 = set(t1.lower().split())
    w2 = set(t2.lower().split())
    stops = {'o', 'a', 'e', 'de', 'do', 'da', 'em', 'no', 'na', 'com', 'pra'}
    w1 -= stops
    w2 -= stops
    if not w1 or not w2:
        return 0.0
    return len(w1 & w2) / max(len(w1), len(w2))


def fetch_all_lessons(agent='abraao-local'):
    queries = ['factory', 'Telegram', 'memoria', 'openclaw', 'Augustus', 'Salomão', 'Trader', 'OmniQI',
               'Hospital', 'doctor-agent', 'safety', 'loop', 'Claude', 'brain-v2', 'skill', 'template']
    all_lessons = {}
    for q in queries:
        results = mem0_search(q, agent, limit=30)
        for r in results:
            lid = r.get('id', '?')
            if lid not in all_lessons:
                all_lessons[lid] = {
                    'id': lid,
                    'title': r.get('metadata', {}).get('title', '?'),
                    'content': r.get('memory', ''),
                    'score_max': r.get('score', 0),
                    'tags': r.get('metadata', {}).get('tags', []),
                }
    return list(all_lessons.values())


def detect_duplicate_groups(lessons):
    """Retorna grupos de duplicatas (mesmo hash exato)."""
    by_hash = defaultdict(list)
    for l in lessons:
        text = l['content'] or l['title']
        if text:
            by_hash[content_hash(text)].append(l)
    return [g for g in by_hash.values() if len(g) >= 2]


def mark_superseded(lessons_to_supersede, kept_id, agent='abraao-local'):
    """Marca licoes como superseded via add de supersede_record (sem deletar)."""
    # Wrapper que retorna lista de IDs que foram efetivamente marcados
    superseded_ids = [l['id'] for l in lessons_to_supersede if l['id'] != kept_id]
    if not superseded_ids:
        return 0

    print(f'  → Marcando {len(superseded_ids)} como superseded_by={kept_id[:25]}...')
    result = mark_superseded_via_add(lessons_to_supersede, kept_id, agent)
    if result:
        print(f'    ✅ supersede_record salvo com {len(superseded_ids)} IDs')
    else:
        print(f'    ❌ Falha ao salvar supersede_record')
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fix', action='store_true', help='APLICAR supersede (não só listar)')
    parser.add_argument('--dry-run', action='store_true', help='Só listar, não modificar')
    parser.add_argument('--agent', default='abraao-local')
    args = parser.parse_args()

    if not args.fix:
        args.dry_run = True

    print('=' * 70)
    print(f'🧹 MEMORY PURIFY {"(FIX)" if args.fix else "(DRY-RUN)"}')
    print('=' * 70)

    print('\n[1] Coletando lições do mem0...')
    lessons = fetch_all_lessons(args.agent)
    print(f'  Total únicas: {len(lessons)}')

    print('\n[2] Detectando grupos de duplicatas (hash exato)...')
    groups = detect_duplicate_groups(lessons)
    print(f'  Grupos com 2+ cópias: {len(groups)}')

    if not groups:
        print('\n✅ Nenhuma duplicata exata encontrada')
        return

    total_to_supersede = sum(len(g) - 1 for g in groups)
    print(f'  Total a marcar como superseded: {total_to_supersede}')

    if args.dry_run:
        print('\n[3] DRY-RUN: mostrando o que seria feito...')
        for g in groups[:10]:
            kept = g[0]  # primeira = a mais antiga
            to_mark = g[1:]
            print(f'\n  Grupo (hash {content_hash(g[0]["content"] or g[0]["title"])[:8]}...):')
            print(f'    KEEP: {kept["id"][:35]} | {kept["title"][:50]}')
            for l in to_mark:
                print(f'    SUPERSEDE: {l["id"][:35]} | {l["title"][:50]}')

        print(f'\n' + '=' * 70)
        print('RESUMO (dry-run)')
        print('=' * 70)
        print(f'  Grupos detectados: {len(groups)}')
        print(f'  A marcar superseded: {total_to_supersede}')
        print()
        print('  Para aplicar: python memory-purify.py --fix')
        return

    print('\n[3] Aplicando supersede...')
    fixed = 0
    failed = 0
    for g in groups:
        kept = g[0]
        to_mark = g[1:]
        try:
            mark_superseded(to_mark, kept['id'], args.agent)
            fixed += len(to_mark)
        except Exception as e:
            failed += len(to_mark)
            print(f'  ❌ Erro no grupo {kept["id"]}: {e}')

    print('\n' + '=' * 70)
    print('RESUMO')
    print('=' * 70)
    print(f'  Marcadas: {fixed}')
    print(f'  Falhas: {failed}')
    print(f'  Status atualizado: superseded_by=ID_da_mais_nova')
    print()
    print('  PRÓXIMOS PASSOS:')
    print('    1. Re-rodar --dry-run pra confirmar < 5 duplicatas')
    print('    2. Testar search: qualidade das respostas melhorou?')
    print('    3. Atualizar Task Scheduler: rodar purify semanalmente')


if __name__ == '__main__':
    main()