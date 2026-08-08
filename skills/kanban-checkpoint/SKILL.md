---
name: kanban-checkpoint
description: "Kanban + checkpoint nativos do Hermes-Agent. Use em QUALQUER subtarefa complexa pra evitar perder contexto. Anti-fragmentação operacional."
version: 1.0.0
---

# Kanban + Checkpoint (Hermes-Agent nativo)

## Fontes oficiais
- Kanban: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban-tutorial.md
- Checkpoint: https://hermes-agent.nousresearch.com/docs/user-guide/checkpoints-and-rollback.md

## Setup (1x por agente)

```bash
hermes kanban init
hermes dashboard  # abre http://127.0.0.1:9119

# Em config.yaml (~/.hermes/config.yaml):
# checkpoints:
#   enabled: true

hermes chat --checkpoints  # habilita rollback
```

## Comandos essenciais

```bash
# Kanban
hermes kanban create "subtarefa X" --assignee <persona>
hermes kanban decompose <id>    # auto fan-out
hermes kanban complete <id>
hermes kanban block <id> --reason "..."
hermes kanban heartbeat

# Checkpoint (slash commands in-session)
/rollback          # lista todos
/rollback 3        # volta 3 turnos
/rollback diff 5   # preview
/rollback 3 <file> # restaura 1 arquivo

# CLI fora da sessao
hermes checkpoints status
hermes checkpoints prune
```

## Quando USAR (regra L143 inversa)

L143: "nao ler arquivo 2x" → busca LKP.

Aqui e **inversa**: se a conversa entra em subthread ou voce nao sabe onde esta:

1. **PARA**
2. **Olha kanban** (`hermes kanban list`)
3. **Le CHECKPOINT.md** (snapshot atual)
4. **Resume** com confianca

**Pablo/usuario nao fica mais perdido.**

## Anti-fragmentacao (regra dura)

SE uma tarefa tem >3 subtarefas estimadas:

1. `hermes kanban create <task>`
2. `hermes kanban decompose <id>` (auto fan-out)
3. Worker herda card de cada subtarefa
4. Cada worker marca done ou block ao final
5. Usuario visualiza dashboard em tempo real

## Por que importa

Sem kanban + checkpoint, o agente:

- Perde contexto em tasks complexas
- Usuario nao ve o que ta rolando em tempo real
- Operacoes destrutivas (delete, reset) sem undo
- Auto-decompose nao acontece → agent faz 1 coisa de cada vez

Com kanban + checkpoint ativados:

- Agente tem 6 colunas visuais (Triage → Done)
- Usuario ve dashboard em http://127.0.0.1:9119/kanban
- Agente volta atras se errar (`/rollback N`)
- Auto-decomposer divide tasks complexas em fan-out
