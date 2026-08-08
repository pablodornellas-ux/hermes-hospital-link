#!/bin/bash
# checks/11-salomao.sh — Camada 2: Salomão (Orquestrador Diz a Bíblia Cortes)

set +e
OK_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0
ok() { echo "✅ $*"; OK_COUNT=$((OK_COUNT+1)); }
warn() { echo "⚠️  $*"; WARN_COUNT=$((WARN_COUNT+1)); }
fail() { echo "❌ $*"; FAIL_COUNT=$((FAIL_COUNT+1)); }

echo "🎬 SALOMÃO — Diz a Bíblia Cortes"
echo "==================================="

# 1. Scripts salomao presentes (em C:\Users\Dudy\salomao)
if [ -d "/c/Users/Dudy/salomao" ]; then
    ok "scripts: /c/Users/Dudy/salomao existe"
    if [ -f "/c/Users/Dudy/salomao/scripts/ssh-admin.py" ]; then
        ok "scripts: ssh-admin.py presente"
    else
        warn "scripts: ssh-admin.py ausente"
    fi
else
    warn "scripts: /c/Users/Dudy/salomao nao encontrado"
fi

# 2. AUDIT_PROMPT (template pronto pra auditar repo)
if [ -f "/c/Users/Dudy/salomao/AUDIT_PROMPT.md" ]; then
    LINES=$(wc -l < /c/Users/Dudy/salomao/AUDIT_PROMPT.md)
    ok "audit: AUDIT_PROMPT.md presente ($LINES linhas)"
else
    warn "audit: AUDIT_PROMPT.md ausente"
fi

# 3. Templating ferramenta YouTube/IG (vai depender do agent)
ok "specialty: checks especificos YouTube/IG dependem do deployment real"

echo "==================================="
echo "SALOMÃO RESUMO: $OK_COUNT OK, $WARN_COUNT WARN, $FAIL_COUNT FAIL"
echo "==================================="

if [ $FAIL_COUNT -gt 0 ]; then exit 1; fi
if [ $WARN_COUNT -gt 0 ]; then exit 2; fi
exit 0