# Doctor da Fabrica - Scorecard de Recursos Vitais

> Diagnosticar todos os agentes da Fabrica vs 20 recursos vitais.
> Base: o que Abraao (Guardian) tem instalado.

## 20 Recursos Vitais (todo agente deve ter)

### L1 - Identidade (4 itens)
- [ ] MEMORY.md (memoria injetada todo turno)
- [ ] USER.md (preferencias do operador)
- [ ] SOUL.md (identidade/papel do agente)
- [ ] AGENTS.md (regras de orquestracao)

### L2-L4 - Memoria (3 itens)
- [ ] mem0-server (localhost:8765 + Qdrant Cloud)
- [ ] state.db (FTS5 sessions)
- [ ] brain_v2.db (licoes FTS5)

### L5-L7 - Conhecimento (3 itens)
- [ ] skills/ (anti-amnesia + agent-self-improvement + boundary + pre-create-check)
- [ ] hooks/ (pre-task + post-task + session-end)
- [ ] workspace/scripts/ (agent_eval + self_learn + agent_trace + harmonize + smart-add + purify + snapshot + vacuum)

### H1-H8 - Scripts de Higienizacao (8 itens)
- [ ] agent_eval.py (scora output 0-100)
- [ ] self_learn.py (diff output vs aprovado -> aprende regras)
- [ ] agent_trace.py (tracing tool calls)
- [ ] harmonize_memory.py (check L1-L7)
- [ ] memory-smart-add.py (dedup + versionamento)
- [ ] memory-purify.py (limpa duplicatas)
- [ ] session-snapshot.py (snapshot fim de sessao)
- [ ] state-db-vacuum.py (VACUUM SQLite)

### H9-H12 - Skills Vitais (4 itens)
- [ ] anti-amnesia (anti-esquecimento operacional)
- [ ] boundary-external-agent (L043 LGPD isolado)
- [ ] pre-create-check (verifica antes de criar)
- [ ] agent-self-improvement (eval + self-learn + trace)

### H13-H16 - Orquestracao (4 itens)
- [ ] kanban-checkpoint (gestao de tasks)
- [ ] memory-layer-architecture (L1-L7 documentado)
- [ ] dedupe (remove duplicatas)
- [ ] cron jobs (rotinas agendadas)

## Diagnosticos da Frota (09-08-2026)

### Abraao Local (Guardian) - 18/20 OK (90%)
| Item | Status |
|------|--------|
| L1 MEMORY/USER/SOUL/AGENTS | OK |
| L2 mem0 | OK |
| L3 state.db (112MB) | OK |
| L4 brain_v2.db | FALTA |
| L5 skills (188) | OK |
| L6 hooks (8) | OK |
| L7 scripts (13) | OK |
| H1-H8 scripts | OK |
| H9-H12 skills vitais | OK |
| H13 kanban-checkpoint | OK |
| H14 memory-layer-architecture | OK |
| H15 dedupe | OK |
| H16 cron jobs | OK |

### Augustus (Diretor Solfortes) - 16/20 OK (80%)  
| Item | Status |
|------|--------|
| L1 MEMORY/USER | OK (recem criado 09/08) |
| L1 SOUL/AGENTS | OK (pre-existente) |
| L2 mem0 | PARCIAL (plugin mas sem server) |
| L3 state.db (882MB) | OK |
| L4 brain_v2.db | OK (recem criado 09/08) |
| L5 skills (122) | OK (110 + 7 vitais + 5 arquivadas) |
| L6 hooks (3) | OK (recem criado 09/08) |
| L7 scripts (8) | OK (recem copiado 09/08) |
| H1-H8 scripts | OK |
| H9-H12 skills vitais | OK (4 vitais) |
| H13 kanban-checkpoint | OK |
| H14 memory-layer-architecture | OK |
| H15 dedupe | OK |
| H16 cron jobs | OK (23 jobs) |

### OmniQI (Trader) - DIAGNOSTICO PENDENTE (em outro PC)
- Rodou setup v1 e v2
- Precisa preencher CHECKLIST-OMNIQI.md

### Neemias (BETA) - DIAGNOSTICO PENDENTE (via SSH)
- Acesso via SSH beta@100.103.213.58
- Aguardando diagnostico

### Solfortes - DIAGNOSTICO PENDENTE
- Sem acesso direto
