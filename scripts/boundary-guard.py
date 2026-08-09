#!/usr/bin/env python3
"""
boundary-guard.py — Hook pre-task anti-leak de dados internos da Fabrica
CLAUDE AUDIT E-017: default-deny. Se target nao esta na allowlist interna = EXTERNO.
Se EXTERNO e payload tem padroes sensiveis → BLOQUEIA + alerta.

Uso: python boundary-guard.py --target <nome> --payload <arquivo_ou_string>
Exit: 0=ALLOW, 1=DENY, 2=ERROR
"""

import sys
import re
import json
import argparse
from pathlib import Path
from datetime import datetime

# === ALLOWLIST INTERNA (default-deny: tudo fora disto = externo) ===
INTERNAL_AGENTS = {
    'abraao-local', 'abraao', 'augustus', 'omniqi', 'neemias', 'solfortes',
    'atanazio',  # persona do Augustus, interno
    # E-017 auditor: read-only local, nao e destino de rede
    'claude-code', 'claude', 'e017',
}

# === PADROES SENSIVEIS (regex) ===
SENSITIVE_PATTERNS = [
    # Paths internos
    (r'C:\\Users\\Dudy', 'path interno Windows'),
    (r'/root/\.hermes', 'path interno Augustus'),
    (r'/mnt/c/Users/Dudy', 'path WSL->Windows'),
    # Secrets
    (r'\.env\b', 'arquivo .env'),
    (r'github_token', 'github token'),
    (r'ghp_[a-zA-Z0-9]{36}', 'GitHub PAT exposto'),
    (r'id_ed25519', 'chave SSH privada'),
    (r'sk-[a-zA-Z0-9]{20,}', 'API key (sk-)'),
    (r'Bearer\s+[a-zA-Z0-9_.\-]{20,}', 'Bearer token'),
    (r'(?i)password\s*[:=]\s*\S{8,}', 'password em texto plano'),
    (r'-----BEGIN\s+(RSA|EC|OPENSSH|PGP)?\s?PRIVATE\s+KEY-----', 'private key'),
    # Tailscale IPs
    (r'100\.\d{1,3}\.\d{1,3}\.\d{1,3}', 'IP Tailscale interno'),
    # DBs internos
    (r'brain_v2\.db', 'brain_v2.db (segundo cerebro)'),
    (r'state\.db', 'state.db (historico sessões)'),
    # Config
    (r'config\.yaml', 'config.yaml'),
    # Repo privado
    (r'pablodornellas-ux/omniqi-trader-agent', 'repo privado'),
    # LGPD
    (r'\b\d{3}\.\d{3}\.\d{3}-\d{2}\b', 'CPF (LGPD)'),
    (r'\b\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}\b', 'CNPJ (LGPD)'),
]

# === ALLOWLIST DE EXTENSOES SEGURAS (para anexos E-017) ===
SAFE_EXTENSIONS = {'.py', '.sh', '.md', '.txt', '.json', '.yaml', '.yml', '.toml'}


def scan_payload(payload: str) -> list:
    """Escaneia payload contra padroes sensiveis. Retorna lista de matches."""
    matches = []
    for pattern, label in SENSITIVE_PATTERNS:
        found = re.findall(pattern, payload)
        if found:
            matches.append({
                'label': label,
                'pattern': pattern,
                'count': len(found),
                'sample': found[0][:50] if found else ''
            })
    return matches


def is_internal(target: str) -> bool:
    """Verifica se target esta na allowlist interna."""
    target_lower = target.lower().strip()
    for agent in INTERNAL_AGENTS:
        if agent in target_lower:
            return True
    return False


def check_file_extensions(payload: str) -> list:
    """Verifica se payload referencia arquivos com extensoes nao-seguras."""
    # Procura paths de arquivos no payload
    file_refs = re.findall(r'[\w/\\.-]+\.\w+', payload)
    unsafe = []
    for f in file_refs:
        ext = Path(f).suffix.lower()
        if ext and ext not in SAFE_EXTENSIONS:
            unsafe.append({'file': f, 'ext': ext})
    return unsafe


def log_block(target: str, matches: list, unsafe_files: list):
    """Loga bloqueio em arquivo de audit."""
    log_dir = Path.home() / '.hermes' / 'workspace' / 'logs'
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / 'boundary-guard.log'
    entry = {
        'timestamp': datetime.now().isoformat(),
        'target': target,
        'blocked': True,
        'sensitive_matches': matches,
        'unsafe_files': unsafe_files,
    }
    with open(log_file, 'a', encoding='utf-8') as f:
        f.write(json.dumps(entry, ensure_ascii=False) + '\n')


def main():
    parser = argparse.ArgumentParser(description='Boundary guard anti-leak')
    parser.add_argument('--target', required=True, help='Nome do agente destino')
    parser.add_argument('--payload', required=True, help='Payload (arquivo ou string)')
    args = parser.parse_args()

    target = args.target
    internal = is_internal(target)

    # Le payload (arquivo ou string direta)
    payload_path = Path(args.payload)
    if payload_path.exists():
        payload = payload_path.read_text(encoding='utf-8', errors='ignore')
    else:
        payload = args.payload

    # Se interno → ALLOW (compartilha tudo)
    if internal:
        print(f"ALLOW: target '{target}' e INTERNO (allowlist)")
        sys.exit(0)

    # EXTERNO → escanear
    matches = scan_payload(payload)
    unsafe_files = check_file_extensions(payload)

    if matches or unsafe_files:
        print(f"DENY: target '{target}' e EXTERNO e payload contem dados sensiveis:")
        for m in matches:
            print(f"  - {m['label']} ({m['count']}x)")
        for uf in unsafe_files:
            print(f"  - arquivo inseguro: {uf['file']} (ext: {uf['ext']})")
        log_block(target, matches, unsafe_files)
        print(f"  Log salvo em ~/.hermes/workspace/logs/boundary-guard.log")
        sys.exit(1)
    else:
        print(f"ALLOW: target '{target}' e EXTERNO mas payload nao contem dados sensiveis")
        sys.exit(0)


if __name__ == '__main__':
    main()
