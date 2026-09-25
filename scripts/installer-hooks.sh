#!/usr/bin/env bash
# installer-hooks.sh — repose les garde-fous git de CE dépôt. Idempotent.
#
# POURQUOI CE SCRIPT EXISTE. `core.hooksPath` est une configuration LOCALE, perdue à chaque
# clone. Une session fraîche n'a donc, par défaut, NI doc-lint, NI code-lint, NI contrôle du
# noyau, sans que rien ne le signale.
#
# Deux configurations, pas une.
#   core.hooksPath  active les hooks versionnés de scripts/githooks/
#   merge.ff false  sans commit de fusion, un hook de fusion ne se déclenche jamais
set -euo pipefail
racine=$(git rev-parse --show-toplevel)
cd "$racine"

pose() {
    local cle="$1" valeur="$2" actuel
    actuel=$(git config --get "$cle" || true)
    if [ "$actuel" = "$valeur" ]; then
        echo "  = $cle déjà à « $valeur »"
    else
        git config "$cle" "$valeur"
        echo "  + $cle → « $valeur »"
    fi
}

echo "== Garde-fous git =="
pose core.hooksPath scripts/githooks
pose merge.ff false

manquants=""
for h in pre-commit pre-merge-commit pre-push; do
    [ -f "scripts/githooks/$h" ] || manquants="$manquants $h"
done
if [ -n "$manquants" ]; then
    echo "⚠️  hooks introuvables dans scripts/githooks/ :$manquants" >&2
    exit 1
fi
echo "== En place. Les commits et les pushes sont désormais contrôlés ici. =="
