#!/usr/bin/env python3
"""self_learn.py — Diff output vs aprovado, aprende regras e reescreve skills.
Baseado no self-improvement loop do Sylph (YC X25).

Ciclo:
  1. skill gera output
  2. Pablo edita/aprova
  3. self_learn faz diff output vs approved
  4. identifica regras novas
  5. salva em mem0 (vetorizada) + MEMORY.md + reescreve skill se regra persistente

Uso:
    python self_learn.py <eval_id> <approved.md> [--agent abraao] [--dry-run]
    python self_learn.py --stats
"""
import sqlite3
import os
import sys
import json
import re
import difflib
import urllib.request
from pathlib import Path
from datetime import date
from collections import Counter

HERMES_HOME = Path(os.environ.get('HERMES_HOME', os.path.expanduser('~/.hermes')))
STATE_DB = HERMES_HOME / 'state.db'
MEMORY_MD = HERMES_HOME / 'MEMORY.md'
MEM0_URL = os.environ.get('MEM0_URL', 'http://localhost:8765')


def get_eval_from_db(eval_id: int):
    """Pega output original do state.db pelo eval_id."""
    if not STATE_DB.exists():
        return None
    conn = sqlite3.connect(str(STATE_DB))
    try:
        row = conn.execute(
            'SELECT output, expected, agent FROM agent_evals WHERE id = ?',
            (eval_id,)
        ).fetchone()
        return row if row else None
    finally:
        conn.close()


def diff_outputs(generated: str, approved: str):
    """Faz diff entre output gerado e aprovado. Retorna categorias de mudancas."""
    gen_lines = generated.splitlines()
    app_lines = approved.splitlines()

    diff = list(difflib.unified_diff(
        gen_lines, app_lines,
        fromfile='generated', tofile='approved',
        lineterm=''
    ))

    if len(diff) < 3:
        return {'changed': False, 'diff': diff}

    added = [l[1:] for l in diff if l.startswith('+') and not l.startswith('+++')]
    removed = [l[1:] for l in diff if l.startswith('-') and not l.startswith('---')]

    return {
        'changed': True,
        'diff': diff,
        'added': added,
        'removed': removed,
        'diff_size': len(diff)
    }


