---
name: memory-layer-architecture
description: Arquitetura de memória em camadas do Hermes-agent — usado pelo Doctor pra auditar e pelo agente pra diagnosticar gaps. L1 (built-in MEMORY.md/USER.md) + L2 (mem0/MemMachine providers) + L3 (state.db sessions) + L4 (skills filesystem) + L5 (cold cloud). Inclui opções validadas em projetos oficiais do GitHub (MemMachine, Memoir).
---

# Memory Layer Architecture (Hermes-agent)

> **Fonte oficial Hermes-agent:** https://github.com/NousResearch/hermes-agent
> **Projetos validados no GitHub (alternativas robustas):**
> - [MemMachine](https://github.com/MemMachine/MemMachine) — 3.3k⭐ — L2 universal
> - [Memoir](https://github.com/zhangfengcdt/memoir) — 604⭐ — L1 Git-like versioned

## 🎯 Camadas oficiais (5)

### L1 — Built-in (sempre presente)
- **`MEMORY.md`** — conhecimento persistente do agente
- **`USER.md`** — perfil do owner
- **`SOUL.md`** — identidade da persona
- **`AGENTS.md`** — regras do projeto

**Threshold oficial:** `config.yaml` → `memory.memory_char_limit: 2200`

**Risco de esgotamento:** ⚠️ **ALTO** se usado sem controle. **Solução:** Memoir (Git-like version control do MEMORY.md — commit, blame, rollback)

### L2 — Providers opcionais
- **`mem0`** — memória semântica persistente (via Qdrant Cloud) — **built-in Hermes-agent**
- **`MemMachine`** (3.3k⭐, MIT-ish) — Episodic + Profile + Working memory — **alternativa robusta**
- **`Qdrant`** — vector store
- **8 providers oficiais** documentados em `docs/`

**Risco de esgotamento:** 🟡 Médio (depende do provider). **Solução:** MemMachine sobrevive restarts + model changes (3.3k⭐ e MCP nativo pro Hermes-agent)

### L3 — Sessions (state.db)
- **74MB de sessões** (típico após 6+ meses)
- Schema em `gateway/session.py` (~1444 linhas)
- Compactação: `compression.micro_compact: true` (off by default)
- WAL checkpoint quando > 50MB

**Risco de esgotamento:** ⚠️ **ALTO** sem limpeza. **Solução:** VACUUM regular + pruning de sessions > 90 dias

### L4 — Skills filesystem
- **`~/.hermes/skills/*/SKILL.md`** — 41 built-in + custom
- Lidos a cada invocação (latência crítica)
- Cada skill = 1+ `SKILL.md` + scripts

**Risco de esgotamento:** 🟢 Baixo (filesystem). **Solução:** versionar via Git

### L5 — Cold storage
- **Backups** (`workspace/backups/*.tar.gz`)
- **Auto-dream** cycles (consolidação noturna)
- **Cloud sync** (Firebase/GCS opcional)

**Risco de esgotamento:** 🟢 Baixo. **Solução:** rotação de backups + cloud sync

## 🔍 Doctor checks (01-memory.sh)

```bash
# MEMORY.md existe? >= 500 bytes
# USER.md existe? >= 200 bytes
# state.db size < 80MB?
```

## 🛠️ Como adicionar L2 robusto (MemMachine)

MemMachine (3.3k⭐, open-source) é a **alternativa mais sólida** ao mem0:
- **MCP server nativo** — integra direto com Hermes-agent
- **Episodic + Profile + Working memory** em 1 solução
- **Sobrevive restarts** + mudanças de modelo

```bash
# Install
pip install memmachine-client

# Ou Docker
docker pull memmachine/memmachine

# Configurar no Hermes-agent
# config.yaml → mcp_servers.memmachine: { ... }
```

## 🛠️ Como versionar L1 (Memoir)

Memoir (604⭐, Apache 2.0) adiciona Git-like versionamento ao MEMORY.md:
- `memoir commit` — salva versão
- `memoir blame` — quem mudou o quê
- `memoir checkout` — rollback

```bash
pip install memoir-ai
```

## 🛠️ Micro-compaction (oficial Hermes-agent)

```yaml
# config.yaml
compression:
  micro_compact: true   # off by default — leia docs/micro-compaction.md antes
```

**Cuidado:** quebra prompt cache prefix toda turn. Trade-off explícito.

## 📋 Profile-based routing (multi-perfil)

```yaml
# config.yaml
profile_routes:
  - name: augustus-solfortes
    platform: telegram
    chat_id: "1970071068"
    profile: augustus-profile
  - name: salomao-diz-a-biblia
    platform: telegram
    chat_id: "-1003914063260"
    profile: salomao-profile
```

Cada perfil = diretório isolado `~/.hermes/profiles/<name>/` com próprio MEMORY.md/USER.md.

## ⚠️ Como prevenir esgotamento (3 políticas)

### Política 1: Eviction priority (o que deletar primeiro)

```
L1 (MEMORY.md) — manual curation only, nunca auto-deletar
L2 (Qdrant/MemMachine) — TTL 90 dias pra episodic, permanente pra profile
L3 (state.db) — VACUUM + sessions pruning a cada 30 dias
L4 (skills) — só remove via GH PR (auditado)
L5 (backups) — rotação automática, manter últimos 30
```

### Política 2: Compression thresholds

| Camada | Quando compactar | Auto? |
|---|---|---|
| MEMORY.md | > 80% (1.76KB) | ✅ via `compression.micro_compact` |
| state.db | > 80MB | ✅ via VACUUM |
| Sessions | > 90 dias sem uso | ✅ via pruning |

### Política 3: Backup antes de limpar

```bash
# Antes de VACUUM, sempre:
cp state.db state.db.bak.$(date +%Y%m%d)
sqlite3 state.db "VACUUM;"
```

## 📖 References (canais oficiais)

- [Hermes Agent repo](https://github.com/NousResearch/hermes-agent)
- [docs/](https://github.com/NousResearch/hermes-agent/tree/main/docs)
- [MemMachine (3.3k⭐)](https://github.com/MemMachine/MemMachine)
- [Memoir (604⭐)](https://github.com/zhangfengcdt/memoir)
- [Discord oficial](https://discord.gg/hermes)

## ⚠️ Quando auditar

Use a skill `doctor-agent` (auto-fix + system-health) pra:
- Verificar se MEMORY.md < 90% do limite
- VACUUM state.db se > 80MB
- Validar que skills estão em L4 filesystem
- Confirmar L2 provider configurado se necessário
- Sugerir MemMachine como upgrade do mem0 (mais robusto)

## 🛠️ Plano de upgrade recomendado

| Hoje | Amanhã | Ganho |
|---|---|---|
| L2 = mem0 + Qdrant Cloud | L2 = **MemMachine** (MCP) | Sobrevive restarts + model changes |
| L1 = MEMORY.md flat | L1 = MEMORY.md **+ Memoir versionamento** | Git-like, rollback, blame |
| L3 = VACUUM manual | L3 = **state.db com TTL auto-prune** | Auto-cleanup de sessions > 90d |
| L5 = backup tar.gz | L5 = **auto-dream + cold storage** | Consolidação noturna |