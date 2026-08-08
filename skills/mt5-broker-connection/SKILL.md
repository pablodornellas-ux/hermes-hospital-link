---
name: mt5-broker-connection
description: "Conecta Hermes-Agent ao broker MT5 (Exness/XM/FTMO) via MetaAPI. Auto-detecta tipo de conta, valida credenciais, configura risk limits."
version: 1.0.0
---

# MT5 Broker Connection

> **Pablo pediu (2026-08-08):** "OmniQI precisa de skill mt5-broker-connection"
> Conecta o Hermes-Agent ao broker MetaTrader 5 via MetaAPI Cloud.

## 🎯 Quando usar

- Setup inicial do agente Trader OmniQI
- Verificar status de conexão MT5
- Trocar de conta (real ↔ demo)
- Resolver problemas de conexão

## 📋 Pré-requisitos

```bash
# .env do agente
METAAPI_TOKEN=eyJ...  # API token de metapi.net
BROKER_ADAPTER=mt5_local
MT5_LOGIN=12345678
MT5_PASSWORD=AbCd123
MT5_SERVER=Exness-MT5Real8

# Opcional (multi-conta)
MT5_ACCOUNTS_REAL=login1:pass1:server1,login2:pass2:server2
MT5_ACCOUNTS_DEMO=logind1:passd1:serverd1
```

## 🔧 Comandos (automatizar)

```python
# Skill: mt5-broker-connection
# Auto-rodar em setup
from metaapi_cloud_sdk import MetaApi

api = MetaApi(token=METAAPI_TOKEN)
account = await api.metatrader_account_api.get_account(account_id=METAAPI_LOGIN)

# 1. Validar conexão
state = account.state  # DEPLOYING, DEPLOYED, UNDEPLOYED, STOPPED
if state != 'DEPLOYED':
    await account.deploy()  # ~30s

# 2. Conectar (streaming)
connection = account.get_rpc_connection()
await connection.connect()
await connection.wait_synchronized()  # ~5-10s

# 3. Verificar conta
info = await connection.get_account_information()
print(f"Balance: {info.balance} {info.currency}")
print(f"Equity: {info.equity}")
print(f"Leverage: {info.leverage}")
print(f"Broker: {info.broker}")
```

## 🚦 Validações obrigatórias

| Check | Esperado |
|---|---|
| `METAAPI_TOKEN` definido | ✅ |
| Token válido (não expirado) | ✅ (testar: `curl -H "Auth-Token: $TOKEN" https://mt-provisioning-api-v1.agiliumtrade.ai/users/current/provisioning-profile`) |
| `BROKER_ADAPTER=mt5_local` | ✅ |
| `MT5_LOGIN` numérico | ✅ |
| `MT5_PASSWORD` correto | ✅ |
| `MT5_SERVER` conhecido | ✅ (Exness-MT5Real8, ICMarkets-Live04, FTMO-Demo) |

## 🚨 Erros comuns + fix

| Erro | Causa | Fix |
|---|---|---|
| `account.state=UNDEPLOYED` | MetaAPI não provisionou | `await account.deploy()` |
| `auth_error` | Token inválido | Gerar novo em metapi.net |
| `connection timeout` | Firewall/proxy | `curl` pro servidor do broker |
| `wrong_password` | Senha errada | Verificar no broker |
| `invalid_account` | Login errado | Confirmar no broker |

## 🛡️ Risk Limits (FTMO/Prop Firm)

```python
# FTMO Challenge 100k
RISK_LIMITS = {
    'max_daily_loss_pct': 5.0,  # 5% per day
    'max_total_loss_pct': 10.0,  # 10% total
    'profit_target_pct': 8.0,  # 8% target phase 1
    'min_trading_days': 4,  # 4 days min
    'leverage': 100,  # 1:100
}

# Apex 50k
RISK_LIMITS_APEX = {
    'max_daily_loss_pct': 2.5,  # 2.5% per day (stricter)
    'max_total_loss_pct': 5.0,
    'profit_target_pct': 6.0,
    'consistency_rule': True,  # no single day >30% of total
}
```

## 📊 Commands to check status

```bash
# Status da conexão
hermes run mt5-broker-connection --status

# Trocar para demo
hermes run mt5-broker-connection --switch=demo

# Ver saldo/equity
hermes run mt5-broker-connection --balance

# Listar posições abertas
hermes run mt5-broker-connection --positions
```

## 🔗 References

- [MetaAPI docs](https://metaapi.cloud/docs/)
- [FTMO challenge rules](https://ftmo.com/en/challenge/)
- [Apex Trader Funding rules](https://apextraderfunding.com/rules)
- [Lido L181-L190](https://github.com/NousResearch/hermes-agent/blob/main/L181-L190) (skill de MT5)

## ✅ Auto-check no boot

```python
# Adicionar em hooks/pre-task/handler.py (custom)
def check_mt5_health():
    if not os.environ.get('METAAPI_TOKEN'):
        return '[WARN] METAAPI_TOKEN nao definido'
    if not os.environ.get('MT5_LOGIN'):
        return '[WARN] MT5_LOGIN nao definido'
    return '[OK] MT5 config presente'
```