---
name: post-update-hygiene
description: "DEPOIS de update: roda dedup, valida sintaxe, atualiza registry. Limpa arquivos velhos e evita usar info desatualizada."
version: 1.0.0
---

# Post-Update Hygiene

> **Pablo cobrou (2026-08-08):** "qnd mudar ou corrigir ou atualizar algo ele higienizar arquivos, dados, tools e outros para não ficar alucinando usando coisas velhas q foram atualizada ou corrigidas"

## 🎯 Quando usar

- **DEPOIS de qualquer update/criação** (write_file, patch, edit)
- Quando você mudou `.env`, `config.yaml`, `SOUL.md`, scripts
- Quando você publicou nova versão no GitHub
- Quando você mudou uma skill ou hook
- Quando a `session-snapshot.py` foi salva

## 📋 Workflow (automático via hook)

Quando o hook `post-update-hygiene` dispara:

```python
# 1. Se for SKILL.md ou memory file, rodar memory-purify
if target has 'SKILL' OR 'memory':
    run memory-purify.py --dry-run
    # Se achou duplicatas, perguntar: --fix ou skip?

# 2. Se for script, validar compilação
if target ends with '.py':
    run py_compile.compile(target)
    # Se falhou: reportar erro (NÃO bloqueia)

# 3. Se for SKILL.md, validar frontmatter
if target == 'SKILL.md':
    check first line == '---'
    check name: / description: present
    # Se faltando: reportar (NÃO bloqueia)
```

## 🚨 Problema resolvido

| Problema | Antes | Agora |
|---|---|---|
| Memória desatualizada | Agente usava info velha | Hook roda memory-purify --dry-run |
| Skill quebrada (sem frontmatter) | Passava despercebido | Hook valida primeira linha |
| Script com syntax error | Quebrava silenciosamente | Hook valida py_compile |
| Tools/scripts obsoletos | Continham refs antigas | Hook reporta e alerta |

## 🔧 Como o hook tá wired

```yaml
# ~/.hermes/hooks/post-update-hygiene/HOOK.yaml
name: post-update-hygiene
description: Higieniza após update
events:
  - agent:end
  - command:end
```

## 📊 Output esperado

```
[POST-HYGIENE] Higienizando após update: scripts/auto-update.py
  [OK] Python compila OK
  [INFO] memory-purify detectou 0 duplicatas
  [OK] Higiene completa
```

## 🚫 Anti-patterns (o que NÃO fazer)

- ❌ Update sem rodar hygiene (acumula lixo)
- ❌ Ignorar warnings de py_compile (script pode quebrar)
- ❌ Manter skills sem frontmatter (perde visibilidade)
- ❌ Usar info velha de MEMORY.md (alucina)

## 📚 References

- memory-purify.py (deduplica lições)
- harmonize_memory.py (check L1-L7)
- memory-smart-add.py (dedup ao adicionar)
- Hooks: pre-create (anti-dup), post-update-hygiene (cleanup), pre-task (lookup)