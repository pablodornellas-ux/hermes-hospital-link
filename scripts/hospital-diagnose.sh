#!/bin/bash
# hospital-diagnose.sh — Diagnostico rapido (read-only)
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
echo "=== HOSPITAL DIAGNOSE ==="
echo "HERMES_HOME: $HERMES_HOME"
echo

# L1 - MEMORY/USER/SOUL
echo "[L1] Identity files:"
for f in MEMORY.md USER.md SOUL.md; do
  if [ -f "$HERMES_HOME/$f" ]; then
    size=$(stat -c%s "$HERMES_HOME/$f" 2>/dev/null || stat -f%z "$HERMES_HOME/$f")
    echo "  OK $f: ${size}B"
  else
    echo "  MISSING $f"
  fi
done

# L2 - mem0
echo
echo "[L2] Memory (mem0):"
if curl -s -m 3 http://localhost:8765/health >/dev/null 2>&1; then
  echo "  OK mem0-server running on :8765"
  curl -s -m 3 http://localhost:8765/health | python -m json.tool 2>/dev/null | head -10
else
  echo "  FAIL mem0-server not responding"
fi

# L3 - state.db
echo
echo "[L3] state.db:"
state_db="$HERMES_HOME/state.db"
if [ -f "$state_db" ]; then
  size=$(stat -c%s "$state_db" 2>/dev/null)
  echo "  OK state.db: ${size}B"
  if command -v sqlite3 >/dev/null; then
    sqlite3 "$state_db" "SELECT '  sessions: ' || COUNT(*) FROM messages;" 2>/dev/null
  fi
else
  echo "  MISSING state.db"
fi

# L4 - skills
echo
echo "[L4] Skills:"
if [ -d "$HERMES_HOME/skills" ]; then
  count=$(find "$HERMES_HOME/skills" -name "SKILL.md" -not -path "*__pycache__*" 2>/dev/null | wc -l)
  echo "  Skills count: $count"
else
  echo "  MISSING skills dir"
fi

# L5 - backups
echo
echo "[L5] Backups:"
backup_dir="$HERMES_HOME/workspace/backups"
if [ -d "$backup_dir" ]; then
  latest=$(ls -t "$backup_dir"/*.tar.gz 2>/dev/null | head -1)
  if [ -n "$latest" ]; then
    age=$(($(date +%s) - $(stat -c%Y "$latest" 2>/dev/null || stat -f%m "$latest")))
    days=$((age / 86400))
    echo "  Latest: $(basename $latest) (${days}d ago)"
  else
    echo "  No backups found"
  fi
else
  echo "  No backup dir"
fi

echo
echo "Run harmonize_memory.py --harmonize for full report"