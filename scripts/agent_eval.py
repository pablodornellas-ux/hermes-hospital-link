#!/usr/bin/env python3
"""agent_eval.py — Scora output do agente em 3 dimensoes.
Baseado em JudgmentLabs pattern (agent judges).
Zero custo, local, sem API externa.

Uso:
    python agent_eval.py <output.md> [expected.md] [--agent abraao] [--json]
"""
import sqlite3
import os
import json
import re
import sys
from pathlib import Path
from dataclasses import dataclass, asdict
from datetime import datetime

HERMES_HOME = Path(os.environ.get('HERMES_HOME', os.path.expanduser('~/.hermes')))
STATE_DB = HERMES_HOME / 'state.db'


@dataclass
class EvalResult:
    score: int          # 0-100 (media)
    factual: int        # 0-100 (sem placeholders, datas imposssiveis, URLs inventadas)
    completeness: int   # 0-100 (nao vazio, tem nexos)
    style: int           # 0-100 (sem em-dash, sem jargon, conciso)
    issues: list        # lista de problemas
    approved: bool      # score >= 70 sem issues criticos
    metrics: dict       # dados brutos

    def to_dict(self):
        return asdict(self)


def check_factual(output: str, agent: str = 'abraao') -> tuple[int, list[str]]:
    """Checa se output tem factuais: placeholders, URLs invalidas, datas imposssiveis."""
    issues = []
    score = 100

    # 1. Placeholders
    if '[REDACTED]' in output or 'TODO' in output or '<placeholder>' in output:
        score -= 30
        issues.append('output contem placeholder ([REDACTED]/TODO)')

    # 1b. SECRET SCAN (CLAUDE AUDIT round 2): varre segredos antes de sair
    # Padroes: API keys (sk-...), bearer tokens, passwords, private keys
    secret_patterns = [
        (r'sk-[a-zA-Z0-9]{20,}', 'API key exposta (sk-...)'),
        (r'Bearer\s+[a-zA-Z0-9_.\-]{20,}', 'Bearer token exposto'),
        (r'(?i)password\s*[:=]\s*\S{8,}', 'password em texto plano'),
        (r'-----BEGIN\s+(RSA|EC|OPENSSH|PGP)?\s?PRIVATE\s+KEY-----', 'private key exposta'),
        (r'(?i)(api_?key|secret|token)\s*[:=]\s*[a-zA-Z0-9_\-]{32,}', 'secret em texto plano'),
    ]
    for pattern, label in secret_patterns:
        matches = re.findall(pattern, output)
        if matches:
            score = 0  # CRITICO: segredo exposto = score zero
            issues.append(f'SECRET LEAK: {label} ({len(matches)}x)')
            break  # um ja e critico, nao precisa continuar

    # 1c. LGPD: CPF, email corporativo, telefone BR
    if re.search(r'\b\d{3}\.\d{3}\.\d{3}-\d{2}\b', output):
        score -= 40
        issues.append('CPF exposto (LGPD)')
    if re.search(r'\b[\w.-]+@(gmail|outlook|hotmail|yahoo)\.com\b', output) and agent != 'pablo':
        score -= 15
        issues.append('email pessoal em output')

    # URLs inventadas (http://example.com, https://foo.bar)
    urls = re.findall(r'https?://[^\s\)]+', output)
    suspicious_urls = [u for u in urls if any(x in u for x in ['example.com', 'foo.bar', 'your-domain', 'placeholder'])]
    if suspicious_urls:
        score -= 20
        issues.append(f'URLs suspeitas: {suspicious_urls[:3]}')

    # Datas imposssiveis (ano futuro >2030 ou muito antigo <2019)
    years = re.findall(r'\b(20\d{2})\b', output)
    bad_years = [y for y in years if int(y) > 2030 or int(y) < 2019]
    if bad_years:
        score -= 15
        issues.append(f'datas suspeitas: {bad_years}')

    # M-004: 0 bytes = nao tenho garantia
    if len(output.strip()) == 0:
        score = 0
        issues.append('output VAZIO (M-004)')

    return max(0, score), issues


def check_completeness(output: str, expected: str = None) -> tuple[int, list[str]]:
    """Checa se output e completo o suficiente."""
    issues = []
    score = 100
    chars = len(output.strip())

    if chars == 0:
        return 0, ['output vazio']
    if chars < 50:
        score = 30
        issues.append(f'output muito curto ({chars} chars)')
    elif chars < 200:
        score = 70
        issues.append(f'output curto ({chars} chars)')

    # Se tem expected, checa cobertura
    if expected:
        expected_keywords = set(expected.lower().split())
        output_lower = output.lower()
        missing = [w for w in expected_keywords if len(w) > 4 and w not in output_lower]
        if missing:
            coverage = 1 - (len(missing) / max(1, len(expected_keywords)))
            score = int(score * coverage)
            issues.append(f'{len(missing)} palavras esperadas ausentes')

    return max(0, score), issues


