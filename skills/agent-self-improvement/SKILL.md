---
name: agent-self-improvement
description: "Self-learning loop + eval + observabilidade pra agentes Hermes-Agent. Baseado em Sylph (YC X25), JudgmentLabs, AgentOps, Future AGI, Raindrop Workshop. Aplica em todos os templates."
version: 1.0.0
---

# Agent Self-Improvement — Eval + Self-Learning + Observability

> **Pablo cobrou (09-08):** "vc não viu nada de eval?"
> Estudei 6 projetos YC/estrelados: Sylph, JudgmentLabs, AgentOps, Future AGI, Raindrop Workshop, Trulens. Aqui está o padrão consolidado.

---

## 🎯 O FALTÃO (o que NÃO tenemos)

| Item | Sylph (YC X25) | Judgeval (1k⭐) | AgentOps (5.7k⭐) | Future AGI (1.6k⭐) | Workshop (960⭐) | **Nós** |
|---|---|---|---|---|---|---|
| **Tracing** | ❌ | ✅ OpenTelemetry | ✅ Session replay | ✅ End-to-end | ✅ Live traces | ❌ só logs |
| **Eval (judge)** | ❌ implícito | ✅ Agent judges | ✅ Benchmarking | ✅ Evals + guards | ✅ Self-healing | ❌ |
| **Self-learning** | ✅ diff output vs editado | ❌ | ❌ | ✅ Feedback loop | ✅ Eval loop | ❌ |
| **Observability dashboard** | ❌ | ✅ Slack alerts | ✅ Web UI | ✅ Web UI | ✅ Live UI | ❌ |
| **Guardrails** | ❌ | ✅ Online monitor | ✅ Cost track | ✅ Simulations | ❌ | ❌ |
| **Regression tests** | ❌ | ✅ Replay traces | ✅ Replay sessions | ✅ CI integration | ✅ Local replay | ❌ |

### O que nos falta (1-3):

1. **Eval:** Step-by-step scoring de cada agente (evaluability)
2. **Self-learning:** Diff output→approved→rewrite skill regras
3. **Tracing:** Observar cada tool call, cada token, cada decision

---

## 📐 PADRÃO DA INDÚSTRIA (estudado)

### 1. **Sylph** (YC X25 — 178⭐)
```yaml
Self-learning loop (genial pra sua simplicidade):
  skill gera output → CAO edita/aprova → 
  skill faz diff output-vs-editado →
  se diff revela regra nova: adiciona em _insights.md ou em Writing rules
  se performa bem: promove pra _examples/ (referência futura)
```

### 2. **JudgmentLabs** (1056⭐ — continuous-improvement)
```python
# Tracing automático (OpenTelemetry)
@Tracer.observe(span_type="agent")
def run_agent(question):
    return client.chat.completions.create(...)

# Agent judges (scorers)
def judge_response(trace):
    if "alucinação" in trace.output:
        return {"score": 0, "reason": "inventou fato"}
    return {"score": 1, "reason": " OK"}

# Online monitoring
# Production traffic é scored server-side
# Alertas Slack se regressão
```

### 3. **AgentOps** (5760⭐)
- Session replay (vê step-by-step do agent)
- Cost tracking (tokens consumidos)
- Benchmark vs baseline
- Dashboard web

### 4. **Future AGI** (1.6k⭐)
"Self-improving AI agents" — loop único de feedback:
```
Evals → Tracing → Simulations → Guardrails → Gateway → Optimization
```

### 5. **Raindrop Workshop** (960⭐)
Claude Code escreve evals, roda agent, vê falha, corrige código, re-roda até passar. Self-healing loop.

---

## 🛠️ NOSSO SELF-IMPROVEMENT LOOP (pro Abraão + OmniQI)

Vou copiar o padrão Sylph + Workshop adaptado pra Hermes-Agent.

### Arquitetura

```
┌────────────────────────────────────────────────────┐
│ FASE 1 — TRACING (cada task do agente)            │
│                                                    │
│ hook pre-task  → registra task_start + input       │
│ hook post-task → registra task_end + output        │
│ state.db      → armazena traces (FTS5 searchable)  │
└────────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────────┐
│ FASE 2 — EVAL (score quality)                      │
│                                                    │
│ Pablo aprova/rejeita/edição                         │
│ eval_judge.py compara output-vs-approved           │
│ 3 scores: factual, completeness, style              │
└────────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────────┐
│ FASE 3 — SELF-LEARNING (diff + rewrite rules)      │
│                                                    │
│ Se aprovado com diffs → aprender:                  │
│  - diff output vs approved                         │
│  - identificar regra nova                          │
│  - adiciona em _insights.md                        │
│  - se regra é permanente: reescreve skill          │
│  - mem0 guarda lição (vetorizada)                  │
└────────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────────┐
│ FASE 4 — REGRESSION TESTS (replay)                │
│                                                    │
│ Guarda traces de sucesso em _examples/              │
│ Workshop-like: re-roda traces antigos              │
│ Se novo output diverge: alerta                     │
└────────────────────────────────────────────────────┘
```

