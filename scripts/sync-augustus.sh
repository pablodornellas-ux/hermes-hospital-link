#!/bin/bash
# sync-augustus.sh — Sincroniza scripts/skills/docs do repo pro Augustus
# CLAUDE AUDIT E-017: federada (pull). Abraao faz bridge pro container.
# Roda no WSL host (nao dentro do container).

set -euo pipefail

REPO_DIR="${1:-$HOME/hermes-hospital-link}"
CONTAINER="augustus-hermes-standalone"
TARGET="/root/.hermes"

echo "=== sync-augustus.sh — $(date) ==="

# 1. Git pull no WSL host
if [ -d "$REPO_DIR/.git" ]; then
    echo "[1/4] git pull..."
    cd "$REPO_DIR" && git pull --ff-only 2>&1 | head -5
else
    echo "[1/4] WARN: $REPO_DIR nao e um repo git. Clone primeiro."
    exit 1
fi

# 2. Copiar scripts pro container (LF clean via base64)
echo "[2/4] copiando scripts..."
for f in scripts/*.py scripts/*.sh; do
    [ -f "$f" ] || continue
    FNAME=$(basename "$f")
    B64=$(base64 -w0 "$f")
    echo "$B64" | base64 -d | docker exec -i "$CONTAINER" tee "$TARGET/workspace/scripts/$FNAME" > /dev/null
    echo "  $FNAME OK"
done

# 3. Copiar skills vitais pro container
echo "[3/4] copiando skills vitais..."
for skill in anti-amnesia agent-self-improvement boundary-external-agent pre-create-check memory-layer-architecture dedupe fabrica-doctor-orchestrator fabrica-fleet-diagnostic; do
    if [ -d "$REPO_DIR/skills/$skill" ]; then
        # Criar dir no container
        docker exec "$CONTAINER" mkdir -p "$TARGET/skills/$skill" 2>/dev/null || true
        # Copiar SKILL.md via base64
        SKFILE="$REPO_DIR/skills/$skill/SKILL.md"
        if [ -f "$SKFILE" ]; then
            B64=$(base64 -w0 "$SKFILE")
            echo "$B64" | base64 -d | docker exec -i "$CONTAINER" tee "$TARGET/skills/$skill/SKILL.md" > /dev/null
            echo "  $skill OK"
        fi
    fi
done

# 4. Verificar (boundary-guard anti-regressao)
echo "[4/4] verificando..."
docker exec "$CONTAINER" ls "$TARGET/workspace/scripts/" | wc -l
echo "scripts no container"

echo "=== sync-augustus.sh DONE ==="