def check_style(output: str) -> tuple[int, list[str]]:
    """Checa estilo: em-dash, jargon, concisao."""
    issues = []
    score = 100

    # Em-dash (Pablo prefere hifen)
    em_dash_count = output.count('\u2014')  # —
    if em_dash_count > 0:
        score -= 10 * min(em_dash_count, 3)
        issues.append(f'em-dash (—) usado {em_dash_count}x (Pablo prefere hifen)')

    # Jargon leak (log-style: "OK:", "DONE", "ERR:") — so no inicio de linha
    jargon = re.findall(r'^(OK:|DONE|ERR:|FAIL|PASS|SKIP)\b', output, re.MULTILINE)
    if jargon:
        score -= 5 * min(len(jargon), 3)
        issues.append(f'jargon de log: {jargon[:3]}')

    # Muito longo (>5000 chars = deveria ser resumido)
    if len(output) > 5000:
        score -= 10
        issues.append(f'output muito longo ({len(output)} chars)')

    # Repeticao excessiva
    words = output.lower().split()
    if words:
        from collections import Counter
        common = Counter(words).most_common(1)[0]
        if common[1] > len(words) * 0.1:
            score -= 5
            issues.append(f'repeticao excessiva: "{common[0]}" {common[1]}x')

    return max(0, score), issues


def eval_output(output: str, expected: str = None, agent: str = 'abraao') -> EvalResult:
    """Scora output em 3 dimensoes + salva em state.db."""
    factual_score, factual_issues = check_factual(output, agent)
    completeness_score, completeness_issues = check_completeness(output, expected)
    style_score, style_issues = check_style(output)

    all_issues = factual_issues + completeness_issues + style_issues
    score = (factual_score + completeness_score + style_score) // 3

    # Issues criticos = nao approved
    critical = any('placeholder' in i or 'vazio' in i or 'VAZIO' in i for i in all_issues)
    approved = score >= 70 and not critical

    metrics = {
        'chars': len(output),
        'urls': len(re.findall(r'https?://', output)),
        'em_dashes': output.count('\u2014'),
        'lines': output.count('\n') + 1,
    }

    result = EvalResult(
        score=score,
        factual=factual_score,
        completeness=completeness_score,
        style=style_score,
        issues=all_issues,
        approved=approved,
        metrics=metrics
    )

    # Salvar em state.db
    try:
        save_eval(output, expected or '', result, agent)
    except Exception as e:
        print(f'WARN: nao salvou eval em state.db: {e}', file=sys.stderr)

    return result


def save_eval(output: str, expected: str, result: EvalResult, agent: str):
    """Salva eval em state.db (tabela agent_evals)."""
    conn = sqlite3.connect(str(STATE_DB))
    conn.execute('''
        CREATE TABLE IF NOT EXISTS agent_evals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            agent TEXT,
            output TEXT,
            expected TEXT,
            score INTEGER,
            factual INTEGER,
            completeness INTEGER,
            style INTEGER,
            issues TEXT,
            approved INTEGER,
            metrics TEXT
        )
    ''')
    conn.execute('''
        INSERT INTO agent_evals (agent, output, expected, score, factual, completeness, style, issues, approved, metrics)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (agent, output[:5000], expected[:5000], result.score, result.factual,
          result.completeness, result.style, json.dumps(result.issues, ensure_ascii=False),
          int(result.approved), json.dumps(result.metrics)))
    conn.commit()
    conn.close()


def stats():
    """Mostra stats dos evals acumulados."""
    if not STATE_DB.exists():
        print('state.db nao encontrado')
        return

    conn = sqlite3.connect(str(STATE_DB))
    try:
        rows = conn.execute('''
            SELECT agent, COUNT(*) as total,
                   AVG(score) as avg_score,
                   SUM(CASE WHEN approved = 1 THEN 1 ELSE 0 END) as approved_count
            FROM agent_evals
            GROUP BY agent
            ORDER BY total DESC
        ''').fetchall()

        if not rows:
            print('Nenhum eval registrado ainda.')
            return

        print('=== EVAL STATS ===')
        for agent, total, avg, approved in rows:
            print(f'  {agent:20s} {total:4d} evals  avg={avg:.0f}/100  approved={approved}/{total}')

        # Top issues
        all_issues = conn.execute('SELECT issues FROM agent_evals WHERE issues != "[]"').fetchall()
        from collections import Counter
        issue_words = []
        for (issues_json,) in all_issues:
            try:
                for issue in json.loads(issues_json):
                    issue_words.append(issue[:40])
            except:
                pass

        if issue_words:
            print()
            print('Top issues:')
            for issue, count in Counter(issue_words).most_common(5):
                print(f'  {count:3d}x {issue}')

    finally:
        conn.close()


def main():
    args = sys.argv[1:]

    if not args or args[0] == '--stats':
        stats()
        return

    if args[0] in ['-h', '--help']:
        print(__doc__)
        return

    output_file = args[0]
    expected_file = args[1] if len(args) > 1 and not args[1].startswith('--') else None
    agent = 'abraao'
    json_output = False

    for i, arg in enumerate(args):
        if arg.startswith('--agent='):
            agent = arg.split('=', 1)[1]
        elif arg == '--agent' and i + 1 < len(args):
            agent = args[i + 1]  # --agent X (espaco)
        elif arg == '--json':
            json_output = True

    if not os.path.exists(output_file):
        print(f'Erro: arquivo nao encontrado: {output_file}')
        sys.exit(1)

    output = open(output_file, encoding='utf-8').read()
    expected = open(expected_file, encoding='utf-8').read() if expected_file else None

    result = eval_output(output, expected, agent)

    if json_output:
        print(json.dumps(result.to_dict(), indent=2, ensure_ascii=False))
    else:
        print(f'Score: {result.score}/100')
        print(f'  Factual:       {result.factual}/100')
        print(f'  Completeness:  {result.completeness}/100')
        print(f'  Style:         {result.style}/100')
        print(f'  Approved:      {"SIM" if result.approved else "NAO"}')
        if result.issues:
            print(f'  Issues:')
            for issue in result.issues:
                print(f'    - {issue}')


if __name__ == '__main__':
    main()