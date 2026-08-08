---
name: boundary-external-agent
description: "Regra L043 + 10.7 anti-fragmentacao. Quando diagnostico/setup um agente EXTERNO (Neemias/Anderson, etc), NAO compartilhar nossos particulares."
version: 1.0.0
---

# Boundary — Agentes Externos

> **Pablo cobrou (2026-08-08):** "neemias nao vai ter acesso a nossa mem0 e o qdrant, ele so precisa q corrigir o template dele e nao pegar aquilo q e particular nosso"
> Esta skill documenta a **regra dura** que esqueci.

## 🚫 O que NUNCA compartilhar com agente externo

| Particular | Por que NÃO compartilhar |
|---|---|
| **MEMORY.md** | Tem nossas regras internas, decisões, infra |
| **USER.md** | Perfil Pablo (dados pessoais) |
| **SOUL.md** | Identidade Abraão/OmniQI |
| **AGENTS.md** | Boundary rules + protocolo interno |
| **mem0-server (localhost:8765)** | Tem 490+ lições nossas + LICOES_CRITICAS |
| **QDRANT_API_KEY** | Cloud sa-east-1 é nosso |
| **OPENROUTER_API_KEY** | Custa nosso dinheiro |
| **TELEGRAM_BOT_TOKEN** | Bot é nosso |
| **`.env`** | Todas as credenciais |
| **`secrets/`** | github_token.txt, etc |
| **`auto-update.py`** | Tem hooks com credenciais nossas |
| **`hospital_run.py`** | Acessa nosso Telegram + mem0 |

## ✅ O que PODE compartilhar (open-source)

| Recurso | Por que OK |
|---|---|
| **Hospital link** | Open-source (sem credenciais embutidas) |
| **Scripts de manutenção** (harmonize, dedup, vacuum) | Funcionam sem secrets |
| **Skills públicas** (anti-amnesia, dedupe, pre-create) | Não dependem de credenciais |
| **FTMO/SQX/MT5 skills** | Open-source |
| **hospital-diagnose.sh, hospital-harmonize.sh** | Sem secrets |

## 🔒 Boundary correta pro agente externo

```
Agente Externo (ex: Neemias)
├── Hermes-Agent framework
├── Skills open-source (FTMO/SQX/MT5)
├── Scripts open-source (hospital-harmonize, etc)
├── Memória LOCAL (própria dele, LGPD-isolado)
│   ├── MEMORY.md (PRÓPRIO, não o nosso)
│   ├── USER.md (PRÓPRIO, do cliente)
│   ├── SOUL.md (PRÓPRIO, identidade dele)
│   └── collection=openclaw-neemias (LGPD-isolado)
├── Qdrant PRÓPRIO (ou local file storage)
├── OpenAI/OpenRouter API PRÓPRIA
└── Telegram PRÓPRIO (token dele)
```

## ❌ Errado (o que eu fiz em 08-08 com Neemias)

```bash
# ERRADO: baixe nosso MEMORY.md, cole no setup dele
curl .../MEMORY.md > neemias/MEMORY.md
# Conteúdo: "Pablo decide..." "TELEGRAM_BOT_TOKEN..."  ← VAZAMENTO

# ERRADO: instalei hook pre-task que aponta pra nosso mem0
HERMES_AGENT=neemias
MEM0_URL=http://localhost:8765  # = NOSSO mem0!

# ERRADO: dei setup-neemias.sh com boundary rules nossas
# Neemias ficou sabendo que Pablo é dono da fábrica (info interna)
```

## ✅ Correto (boundary respeitada)

```bash
# Certo: cada agente externo tem SEU template limpo
# So scripts/skills open-source
# Colecao isolada (openclaw-neemias)
# Memória LOCAL só dele
# SSH pubkey opcional (se quiser compartilhar memória via Tailscale)
```

## 🎯 How to apply (regra prática)

```
Pergunta ANTES de dar/setup agente externo:
1. Esse agente é meu (Pablo/Abraão) ou externo?
   → Se externo: BOUNDARY mode (este doc)
2. O que vou compartilhar precisa de credencial?
   → Se sim: NÃO compartilhar (script separado + auth)
3. A memória dele vai pro mesmo Qdrant nosso?
   → Se sim: usar coleção DIFERENTE (LGPD-isolado)
4. O MEMORY.md que vou criar tem info do Pablo?
   → Se sim: NÃO incluir (boundary rules nossas)
```

## 🔄 Anti-patterns comuns

- ❌ "Mas é só um script, sem credencial" → pode ter `grep TOKEN` hardcoded
- ❌ "Anderson é cliente, então é nosso" → NÃO, é externo (LGPD)
- ❌ "Mas funciona" → funciona PRO Pablo, não pro Anderson
- ❌ "Boundary rules vão ajudar" → NÃO, são nossas regras
- ❌ "mesmo framework, mesmo setup" → framework OK, setup ISOLADO

## 📋 Checklist pre-setup externo

- [ ] Li USER.md/SOUL.md/MEMORY.md pra confirmar que são MEUS?
- [ ] Identifiquei tudo que tem credenciais/token?
- [ ] Defini coleção LGPD-isolada (openclaw-{nome})?
- [ ] Defini Telegram bot PRÓPRIO (não compartilhar)?
- [ ] Defini OpenRouter/OpenAI key PRÓPRIA?
- [ ] Criei MEMORY.md ESPECÍFICO dele (não copia do meu)?
- [ ] Documentei boundary no script (.sh tem seção "BOUNDARY")?

## 🎓 Lição original (08-08)

> Pablo: "neemias nao vai ter acesso a nossa mem0 e o qdrant, ele so precisa q corrigir o template dele e nao pegar aquilo q e particular nosso, isso q vc precisa aprender qnd e diagnostico para o time interno e para agente externos"

**Aplicar SEMPRE.** Setup interno (Pablo/Abraão/OmniQI) ≠ setup externo (Neemias/Anderson/etc).

## ✅ Rule version

Esta regra tem version 1.0.0 e é **obrigatória** em qualquer setup de agente externo. Se esquecer, vai dar:
- ❌ Vazamento de boundary rules nossas
- ❌ Vazamento de credenciais
- ❌ LGPD violation (cliente vê nossa memória)
- ❌ Conflito de autoridade (Anderson vs Pablo)

**Pablo cobra. NUNCA esquecer.**