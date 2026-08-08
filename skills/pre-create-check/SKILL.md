---
name: pre-create-check
description: "ANTES de criar QUALQUER arquivo/skill/script, verifica se ja existe similar. Anti-duplicacao."
version: 1.0.0
---

# Pre-Create Check — Não duplique o que já existe

> **Por que:** Pablo cobrou (2026-08-08) "vc esquece de usar o q vc tem". Esta skill garante que **ANTES de criar**, o agente **confere se já existe**.

## 🎯 Quando usar

SEMPRE que for criar:
- Script (Python, JS, etc)
- Skill (SKILL.md)
- Persona
- Prompt
- Arquivo de config
- Template
- Documento
- Qualquer coisa nova

## 📋 Checklist OBRIGATÓRIO antes de criar

```bash
# 1. Buscar no GitHub (template local)
find ~/.hermes/templates -name "<filename>" 2>/dev/null

# 2. Buscar em skills
ls ~/.hermes/skills/openclaw-imports/ | grep -i <keyword>

# 3. Buscar em scripts
ls ~/.hermes/workspace/scripts/ | grep -i <keyword>

# 4. Buscar no mem0 (RAG)
curl -X POST http://localhost:8765/memory/search \
  -H "Content-Type: application/json" \
  -d '{"agent":"abraao-local","query":"<keyword>","limit":5}'

# 5. Buscar por similaridade (hash)
python memory-purify.py --dry-run
```

## 🚦 Decisão (matrix)

| Resultado | Ação |
|---|---|
| **Arquivo IDÊNTICO existe** | **NÃO criar.** Reusar. |
| **Similar existe (>80% match)** | **Editar existente**, não criar novo |
| **Similar existe (50-80% match)** | Estender existente ou criar versão 2 |
| **Nada similar** | Criar novo, MAS adicionar ao registry |

## 📝 Registry de tudo que existe

```bash
# Listar TUDO que existe (sempre antes de criar)
~/.hermes/workspace/scripts/list-all.sh > /tmp/inventory.txt
```

## 🚫 Anti-patterns

- ❌ "Vou criar um novo script" sem checar antes
- ❌ "Já tem um similar mas vou criar melhor" — **primeiro edite o existente**
- ❌ Duplicar em múltiplos lugares
- ❌ Não atualizar o registry

## 🧠 Quando esquecer

Se você (agente) esqueceu de checar:
1. **`/simplify`** (skill oficial Hermes-Agent) — 4 reviewers paralelos
2. **`memory-purify.py --fix`** — limpa duplicatas automaticamente
3. **`auto-update.py v2`** — preserva customizações

## 📚 References

- **simplify-code** (skill oficial): cleanup paralelo
- **memory-smart-add** (skill nossa): dedup ao adicionar memória
- **auto-update v2** (script nosso): preserva customizações
- L143: "não ler arquivo 2x → busca LKP"

## ✅ Quando você CHAMAR este skill

```bash
hermes run pre-create-check
# OU
hermes chat --skill pre-create-check
```

Output esperado:
```
CHECKING: <keyword>
[1] ~/.hermes/scripts/foo.py  <- match
[2] ~/.hermes/skills/bar/      <- match 80%
[3] GitHub: pablodornellas-ux/hermes-agent-templates

DECISION: REUSAR [1] / EDITAR [2] / CRIAR NOVO
```