---
name: sqx-backtest-runner
description: "Roda backtests no StrategyQuant X (SQX) local. Auto-detecta estratégias .sqx pendentes, executa BT incremental, captura resultados em schema_omniqi_rrs."
version: 1.0.0
---

# SQX Backtest Runner

> **Pablo pediu (2026-08-08):** "OmniQI precisa de skill sqx-backtest-runner"
> Roda backtests no SQX local seguindo política L345 (incremental, semanal, demo > BT).

## 🎯 Política (L345)

**BT é INCREMENTAL, não bulk.** Demo > BT na precedência.

- **Frequência:** semanal (Sáb 22h via `job_weekly_backtest` Hermes; SQX_Dataquant_WeeklyBT Sáb 8:45 Windows Task)
- **Trigger:** estratégias "a 1 trade de mudar status" via `job_check_degradation` + `strategy_envelope.seq_loss/seq_gain` próximo de threshold 25%
- **Escopo:** incremental do período sem dados (NÃO regenera BT completo)
- **Pré-requisito:** .ex5 + .set salvos por strategy via `compile_all_dataquant` cascade
- **Precedência:** live_trades demo > BT — `job_forward_demo_record` (23:55 daily) usa source live_trades

## 📋 Pré-requisitos

```bash
# .env
SQX_VAULT_KEY=<Fernet key>
SQX_DATA_DIR=C:\data\sqx\incoming
SQX_RESULTS_DIR=C:\data\sqx\results
SQX_BT_TIMEOUT_SEC=3600
```

## 🔧 Comando (automatizar)

```python
# Skill: sqx-backtest-runner
import subprocess
from pathlib import Path
from datetime import datetime, timedelta

def run_weekly_backtest():
    """Roda BT semanal incremental (politica L345)."""

    # 1. Listar strategies "a 1 trade de mudar status"
    candidates = check_degradation_envelope()  # job_check_degradation
    if not candidates:
        log('Nenhuma strategy a 1 trade de mudar status')
        return

    # 2. Para cada candidate, rodar BT incremental
    for strategy_id in candidates:
        since = get_last_bt_date(strategy_id)
        if (datetime.now() - since).days < 7:
            continue  # BT recente, skip

        # 3. .ex5 + .set devem existir (regra L345)
        if not has_ex5_and_set(strategy_id):
            log(f'{strategy_id}: .ex5 ou .set faltando - compile_all_dataquant')
            continue

        # 4. Rodar BT incremental
        cmd = [
            'python', 'C:/data/sqx/scripts/run_bt.py',
            '--strategy', strategy_id,
            '--since', since.isoformat(),
            '--output', f'C:/data/sqx/results/{strategy_id}.json',
            '--timeout', '3600',
        ]
        subprocess.run(cmd, timeout=3700)

        # 5. Atualizar schema_omniqi_rrs
        ingest_bt_results(strategy_id, f'C:/data/sqx/results/{strategy_id}.json')

def check_degradation_envelope():
    """Job check_degradation: strategies a 1 trade de mudar status."""
    import sqlite3
    con = sqlite3.connect('C:/data/sqx/dataquant.db')
    cur = con.execute("""
        SELECT strategy_id
        FROM strategy_envelope
        WHERE ABS(seq_loss - threshold) <= 1
           OR ABS(seq_gain - threshold) <= 1
    """)
    return [r[0] for r in cur.fetchall()]

def has_ex5_and_set(strategy_id):
    """Verifica .ex5 + .set salvos."""
    ex5 = Path(f'C:/data/sqx/mt5/MQL5/Experts/Advisors/{strategy_id}.ex5')
    setf = Path(f'C:/data/sqx/mt5/MQL5/Profiles/Tester/{strategy_id}.set')
    return ex5.exists() and setf.exists()

def ingest_bt_results(strategy_id, json_path):
    """Ingere resultado do BT em schema_omniqi_rrs."""
    import json
    import sqlite3
    with open(json_path) as f:
        data = json.load(f)
    con = sqlite3.connect('C:/data/sqx/dataquant.db')
    con.execute("""
        INSERT OR REPLACE INTO bt_equity_curve (strategy_id, trade_date, cum_pnl, dd_value)
        VALUES (?, ?, ?, ?)
    """, (strategy_id, data['date'], data['cum_pnl'], data['dd']))
    con.commit()
```

## 📅 Cronograma

| Schedule | Comando | Job |
|---|---|---|
| **Sáb 22h** | BT semanal Hermes | `job_weekly_backtest` |
| **Sáb 8:45** | BT Windows Task | `SQX_Dataquant_WeeklyBT` |
| **23:55 diário** | Forward demo | `job_forward_demo_record` |

## ⚠️ Regra E-017 (reviewer)

> "Não inferir features de scheduler sem consultar `hermes_scheduler_jobs.md`"

ANTES de propor BT, **ler**:
- `~/.claude/projects/<proj>/memory/hermes_scheduler_jobs.md`
- `pm2 logs hermes-sqx --lines 500 | grep _ok`
- Cruzar com inventário

## 🚨 Erros comuns

| Erro | Causa | Fix |
|---|---|---|
| BT retorna 0 trades | `.ex5` ou `.set` faltando | `compile_all_dataquant` |
| BT duplica dados | `since` muito antigo | Reduzir janela (incremental) |
| BT demora +2h | Estratégia muito complexa | Filtrar por sharpe >= 1.5 |
| BT sem resultado | SQX não está rodando | Verificar `pm2 status hermes-sqx` |
| Erro no SQX | SQX crash | Log em `C:/data/sqx/logs/` |

## 📊 Métricas esperadas

- **Tempo médio:** 5-10min por strategy
- **Throughput:** ~10 strategies/hora
- **Storage:** ~50MB por strategy (curva equity)
- **Latência update:** <1min (auto-ingest)

## 🔗 References

- L345 (regra de BT incremental)
- L181-L190 (skill MT5 + SQX)
- `hermes_scheduler_jobs.md` (inventário)
- `compile_all_dataquant` (cascata .ex5 + .set)
- `job_check_degradation` (trigger envelope)