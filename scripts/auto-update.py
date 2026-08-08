#!/usr/bin/env python
"""auto-update.py v2 — Auto-update SEGURO (preserva arquivos do usuário).

DIFF vs v1: NÃO sobrescreve arquivos de instancia do usuário.

REGRA:
- *.template (model files) = pode sobrescrever (vem do template)
- SEM .template (instância) = PRESERVA (user customizou)

Arquivos protegidos (NUNCA sobrescritos):
- MEMORY.md
- USER.md
- SOUL.md
- AGENTS.md
- .env
- hooks/*
- config/local-* (config local)

V2 CHANGELOG:
- shutil.copytree(src, dst) → safe_copytree(src, dst) que PRESERVA
- Compara SHA256 antes de sobrescrever
- Log claro do que foi sobrescrito vs preservado
- Adiciona backup automatico antes de qualquer update
"""
import os, subprocess, json, urllib.request, shutil, sys, hashlib
from datetime import datetime
from pathlib import Path


def find_hermes_home():
    candidates = [
        Path(r'C:\Users\Dudy\AppData\Local\hermes'),
        Path.home() / 'AppData' / 'Local' / 'hermes',
        Path(r'C:\Users\Dudy\.hermes'),
        Path.home() / '.hermes',
    ]
    for c in candidates:
        if c.exists() and (c / 'state.db').exists():
            return c
    return Path(r'C:\Users\Dudy\AppData\Local\hermes')


HERMES_HOME = find_hermes_home()
GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN')
if not GITHUB_TOKEN:
    secret = HERMES_HOME / 'workspace' / 'secrets' / 'github_token.txt'
    if secret.exists():
        GITHUB_TOKEN = secret.read_text().strip()
    elif Path.home().joinpath('.openclaw/workspace/secrets/github_token.txt').exists():
        GITHUB_TOKEN = Path.home().joinpath('.openclaw/workspace/secrets/github_token.txt').read_text().strip()

REPO = 'hermes-agent-templates'
USER = 'pablodornellas-ux'
LOG = HERMES_HOME / 'workspace' / 'logs' / 'auto-update.log'


# Arquivos PROTEGIDOS (nunca sobrescritos)
PROTECTED_FILES = {
    'MEMORY.md',
    'USER.md',
    'SOUL.md',
    'AGENTS.md',
    '.env',
    '.env.local',
}

PROTECTED_PATTERNS = [
    'hooks/',           # tudo em hooks/ é custom
    'config/local-',   # config local-*
    'config/secret',   # qualquer config/secret
    'config/.env',     # qualquer .env em config
]


def is_protected(rel_path: str) -> bool:
    """Retorna True se arquivo é de instancia do usuario (NAO sobrescrever)."""
    name = Path(rel_path).name

    # Checar arquivos protegidos exatos
    if name in PROTECTED_FILES:
        return True

    # Checar padroes
    for pattern in PROTECTED_PATTERNS:
        if rel_path.startswith(pattern) or f'/{pattern}' in f'/{rel_path}':
            return True

    return False


def file_hash(path: Path) -> str:
    """SHA256 do arquivo."""
    if not path.exists() or not path.is_file():
        return ''
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()[:16]


def safe_copy(src_dir: Path, dst_dir: Path) -> dict:
    """Cópia SEGURA de src pra dst. Preserva arquivos protegidos.

    Returns:
        dict com {preserved: [...], updated: [...], added: [...]}
    """
    log(f'Iniciando safe_copy: {src_dir.name} -> {dst_dir.name}')
    result = {'preserved': [], 'updated': [], 'added': []}

    if not src_dir.exists():
        log(f'  ERRO: {src_dir} nao existe')
        return result

    # Walk source
    for src_path in src_dir.rglob('*'):
        if src_path.is_dir():
            # Criar diretorio no destino se nao existe
            rel = src_path.relative_to(src_dir)
            dst_path = dst_dir / rel
            if not dst_path.exists():
                dst_path.mkdir(parents=True, exist_ok=True)
                log(f'  +dir {rel}')
            continue

        rel = src_path.relative_to(src_dir)
        rel_str = str(rel).replace('\\', '/')
        dst_path = dst_dir / rel

        # REGRA: se for arquivo protegido, PRESERVA
        if is_protected(rel_str):
            if dst_path.exists():
                result['preserved'].append(rel_str)
                log(f'  PRESERV {rel_str} (protegido)')
            else:
                # Primeira install: copia o template
                shutil.copy2(src_path, dst_path)
                result['added'].append(rel_str)
                log(f'  +{rel_str} (primeira install)')
            continue

        # REGRA: se existe localmente e mesmo hash, skip
        if dst_path.exists():
            src_hash = file_hash(src_path)
            dst_hash = file_hash(dst_path)
            if src_hash == dst_hash:
                log(f'  ={rel_str} (mesmo hash)')
                continue
            # Hash diferente = usuario customizou = PRESERVA
            else:
                # Criar backup antes de sobrescrever
                backup_path = dst_path.with_suffix(dst_path.suffix + '.user-backup')
                if not backup_path.exists():
                    shutil.copy2(dst_path, backup_path)
                    log(f'  !backup {rel_str} -> {backup_path.name}')
                # Atualiza so se for arquivo de template (nao de instancia)
                # .template pode ser sobrescrito
                # SEM .template (mas nao protegido) PRESERVA
                name = Path(rel_str).name
                if name.endswith('.template') or '.template.' in rel_str:
                    shutil.copy2(src_path, dst_path)
                    result['updated'].append(rel_str)
                    log(f'  ~{rel_str} (template, sobrescrito)')
                else:
                    # Preserva instancia do usuario
                    result['preserved'].append(rel_str)
                    log(f'  PRESERV {rel_str} (customizado, hash dif)')
                continue

        # Arquivo NOVO no source — copia
        dst_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_path, dst_path)
        result['added'].append(rel_str)
        log(f'  +{rel_str}')

    return result