---

## 📦 IMPLEMENTAÇÃO

### Skill 1: `agent-eval` (AINDA NÃO TENHO)

```python
# scripts/agent_eval.py — Scora output do agente
# Baseado em JudgmentLabs pattern

from dataclasses import dataclass
from typing import Optional
import json
import sqlite3
import os

HERMES_HOME = os.environ.get('HERMES_HOME', os.path.expanduser('~/.hermes'))
STATE_DB = os.path.join(HERMES_HOME, 'state.db')

@dataclass
class EvalResult:
    score: int  # 0-100
    factual: int  # 0-100
    completeness: int  # 0-100
    style: int  # 0-100
    issues: list[str]
    approved: bool

def eval_output(output: str, expected: Optional[str] = None, agent: str = 'abraao') -> EvalResult:
    """
    Scora output do agente em 3 dimensões.
    
    Args:
        output: texto gerado pelo agente
        expected: output aprovado/referência (opcional)
        agent: nome do agente
    
    Returns:
        EvalResult com scores
    """
    issues = []
    factual = 100
    completeness = 100
    style = 100
    
    # 1. Factual check (básico: sem datas impossíveis, URLs invalidadas)
    if 'TODO' in output or '[REDACTED]' in output:
        factual = 70
        issues.append('output contém placeholder')
    
    # 2. Completeness (output não vazio, tem nexos de informação)
    if len(output) < 50:
        completeness = 30
        issues.append('output muito curto')
    elif len(output) < 200:
        completeness = 70
        issues.append('output curto')
    
    # 3. Style (não tem hifen-en, sem travessões)
    if '—' in output:
        style = 85
        issues.append('usa em-dash (proibido)')
    
    # 4. Diff vs expected (se tiver referência)
    if expected:
        from difflib import unified_diff
        diff = list(unified_diff(expected.splitlines(), output.splitlines(), lineterm=''))
        if len(diff) > 5:
            factual = max(0, factual - 20)
            issues.append(f'diff grande vs expected ({len(diff)} linhas)')
    
    score = (factual + completeness + style) // 3
    approved = score >= 70 and not any(s in ' '.join(issues) for s in ['placeholder', 'em-dash'])
    
    # Armazenar em state.db
    save_eval(output, expected, EvalResult(score, factual, completeness, style, issues, approved), agent)
    
    return EvalResult(score, factual, completeness, style, issues, approved)

def save_eval(output, expected, result, agent):
    """Salva eval em state.db (traces table)."""
    conn = sqlite3.connect(STATE_DB)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS agent_evals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            agent TEXT,
            output TEXT,
            expected TEXT,
            score INTEGER,
            factual INTEGER,
            completeness INTEGER,
            style INTEGER,
            issues TEXT,
            approved INTEGER
        )
    ''')
    conn.execute('''
        INSERT INTO agent_evals (agent, output, expected, score, factual, completeness, style, issues, approved)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (agent, output, expected or '', result.score, result.factual, result.completeness, 
          result.style, json.dumps(result.issues), int(result.approved)))
    conn.commit()
    conn.close()

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print('Uso: agent_eval.py <output.md> [expected.md]')
        sys.exit(1)
    output = open(sys.argv[1]).read()
    expected = open(sys.argv[2]).read() if len(sys.argv) > 2 else None
    result = eval_output(output, expected)
    print(f'Score: {result.score}/100 (factual={result.factual}, completeness={result.completeness}, style={result.style})')
    print(f'Approved: {result.approved}')
    for issue in result.issues:
        print(f'  - {issue}')
```

### Skill 2: `self-learning-loop` (Sylph pattern)