def identify_rules(added: list, removed: list, generated: str, approved: str):
    """Heuristicas (estilo Sylph) pra identificar regras novas nas edicoes."""
    insights = []
    all_changes = ' '.join(added + removed)
    all_removed_text = ' '.join(removed)
    all_added_text = ' '.join(added)

    # 1. Em-dash removido (Pablo prefere hifen)
    em_dash_removed = sum(1 for l in removed if '\u2014' in l)
    if em_dash_removed > 0:
        insights.append({
            'type': 'style',
            'rule': 'Evitar em-dash (\u2014) — usar hifen (-) ou ponto final',
            'action': 'add_to_memory',
            'evidence': f'{em_dash_removed}x em-dash removido por Pablo',
            'confidence': 0.9
        })

    # 2. Paragrafo longo cortado
    long_removed = [l for l in removed if len(l) > 500]
    if long_removed:
        insights.append({
            'type': 'completeness',
            'rule': 'Cortar paragrafos longos (>500 chars) — Pablo prefere conciso',
            'action': 'add_to_memory',
            'evidence': f'{len(long_removed)} paragrafos longos cortados',
            'confidence': 0.8
        })

    # 3. Code block adicionado (Pablo quer mais exemplos de codigo)
    code_added = sum(1 for l in added if l.strip().startswith('```'))
    if code_added >= 2:
        insights.append({
            'type': 'format',
            'rule': 'Adicionar mais code blocks — ajuda visualizacao',
            'action': 'add_to_skill',
            'evidence': f'{code_added} code blocks adicionados por Pablo',
            'confidence': 0.7
        })

    # 4. Bullet list adicionada (Pablo prefere lista que texto corrido)
    bullet_added = sum(1 for l in added if l.strip().startswith('- ') or l.strip().startswith('* '))
    if bullet_added >= 3:
        insights.append({
            'type': 'format',
            'rule': 'Preferir bullet lists que texto corrido',
            'action': 'add_to_skill',
            'evidence': f'{bullet_added} bullets adicionados por Pablo',
            'confidence': 0.7
        })

    # 5. "Nao perguntar, agir" (Pablo corrige quando agente pergunta)
    if any(p in l.lower() for l in removed for p in ['o que fazer', 'qual opcao', '(a)', '(b)', '(c)']):
        insights.append({
            'type': 'behavior',
            'rule': 'Nao perguntar — agir e reportar',
            'action': 'add_to_memory',
            'evidence': 'Pablo removeu pergunta/menu de opcoes',
            'confidence': 0.9
        })

    # 6. URL adicionada/completada (Pablo corrigiu link incompleto)
    url_added = [l for l in added if 'http' in l]
    if url_added:
        insights.append({
            'type': 'factual',
            'rule': 'Sempre incluir URL completa (nao encurtar)',
            'action': 'add_to_memory',
            'evidence': f'Pablo adicionou/corrigiu URL {len(url_added)}x',
            'confidence': 0.8
        })

    # 7. Resumo cortado (Pablo cortou inicio redundante)
    if len(approved) < len(generated) * 0.7:
        cut_pct = int((1 - len(approved) / len(generated)) * 100)
        if cut_pct > 30:
            insights.append({
                'type': 'completeness',
                'rule': f'Resposta mais curta — Pablo cortou {cut_pct}% do output',
                'action': 'add_to_memory',
                'evidence': f'output original {len(generated)}B → approved {len(approved)}B',
                'confidence': 0.8
            })

    # 8. Fato trocado (numero/nome corrigido) — CLAUDE AUDIT
    # Detecta numeros ou nomes proprios que mudaram de approved → generated
    import re as _re
    nums_removed = set(_re.findall(r'\b\d{2,}\b', all_removed_text))
    nums_added = set(_re.findall(r'\b\d{2,}\b', all_added_text))
    nums_changed = nums_added - nums_removed  # numeros novos que nao estavam no original
    if len(nums_changed) >= 2:
        insights.append({
            'type': 'factual',
            'rule': 'Verificar numeros/dados antes de escrever — Pablo corrigiu fatos',
            'action': 'add_to_memory',
            'evidence': f'{len(nums_changed)} numeros corrigidos: {list(nums_changed)[:5]}',
            'confidence': 0.85
        })

    # 9. Remocao de alucinacao (texto removido sem substituicao) — CLAUDE AUDIT
    # Se linhas foram removidas sem equivalente em added, pode ser alucinacao cortada
    removed_only = [l.strip() for l in removed if l.strip() and len(l.strip()) > 30]
    added_text_lower = all_added_text.lower()
    unvalidated_removals = [l for l in removed_only if l[:20].lower() not in added_text_lower]
    if len(unvalidated_removals) >= 2:
        insights.append({
            'type': 'factual',
            'rule': 'Cuidado com alucinacoes — Pablo cortou conteudo nao fundado',
            'action': 'add_to_memory',
            'evidence': f'{len(unvalidated_removals)} linhas removidas sem substituicao',
            'confidence': 0.75
        })

    # nota: insight de reorganizacao de tom/ordem removido (conf 0.6 < gate 0.7 = codigo morto, Claude audit round 2)

    # GATE DE CONFIANCA (CLAUDE AUDIT): so salva insights com confidence >= 0.7
    insights = [i for i in insights if i.get('confidence', 0) >= 0.7]

    return insights


def save_to_mem0(insight: dict, agent: str):
    """Salva insight no mem0 (vetorizada, Qdrant Cloud). CLAUDE AUDIT: retry + backoff."""
    import time as _time
    content = f"[self-learn {insight['type']}] {insight['rule']}"
    payload = json.dumps({
        'agent': f'{agent}-self-learn',
        'content': content,
        'metadata': {
            'type': 'self_learn',
            'insight_type': insight['type'],
            'confidence': insight.get('confidence', 0.5),
            'evidence': insight.get('evidence', ''),
            'date': str(date.today())
        }
    }).encode()

    max_retries = 3
    for attempt in range(max_retries):
        try:
            req = urllib.request.Request(
                f'{MEM0_URL}/memory/add',
                data=payload,
                headers={'Content-Type': 'application/json'},
                method='POST'
            )
            urllib.request.urlopen(req, timeout=5)
            return True
        except Exception as e:
            if attempt < max_retries - 1:
                _time.sleep(2 ** attempt)  # backoff: 1s, 2s, 4s
                continue
            print(f'WARN: mem0 falhou apos {max_retries} tentativas ({e}) — brain_v2.db fallback', file=sys.stderr)
            return False


def update_memory_md(insights: list, agent: str):
    """Atualiza MEMORY.md com novas regras (camada L1)."""
    if not MEMORY_MD.exists():
        return 0

    content = MEMORY_MD.read_text(encoding='utf-8')
    new_rules = []
    for insight in insights:
        if insight['action'] == 'add_to_memory':
            rule_line = f"- SELF-LEARN [{insight['type']}]: {insight['rule']}"
            if rule_line not in content:
                new_rules.append(rule_line)

    if not new_rules:
        return 0

    today = str(date.today())
    new_section = f"\n\n## Self-learned {today} ({agent})\n" + '\n'.join(new_rules) + '\n'
    MEMORY_MD.write_text(content.rstrip() + new_section, encoding='utf-8')
    return len(new_rules)