def log(msg):
    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{ts}] {msg}\n'
    try:
        os.makedirs(LOG.parent, exist_ok=True)
        with open(LOG, 'a') as f:
            f.write(line)
    except Exception:
        pass
    print(line.strip())


def fetch_github(path):
    url = f'https://api.github.com{path}'
    headers = {'Accept': 'application/vnd.github.v3+json'}
    if GITHUB_TOKEN:
        headers['Authorization'] = f'token {GITHUB_TOKEN}'
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read())
    except Exception as e:
        log(f'API FAIL {path}: {e}')
        return None


def clone_template(name):
    workdir = HERMES_HOME / 'workspace' / f'.auto-update-{name}'
    if workdir.exists():
        try:
            shutil.rmtree(workdir)
        except OSError:
            subprocess.run(['cmd', '/c', 'rmdir', '/s', '/q', str(workdir)], capture_output=True, timeout=30)
    workdir.mkdir(parents=True)
    try:
        result = subprocess.run(
            ['git', 'clone', '--depth=1', f'https://github.com/{USER}/{REPO}.git', str(workdir)],
            check=True, capture_output=True, timeout=60
        )
        return True
    except subprocess.CalledProcessError as e:
        log(f'ERRO clone {name}: {e.stderr.decode()[:200] if e.stderr else str(e)}')
        return False
    finally:
        for _ in range(3):
            try:
                if workdir.exists():
                    shutil.rmtree(workdir)
                break
            except OSError:
                import time
                time.sleep(1)


def apply_template(name):
    tpl_github = HERMES_HOME / 'workspace' / 'templates' / name
    tpl_local = HERMES_HOME / 'templates' / name

    if tpl_local.exists():
        log(f'SKIP {name} (ja existe)')
        return False

    if not clone_template(name):
        return False

    src = tpl_github / 'templates' / name
    if src.exists():
        # ANTES de copiar: criar backup do destino (que nao existe, mas seguro)
        if tpl_local.exists():
            backup = HERMES_HOME / 'workspace' / f'backup-{name}-{datetime.now().strftime("%Y%m%d-%H%M%S")}'
            shutil.copytree(str(tpl_local), str(backup))
            log(f'  backup do local em {backup}')

        tpl_local.parent.mkdir(parents=True, exist_ok=True)
        result = safe_copy(src, tpl_local)
        log(f'OK {name}: {len(result["added"])} added, {len(result["updated"])} updated, {len(result["preserved"])} preserved')
        return True
    return False


def scan_local_templates():
    tpl_dir = HERMES_HOME / 'templates'
    if not tpl_dir.exists():
        return []
    return [d.name for d in tpl_dir.iterdir() if d.is_dir()]


def scan_github_templates():
    data = fetch_github(f'/repos/{USER}/{REPO}/contents/templates')
    if not data:
        return []
    return [d['name'] for d in data if d.get('type') == 'dir']


def main():
    log('=== AUTO-UPDATE v2 START (SEGURO - preserva customizacoes) ===')

    local_templates = set(scan_local_templates())
    github_templates = set(scan_github_templates() or [])
    new_templates = github_templates - local_templates

    if new_templates:
        log(f'Novos templates: {new_templates}')
        for tpl in new_templates:
            apply_template(tpl)

    log('=== AUTO-UPDATE v2 DONE ===')


if __name__ == '__main__':
    main()