```python
# scripts/self_learn.py — Diffs output vs aprovado, aprende regras
# Baseado em Sylph's self-improvement

import sqlite3
import os
import difflib
from pathlib import Path

HERMES_HOME = Path(os.environ.get('HERMES_HOME', os.path.expanduser('~/.hermes')))

def self_learn(task_id: int, approved_text: str, agent: str = 'abraao'):
    """
    Compara output aprovado vs output gerado.
    Se diff revela padrão, aprende e atualiza skill.
    
    Args:
        task_id: ID da task em state.db
        approved_text: texto que Pablo aprovou (versão final)
        agent: nome do agente que gerou output
    """
    # 1. Pegar output original do state.db
    conn = sqlite3.connect(HERMES_HOME / 'state.db')
    row = conn.execute(
        'SELECT output FROM agent_evals WHERE id = ?', (task_id,)
    ).fetchone()
    if not row:
        return {'error': 'task não encontrada'}
    
    original = row[0]
    conn.close()
    
    # 2. Diff
    diff = list(difflib.unified_diff(
        original.splitlines(), approved_text.splitlines(),
        fromfile='generated', tofile='approved',
        lineterm=''
    ))
    
    if len(diff) < 3:
        return {'learned': False, 'reason': 'sem diferenças'}
    
    # 3. Categorizar diffs
    lines_added = [l[1:] for l in diff if l.startswith('+')]
    lines_removed = [l[1:] for l in diff if l.startswith('-')]
    
    insights = []
    
    # Heurísticas (estilo Sylph)
    if any('—' in l for l in lines_removed):
        insights.append({
            'type': 'style',
            'rule': 'Evitar em-dash (—) — Pablo prefere hífen (-) ou ponto',
            'action': 'add_to_preferencias'
        })
    
    if any(len(l) > 500 for l in lines_removed):
        insights.append({
            'type': 'completeness',
            'rule': 'Cortar paragrafos longos (>500 chars) — Pablo prefere conciso',
            'action': 'add_to_preferencias'
        })
    
    if any('```' in l for l in lines_added) and not any('```' in l for l in lines_removed):
        insights.append({
            'type': 'format',
            'rule': 'Adicionar mais code blocks — ajuda visualização',
            'action': 'add_to_skill_rules'
        })
    
    # 4. Salvar lições no mem0 (vetorizada)
    for insight in insights:
        save_lesson_to_mem0(insight, agent)
    
    # 5. Atualizar MEMORY.md (camada L1)
    update_memory_md(insights)
    
    return {
        'learned': True,
        'diffs': len(diff),
        'insights': insights
    }

def save_lesson_to_mem0(insight, agent):
    """Salva insight no mem0 (vetorizada)."""
    import urllib.request
    import json
    
    content = f"{insight['type']}: {insight['rule']}"
    
    try:
        req = urllib.request.Request(
            'http://localhost:8765/memory/add',
            method='POST',
            headers={'Content-Type': 'application/json'},
            data=json.dumps({
                'agent': f'{agent}-self-learn',
                'content': content,
                'metadata': {'type': 'self_learn', 'insight_type': insight['type']}
            }).encode()
        )
        urllib.request.urlopen(req, timeout=5)
    except Exception as e:
        print(f'WARN: mem0 falhou: {e}')

def update_memory_md(insights):
    """Atualiza MEMORY.md com novas regras aprendidas."""
    memory_path = HERMES_HOME / 'MEMORY.md'
    if not memory_path.exists():
        return
    
    content = memory_path.read_text()
    new_rules = []
    
    for insight in insights:
        if insight['action'] == 'add_to_preferencias':
            rule_line = f"- PREF: {insight['rule']}"
            if rule_line not in content:
                new_rules.append(rule_line)
    
    if new_rules:
        new_section = '\n\n## Self-learned (%s)\n' % __import__('datetime').date.today()
        new_section += '\n'.join(new_rules)
        memory_path.write_text(content.rstrip() + new_section)

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 3:
        print('Uso: self_learn.py <task_id> <approved.md>')
        sys.exit(1)
    approved = open(sys.argv[2]).read()
    result = self_learn(int(sys.argv[1]), approved)
    print(json.dumps(result, indent=2, ensure_ascii=False))
```

### Skill 3: `agent-trace` (observability simples)

```python
# scripts/agent_trace.py — Tracing simples (vs AgentOps/Judgeval)
# Salva cada tool call + tempo + tokens estimados em state.db

import sqlite3
import os
import time
import json
import functools
from pathlib import Path

HERMES_HOME = Path(os.environ.get('HERMES_HOME', os.path.expanduser('~/.hermes')))
STATE_DB = HERMES_HOME / 'state.db'

def trace_tool(tool_name: str):
    """Decorator: traceia functions (tool calls)."""
    def decorator(fn):
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            start = time.time()
            result = fn(*args, **kwargs)
            duration = time.time() - start
            
            # Salvar trace
            conn = sqlite3.connect(STATE_DB)
            conn.execute('''
                CREATE TABLE IF NOT EXISTS agent_traces (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
                    tool TEXT,
                    args TEXT,
                    duration_ms INTEGER,
                    result_size INTEGER,
                    agent TEXT DEFAULT 'abraao'
                )
            ''')
            conn.execute('''
                INSERT INTO agent_traces (tool, args, duration_ms, result_size)
                VALUES (?, ?, ?, ?)
            ''', (tool_name, json.dumps(str(args))[:500], int(duration * 1000), 
                  len(str(result)) if result else 0))
            conn.commit()
            conn.close()
            
            return result
        return wrapper
    return decorator

# Exemplo de uso
@trace_tool('brain-lookup')
def brain_lookup(query):
    # ... função real
    pass

if __name__ == '__main__':
    # Stats: top tools, avg duration, total calls
    conn = sqlite3.connect(STATE_DB)
    rows = conn.execute('''
        SELECT tool, COUNT(*) as calls, AVG(duration_ms) as avg_ms, 
               SUM(duration_ms) as total_ms
        FROM agent_traces 
        GROUP BY tool 
        ORDER BY calls DESC
        LIMIT 10
    ''').fetchall()
    
    print('Tool Usage Stats:')
    for tool, calls, avg_ms, total_ms in rows:
        print(f'  {tool:30s} {calls:4d} calls  avg={avg_ms:.0f}ms  total={total_ms}ms')
    conn.close()
```

