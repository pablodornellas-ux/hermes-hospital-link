---
name: dedupe
description: "Acha duplicatas em mem0 + filesystem + skills. Anti-amnesia operacional. 3 sub-agents paralelos."
version: 1.0.0
---

# Dedupe — Achar Duplicatas em TODA Memória

> **Inspirado em:** `anthropics/claude-code/.claude/commands/dedupe.md` (9.9k⭐ diet103 showcase)
> **Por que:** Pablo cobrou 2026-08-08 "vc esquece de usar o q vc tem" — duplicatas fazem eu alucinar.

## 🎯 Quando usar

- A cada **2 semanas** (limpeza preventiva)
- Quando o agente dá **resposta conflitante** (pode ser duplicata)
- Antes de **update grande** (não criar mais duplicatas)
- Quando **MEMORY.md satura** (muitos lances)
- Quando o **score mem0 está baixo** (deduplica)

## 📋 Workflow (3 sub-agents paralelos)

### 1. **Agent A — filesystem dedup**
- Escaneia `~/.hermes/templates/`, `~/.hermes/skills/`, `~/.hermes/workspace/scripts/`
- Procura arquivos com **mesmo basename** OU **hash similar** (>80%)
- Lista candidatos: `[file1, file2, ...]`
- Reporta: ação recomendada (merge / deletar / manter)

### 2. **Agent B — mem0 dedup**
- Chama `/memory-purify.py --dry-run`
- Lista grupos de duplicatas
- Reporta: top 10 mais relevantes

### 3. **Agent C — semantic dedup**
- Pega 10 lições random do mem0
- Pergunta ao LLM: "essas 2 são a mesma ideia?"
- Reporta: pares semanticamente similares

## 🔧 Implementação

```bash
# Quando invocado
~/.hermes/workspace/scripts/dedupe.sh

# Ou manual
python ~/.hermes/workspace/scripts/memory-purify.py --dry-run
find ~/.hermes -name "*.md" -type f | xargs md5sum | sort | uniq -w32 -d
```

## 📊 Output esperado

```
=== DEDUPE REPORT ===
[filesystem] 0 duplicatas exatas
[filesystem] 3 candidatos a merge (recomendo revisar manualmente)
[mem0] 79 grupos de duplicatas detectados
[mem0] 75 marcados como superseded
[mem0] 4 pendentes
[semantic] 2 pares similares (ex: L089 ≡ L015)

DECISÃO: aplicar --fix? (Y/n)
```

## 🛠️ Stack usado

- **filesystem**: `find`, `md5sum`, `sort`, `uniq`
- **mem0**: `memory-purify.py --dry-run` + `mem0_search` (já temos)
- **semantic**: chamar `hermes agent` com prompt "essas 2 são a mesma?"

## 🚫 Anti-patterns

- ❌ Rodar dedupe sem antes ter hospital rodando
- ❌ Confiar em hash só (precisa semantic também)
- ❌ Deletar sem backup (sempre superseded primeiro)
- ❌ Dedup de skills/scripts (são estruturais, não conteúdo)

## 📚 References

- [Claude Code dedupe command](https://github.com/anthropics/claude-code/blob/main/.claude/commands/dedupe.md)
- [memory-purify.py] (script local, 10/10 OK validado 08-08)
- [diet103 showcase](https://github.com/diet103/claude-code-infrastructure-showcase) (9.9k⭐)