def save_lesson_to_brain(insights: list, agent: str):
    """Salva licao em brain_v2.db (fallback se mem0 falhar)."""
    brain_db = HERMES_HOME / 'workspace' / 'brain_v2.db'
    if not brain_db.exists():
        return

    conn = sqlite3.connect(str(brain_db))
    conn.execute('''
        CREATE TABLE IF NOT EXISTS self_learn_lessons (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            agent TEXT,
            type TEXT,
            rule TEXT,
            evidence TEXT,
            confidence REAL
        )
    ''')
    for insight in insights:
        conn.execute('''
            INSERT INTO self_learn_lessons (agent, type, rule, evidence, confidence)
            VALUES (?, ?, ?, ?, ?)
        ''', (agent, insight['type'], insight['rule'],
              insight.get('evidence', ''), insight.get('confidence', 0.5)))
    conn.commit()
    conn.close()


def self_learn(eval_id: int, approved_text: str, agent: str = 'abraao', dry_run: bool = False):
    """Pipeline completo: diff → identifica regras → salva em mem0 + MEMORY.md + brain."""
    row = get_eval_from_db(eval_id)
    if not row:
        return {'error': f'eval_id {eval_id} nao encontrado em state.db'}

    generated, expected, eval_agent = row
    agent = agent or eval_agent

    diff_result = diff_outputs(generated, approved_text)
    if not diff_result['changed']:
        return {'learned': False, 'reason': 'sem diferenças significativas'}

    insights = identify_rules(
        diff_result.get('added', []),
        diff_result.get('removed', []),
        generated, approved_text
    )

    if not insights:
        return {
            'learned': False,
            'diff_size': diff_result['diff_size'],
            'reason': 'diff existe mas nenhuma regra identificada'
        }

    result = {
        'learned': True,
        'eval_id': eval_id,
        'agent': agent,
        'diff_size': diff_result['diff_size'],
        'insights': insights
    }

    if dry_run:
        result['dry_run'] = True
        return result

    # Salvar
    mem0_ok = 0
    for insight in insights:
        if save_to_mem0(insight, agent):
            mem0_ok += 1

    rules_added = update_memory_md(insights, agent)
    save_lesson_to_brain(insights, agent)

    result['mem0_saved'] = mem0_ok
    result['memory_md_rules_added'] = rules_added
    result['brain_saved'] = len(insights)

    return result


def stats():
    """Mostra stats de self-learning."""
    brain_db = HERMES_HOME / 'workspace' / 'brain_v2.db'
    if not brain_db.exists():
        print('Nenhuma licao de self-learning ainda.')
        return

    conn = sqlite3.connect(str(brain_db))
    try:
        rows = conn.execute('''
            SELECT type, COUNT(*) as total, AVG(confidence) as avg_conf
            FROM self_learn_lessons
            GROUP BY type
            ORDER BY total DESC
        ''').fetchall()

        if not rows:
            print('Nenhuma licao de self-learning ainda.')
            return

        print('=== SELF-LEARN STATS ===')
        for type_, total, avg_conf in rows:
            print(f'  {type_:15s} {total:3d} licocs  conf={avg_conf:.2f}')

        print()
        print('Ultimas 5 licocs:')
        recent = conn.execute('''
            SELECT type, rule, evidence, timestamp
            FROM self_learn_lessons
            ORDER BY timestamp DESC
            LIMIT 5
        ''').fetchall()
        for type_, rule, evidence, ts in recent:
            print(f'  [{type_}] {rule[:60]}')
            print(f'    evidence: {evidence[:60]}')
            print(f'    {ts}')
    finally:
        conn.close()


def main():
    args = sys.argv[1:]

    if not args or args[0] == '--stats':
        stats()
        return

    if args[0] in ['-h', '--help']:
        print(__doc__)
        return

    if len(args) < 2:
        print('Uso: self_learn.py <eval_id> <approved.md> [--agent abraao] [--dry-run]')
        sys.exit(1)

    eval_id = int(args[0])
    approved_file = args[1]
    agent = 'abraao'
    dry_run = False

    for arg in args[2:]:
        if arg.startswith('--agent='):
            agent = arg.split('=')[1]
        elif arg == '--dry-run':
            dry_run = True

    if not os.path.exists(approved_file):
        print(f'Erro: arquivo nao encontrado: {approved_file}')
        sys.exit(1)

    approved_text = open(approved_file, encoding='utf-8').read()
    result = self_learn(eval_id, approved_text, agent, dry_run)

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()