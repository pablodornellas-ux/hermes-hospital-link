---
name: pine-script-generator
description: "Gera Pine Script v5 a partir de estratégia SQX/MT5. Auto-traduz indicadores/condições para TradingView. Suporta backtesting + alerts."
version: 1.0.0
---

# Pine Script Generator

> **Pablo pediu (2026-08-08):** "OmniQI precisa de skill pine-script-generator"
> Converte estratégia SQX em Pine Script v5 pra TradingView visual + alerts.

## 🎯 Quando usar

- Validar estratégia SQX em chart visual
- Receber alerts em tempo real (email/webhook/telegram)
- Compartilhar lógica com trader humano
- Backtest no TradingView (visual + rápido)

## 📋 Pipeline

```
[SQX strategy.ex5] → extract conditions → [Pine Script v5] → [TradingView chart]
                                                                  ↓
                                                          [alert → Telegram]
```

## 🔧 Implementação

```python
# Skill: pine-script-generator
import re
from pathlib import Path


def sqx_to_pine(sqx_strategy_path: str) -> str:
    """Converte .mq5/.ex5 em Pine Script v5."""

    # 1. Extrair indicadores/condições do SQX
    indicators = extract_indicators(sqx_strategy_path)
    entries = extract_entry_conditions(sqx_strategy_path)
    exits = extract_exit_conditions(sqx_strategy_path)

    # 2. Mapear para Pine Script
    pine_code = f"""
//@version=5
strategy('{Path(sqx_strategy_path).stem}', overlay=true, ...)

// === Indicadores ===
{map_indicators_to_pine(indicators)}

// === Entry ===
{map_entries_to_pine(entries)}

// === Exit ===
{map_exits_to_pine(exits)}

// === Alertas ===
{generate_alerts(entries, exits)}
"""
    return pine_code


def extract_indicators(sqx_path):
    """Extrai indicadores do .mq5/.ex5."""
    code = Path(sqx_path).read_text()
    indicators = []
    # Padrões comuns em SQX output
    for match in re.finditer(r'i(MA|RSI|ATR|MACD|EMA|SMA)\((\d+)\)', code):
        ind_type, period = match.groups()
        indicators.append({'type': ind_type, 'period': int(period)})
    return indicators


def map_indicators_to_pine(indicators):
    """Mapeia pra Pine Script v5."""
    code = []
    for ind in indicators:
        if ind['type'] == 'MA':
            code.append(f'ema_{ind["period"]} = ta.ema(close, {ind["period"]})')
        elif ind['type'] == 'RSI':
            code.append(f'rsi_{ind["period"]} = ta.rsi(close, {ind["period"]})')
        elif ind['type'] == 'ATR':
            code.append(f'atr_{ind["period"]} = ta.atr({ind["period"]})')
        # ... outros
    return '\n'.join(code)


def generate_alerts(entries, exits):
    """Gera alerts Pine Script + webhook."""
    return f"""
// Alerts (webhook pra Telegram)
alertcondition(longCondition, title='Long Signal', message='{{"side":"long","price":{{close}}}}')
alertcondition(shortCondition, title='Short Signal', message='{{"side":"short","price":{{close}}}}')
"""
```

## 📋 Exemplo: Estratégia XAUUSD

```pine
//@version=5
strategy('XAUUSD_EMA_Cross_50_200', overlay=true, default_qty_type=strategy.percent_of_equity, default_qty_value=10)

// === Indicadores ===
ema_50 = ta.ema(close, 50)
ema_200 = ta.ema(close, 200)
atr_14 = ta.atr(14)

// === Entry ===
longCondition = ta.crossover(ema_50, ema_200)
shortCondition = ta.crossunder(ema_50, ema_200)

if longCondition
    strategy.entry('Long', strategy.long)
    strategy.exit('Long-Exit', from_entry='Long', stop=close - 1.5*atr_14, limit=close + 3*atr_14)

if shortCondition
    strategy.entry('Short', strategy.short)
    strategy.exit('Short-Exit', from_entry='Short', stop=close + 1.5*atr_14, limit=close - 3*atr_14)

// === Alertas (webhook) ===
alertcondition(longCondition, title='Long Signal', message='{"side":"long","price":{{close}}}')
alertcondition(shortCondition, title='Short Signal', message='{"side":"short","price":{{close}}}')
```

## 🔗 Integração com TradingView

```bash
# 1. Gerar Pine Script
python ~/.hermes/skills/pine-script-generator/generate.py \
    --input C:/data/sqx/results/XAUUSD_EMA_Cross.json \
    --output C:/data/sqx/pine/XAUUSD_EMA_Cross.pine

# 2. Upload pro TradingView (manual ou via API)
# TradingView > Pine Editor > paste
```

## 📊 Comandos

```bash
# Gerar Pine Script a partir de SQX
hermes run pine-script-generator --input strategy.ex5 --output strategy.pine

# Validar Pine Script
hermes run pine-script-generator --validate strategy.pine

# Publicar no TradingView (via API + alert webhook)
hermes run pine-script-generator --publish --webhook https://hermes.local/alerts
```

## 🚨 Validações

| Check | Esperado |
|---|---|
| Sintaxe Pine Script v5 | ✅ Compila no TradingView |
| Indicadores suportados | ✅ MA, RSI, ATR, MACD, BB |
| Alerts funcionais | ✅ Webhook → Telegram |
| Backtest visual | ✅ Chart TradingView |
| Timeframes | ✅ 1m, 5m, 15m, 1h, 4h, 1D |

## 🔗 References

- [Pine Script v5 docs](https://www.tradingview.com/pine-script-docs/)
- [TradingView Webhook](https://www.tradingview.com/support/solutions/43000529348-about-webhooks/)
- SQX output format (.mq5)
- L181-L190 (skill MT5 + SQX)