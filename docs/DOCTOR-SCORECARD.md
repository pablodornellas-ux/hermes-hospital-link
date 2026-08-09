# Doctor da Fabrica - Scorecard de Recursos Vitais

> Diagnosticar todos os agentes da Fabrica vs 26 recursos vitais.
> Base: o que Abraao (Orquestrador/Guardian) tem instalado.
> Atualizado: 2026-08-09 (E-017 auditado por Claude Code, 5 rounds).

## 26 Recursos Vitais (todo agente deve ter)

### L1 - Identidade (4 itens)
- [ ] MEMORY.md (memoria injetada todo turno)
- [ ] USER.md (preferencias do operador)
- [ ] SOUL.md (identidade/papel do agente)
- [ ] AGENTS.md (regras de orquestracao)

### L2-L4 - Memoria (3 itens)
- [ ] mem0-server (localhost:8765 + Qdrant Cloud)
- [ ] state.db (FTS5 sessions, WAL mode)
- [ ] brain_v2.db (licoes FTS5) — INTERNO apenas

### L5-L7 - Conhecimento (3 itens)
- [ ] skills/ (anti-amnesia + agent-self-improvement + boundary + pre-create-check)
- [ ] hooks/ (pre-task + post-task + session-end + pre-llm)
- [ ] workspace/scripts/ (watchdog + backup + finops + boundary-guard + eval + self_learn + trace)

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

### H17-H22 - Operacional/Seguranca (6 itens)
- [ ] H17 watchdog.sh (liveness 8 checks)
- [ ] H18 backup-vitals.sh (backup diario state.db + brain + MEMORY)
- [ ] H19 secret-scan (agent_eval detecta secrets no output)
- [ ] H20 retry/backoff (self_learn retry 3x)
- [ ] H21 WAL mode (state.db journal_mode=wal)
- [ ] H22 LGPD (boundary-guard.py + CPF/CNPJ redaction)

## Classificacao Boundary L043+

| Tipo | Agentes | Acesso |
|------|---------|--------|
| **INTERNO** | Abraao, OmniQI | compartilha TUDO |
| **EXTERNO** | Augustus, Solfortes, Neemias | SO open-source (repo publico) |

## Diagnosticos da Frota (09-08-2026)

### Abraao Local (Orquestrador/Guardian) - 26/26 OK (100%)
| Item | Status |
|------|--------|
| L1 MEMORY/USER/SOUL/AGENTS | OK |
| L2 mem0 (:8765) | OK |
| L3 state.db (112MB, WAL) | OK |
| L4 brain_v2.db (28KB, 8 licoes) | OK |
| L5 skills (190) | OK |
| L6 hooks (9) | OK |
| L7 scripts (24) | OK |
| H1-H8 scripts | OK |
| H9-H12 skills vitais | OK |
| H13-H16 orquestracao | OK |
| H17 watchdog (7/8) | OK |
| H18 backup-vitals | OK |
| H19 secret-scan | OK |
| H20 retry/backoff | OK |
| H21 WAL | OK |
| H22 LGPD (boundary-guard) | OK |

### Augustus (Diretor Solfortes) - EXTERNO - 26/26 vitais OK
| Item | Status |
|------|--------|
| L1 SOUL/AGENTS | OK (MEMORY removido = externo) |
| L3 state.db (882MB, WAL) | OK |
| L4 brain_v2.db | REMOVIDO (externo) |
| H17 watchdog | OK |
| H18 backup-vitals | OK |
| H22 boundary-guard | OK |

### Neemias (Lab Anderson) - EXTERNO - 0/26 (agente NU)
| Item | Status |
|------|--------|
| Hermes v0.18.2 | 3 releases atrasado |
| SO tem config.yaml | Tudo falta |
| Template open-source | Script pronto (neemias-vital-resources.sh) |

### OmniQI (Trader) - INTERNO - Pendente
| Item | Status |
|------|--------|
| Acesso | Outro PC (Tailscale) |
| Diagnostico | Pendente |