---

## 🔄 FLUXO COMPLETO (dragada Sylph + Workshop)

### Ciclo 1: Task chega
```bash
# Hook pre-task dispara
hook_pre_task → trace_start + mem0 lookup

# Agente executa
agente gera output usando skill

# Hook post-task dispara
hook_post_task → trace_end + agent_eval.py scores output

# Agente mostra output pro Pablo
output_score = 75/100 (ok, issues: ['em-dash'])
```

### Ciclo 2: Pablo edita/aprova
```bash
# Pablo edita output (remove em-dash, corta paragrafo)
# Approva

# Self-learning dispara
self_learn.py task_id approved.md

# Detecta padrão: em-dash removido 3x
# Salva lição em mem0: "Pablo prefere hífen"
# Atualiza MEMORY.md: "- PREF: evitar em-dash"
# Reescreve regra em skill se for persistente
```

### Ciclo 3: Próxima task
```bash
# Hook pre-task dispara
# mem0 search retorna: "Pablo prefere hífen que em-dash"

# Agente usa regra aprendida
output gerado SEM em-dash

# Eval score = 95/100
# Approvado sem diffs
# Self-learn: nenhuma regra nova (nada a aprender)
```

---

## 📊 COMO APLICAR NOS TEMPLATES

Pra OmniQI, Neemias, Solfortes (todos agentes da frota):

### Template alterações (repo privado `omniqi-trader-agent`)

| Arquivo | O que adicionar |
|---|---|
| `/setup.sh` | Baixar `agent_eval.py`, `self_learn.py`, `agent_trace.py` |
| `/skills/agent-eval/SKILL.md` | Skill nova (eval + self-learn) |
| `/hooks/post-task/handler.py` | Adicionar call `eval_output()` |
| `/hooks/session-end/handler.py` | Adicionar `self_learn()` se houver diffs |
| `config/openclaw.json` | Adicionar `eval_enabled: true` |

### Pra Abraão (eu mesmo)
1. Instalar `agent_eval.py` em `~/.hermes/workspace/scripts/`
2. Patch `post-task/handler.py` pra chamar eval
3. Patch `session-end/handler.py` pra chamar self_learn

---

## 🎯 QUANDO USAR O QUE

| Cenário | Ferramenta |
|---|---|
| **Eval quality de output** | `agent_eval.py` (Judgeval pattern) |
| **Aprender com edições do Pablo** | `self_learn.py` (Sylph pattern) |
| **Observar cada tool call** | `agent_trace.py` (AgentOps pattern) |
| **Replay de traces** | (futuro: local-replay como Workshop) |
| **Regression tests** | (`_examples/` + re-run) |
| **Dashboard visual** | (futuro: Vercel + Next.js) |

---

## 📚 References

- **Sylph** (YC X25) — github.com/getnao/sylph
- **JudgmentLabs/judgeval** — github.com/JudgmentLabs/judgeval
- **AgentOps** — github.com/AgentOps-AI/agentops
- **Future AGI** — github.com/future-agi/future-agi
- **Raindrop Workshop** — github.com/raindrop-ai/workshop
- **Trulens** — github.com/truera/trulens

---

## ⚠️ O que NÃO copiar

| Item | Por que não |
|---|---|
| **Workshop install** (`curl ... \| bash`) | Precisa de binary `raindrop` instalado |
| **Judgeval SDK** | Precisa de JUDGMENT_API_KEY (custo) |
| **AgentOps cloud** | SaaS (custa) |
| **Future AGI cloud** | SaaS (custa) |

**Nós faremos LOCAL** (state.db + mem0 + Qdrant) — zero custo, sem API externa.

---

**próximo:** implementar `agent_eval.py` + `self_learn.py` + `agent_trace.py` no Abraão e nos templates OmniQI.