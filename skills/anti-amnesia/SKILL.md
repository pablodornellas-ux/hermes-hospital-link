---
name: anti-amnesia
description: "Anti-esquecimento operacional. Pablo cobrou que eu esqueço de usar ferramentas que tenho. ESTA SKILL DOCUMENTA a regra pra não acontecer de novo."
version: 1.0.0
---

# Anti-Amnesia — Não esquecer o que tenho

> **Por que existe:** Pablo (2026-08-08) disse "vc esquece de usar o q vc tem". Esta skill **DOCUMENTA** a regra de uso.

## ⚠️ O que NÃO esquecer

| Ferramenta | Path | Comando | Quando |
|---|---|---|---|
| `memory-save` (lookup) | `~/.hermes/skills/memory-save/scripts/memory-save.py --mode lookup` | ANTES de tarefa |
| `memory-save` (save) | `--mode save` | DEPOIS de aprender algo |
| `harmonize_memory.py` | `~/.hermes/workspace/scripts/harmonize_memory.py --harmonize` | Quando verificar saúde |
| `memory-smart-add.py` | `~/.hermes/workspace/scripts/memory-smart-add.py` | SEMPRE que adicionar memória |
| `memory-purify.py` | `~/.hermes/workspace/scripts/memory-purify.py --fix` | Quando detectar duplicatas |
| `state-db-vacuum.py` | `~/.hermes/workspace/scripts/state-db-vacuum.py` | Quando state.db > 60MB |
| `brain-lookup.mjs` | `~/.hermes/workspace/agents/_shared/brain-lookup.mjs` | ANTES de tarefa |
| `lesson-add-vps.mjs` | `~/.hermes/workspace/scripts/lesson-add-vps.mjs` | DEPOIS de aprender lição |
| `session-snapshot.py` | `~/.hermes/workspace/scripts/session-snapshot.py` | Fim de sessão |
| `kanban` | `hermes kanban` | SEMPRE que >3 subtarefas |
| `checkpoint` | `hermes chat --checkpoints` | SEMPRE em sessão |
| `/rollback` | slash command | Quando errar |
| `pre-task hook` | `~/.hermes/hooks/pre-task/mem0-lookup.py` | Auto ANTES |
| `post-task hook` | `~/.hermes/hooks/post-task/mem0-save.py` | Auto DEPOIS |

## 🎯 Checklist ANTES de cada tarefa não-trivial

```bash
# 1. Tarefa >3 subtarefas? → cria kanban card
hermes kanban list
hermes kanban create "<titulo>" --assignee <persona>

# 2. Auto-decompose se complexa
hermes kanban decompose <id>

# 3. Heartbeat pra manter vivo
hermes kanban heartbeat

# 4. Lookup antes de agir
python ~/.hermes/scripts/memory-save.py --mode lookup --keywords "X Y Z"

# 5. Snapshot ANTES de operação destrutiva
hermes chat --checkpoints
```

## 🎯 Checklist DEPOIS de cada tarefa

```bash
# 1. Marca done
hermes kanban complete <id>

# 2. Salva lição (se aprendeu algo)
python ~/.hermes/workspace/scripts/memory-smart-add.py --rule --title "..." --content "..."

# 3. Session snapshot (fim da sessão)
python ~/.hermes/workspace/scripts/session-snapshot.py --summary "..."
```

## 🧠 Quando PERDER contexto

```bash
# 1. Lista checkpoints
/rollback

# 2. Lista kanban
hermes kanban list

# 3. Lê CHECKPOINT.md
cat ~/.hermes/workspace/CHECKPOINT.md

# 4. Resume com confiança
```

## 🚫 Anti-patterns (o que NÃO fazer)

- ❌ Inventar script sem checar se já existe (grep skills/ primeiro)
- ❌ Releitura de arquivo já lido (M-004 da memória: cache válido)
- ❌ Loop de Read/Edit sem progresso (L143)
- ❌ Criar memória sem dedup (sempre usar memory-smart-add.py)
- ❌ Editar config.yaml Hermes-Agent (refusado por segurança, /hermes config use)
- ❌ Mexer em Augustus/Salomão sem consentimento verbal
- ❌ Gastar BCT sem aprovação Pablo

## 📊 Anti-esquecimento em números

| Antes desta skill | Depois |
|---|---|
| Esquecia memory-save | ✅ Documentado + checklist |
| Esquecia Kanban | ✅ Card ANTES de >3 subtarefas |
| Esquecia /rollback | ✅ Slash command sempre disponível |
| Esquecia dedup | ✅ memory-smart-add.py SEMPRE |
| Esquecia de consultar | ✅ ANTES checklist obrigatório |

## 🔗 References (outras skills complementares)

- `memory-save` (L305) — lookup/save/update
- `memory-layer-architecture` — L1-L7 docs
- `knowledge-digest` — digests semanais
- `kanban-checkpoint` (08-08) — uso do Kanban+Checkpoint

## 📝 Origin

- **Data:** 2026-08-08
- **Por:** Pablo Dornellas (cobrou)
- **Resposta:** SOUL.md + esta skill + checklist em todas as tarefas