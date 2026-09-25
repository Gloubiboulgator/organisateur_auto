#!/usr/bin/env bash
# code-lint — garde-fou des fautes de code qu'une machine locale peut attraper sans compiler.
#
# CE FICHIER APPARTIENT AU NOYAU. Un projet ne le modifie jamais. Ses contrôles à lui vivent
# dans scripts/code-lint-local.sh, exécuté à la fin, avec des numéros préfixés par L.
#
# Même contrat que doc-lint.sh : chaque contrôle DOIT revenir vide, sortie non nulle sinon.
# Usage :  bash scripts/code-lint.sh
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
check() {
  if [ -n "$2" ]; then printf '  ❌ %s\n' "$1"; printf '%s\n' "$2" | sed 's/^/      /'; fail=1
  else printf '  ✅ %s\n' "$1"; fi
}
# garde_plante <code> <sortie> : un contrôle qui PLANTE doit crier, pas se taire. Sans lui, un
# heredoc qui lève écrit sa trace sur la sortie d'erreur, la capture reste vide, et check()
# compte vert pour toujours.
garde_plante() {
  if [ "$1" -ne 0 ]; then printf 'CONTRÔLE PLANTÉ (code %s) : %s' "$1" "${2:-aucune sortie}"
  else printf '%s' "$2"; fi
}

# 1) LE POURQUOI. Un test de rendu acceptait la forme avec ET sans emoji dans le même assert.
#    Il ne décidait rien, et la forme n'a jamais été tranchée. Un test de comportement choisit
#    UNE forme. Un « or » légitime, aux conditions vraiment indépendantes, s'exempte par un
#    commentaire `# @assertion-double : <motif>` sur la ligne, ou sur celle du dessus.
section "1. Aucune assertion indécise dans les tests"
out=$(python3 - 2>&1 <<'PY1'
import os, pathlib, re
# La cible accepte les points et les appels, comme r.text ou r.text.lower(). Une cible réduite
# aux mots laissait dormir de vraies assertions indécises derrière.
motif = re.compile(r"assert .+ in (\S+) or .+ in \1(?![\w.(])")
mauvais = []
racine = pathlib.Path(os.environ.get("DOSSIER_TESTS", "tests"))
for f in sorted(racine.rglob("*.py")) if racine.is_dir() else []:
    lignes = f.read_text(encoding="utf-8").splitlines()
    for num, ligne in enumerate(lignes, 1):
        if "@assertion-double" in ligne:
            continue
        if num >= 2 and "@assertion-double" in lignes[num - 2]:
            continue
        if motif.search(ligne):
            mauvais.append(f"{f}:{num} : {ligne.strip()[:100]}")
print("\n".join(mauvais))
PY1
)
out=$(garde_plante $? "$out")
check "aucun assert n'accepte deux formes du même élément" "$out"

# ── Les contrôles LOCAUX du projet ────────────────────────────────────────────────────────────
# LE FICHIER LOCAL TOURNE DANS UN SOUS-SHELL, ET CE N'EST PAS UN DÉTAIL. Sourcé dans la portée
# du parent, il partageait la variable du verdict : une ligne « fail=0 », posée exprès ou par une
# banale collision de nom, rendait « tout est vert » alors que des contrôles du noyau venaient de
# rougir. Le hook ne lit que le code de sortie, donc le commit fautif passait. Le sous-shell rend
# ce fichier incapable de toucher au verdict du noyau, et son propre verdict remonte par la
# sortie. Une redéfinition de check() ou de section() y est enfermée de la même façon.
#
# LE FICHIER LOCAL DOIT AVOIR TOURNÉ POUR QUE SON VERT COMPTE. Une faute de syntaxe placée
# AVANT le premier contrôle laisse « fail » à zéro dans le sous-shell : il sortait en zéro, et le
# lint annonçait « tout est vert » alors qu'aucun contrôle local n'avait tourné. Le doc-lint a
# reçu cette garde en premier, ce jumeau ensuite, et les deux la portent maintenant.
#
# LIMITE ASSUMÉE, la même qu'au doc-lint. Une commande qui échoue DANS une condition « if » du
# fichier local n'est rattrapée ni par « bash -n » ni par ce code de sortie.
if [ -f scripts/code-lint-local.sh ]; then
  fail_noyau=$fail
  if ! erreur=$(bash -n scripts/code-lint-local.sh 2>&1); then
    printf '  ❌ %s\n' "scripts/code-lint-local.sh ne s'analyse pas, ses contrôles n'ont pas tourné"
    printf '%s\n' "$erreur" | sed 's/^/      /'
    fail=1
  else
    # shellcheck source=/dev/null
    ( fail=0; . scripts/code-lint-local.sh; exit "$fail" )
    fail_local=$?
    if [ "$fail_local" -gt 1 ]; then
      printf '  ❌ %s\n' "scripts/code-lint-local.sh s'est interrompu (code $fail_local)"
      printf '      %s\n' "ses contrôles n'ont pas tous tourné, le vert ne prouve rien"
    fi
    [ "$fail_local" -eq 0 ] || fail=1
  fi
  [ "$fail_noyau" -eq 0 ] || fail=1
fi

if [ "$fail" -ne 0 ]; then
  printf '\n\033[1;31m❌ code-lint : au moins un contrôle a échoué (voir ci-dessus).\033[0m\n'
  exit 1
fi
printf '\n\033[1;32m✅ code-lint : tout est vert.\033[0m\n'
