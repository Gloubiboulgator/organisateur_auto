#!/usr/bin/env bash
# pousser.sh — pousse une branche, teste AVANT d'ouvrir la connexion, pose un témoin.
#
# CE FICHIER APPARTIENT AU NOYAU. Un projet ne le modifie jamais. Ce qu'il doit tester avant de
# pousser — sa propre suite, son propre délai — vit dans scripts/pousser-local.sh, à la racine
# du projet, JAMAIS ici : « le noyau ne pose que ce qui vaut pour tout projet » (README).
#
# LE PROBLÈME QUE CE SCRIPT RÉSOUT (né chez un projet consommateur, généralisé le 2026-09-19) :
# `git push` ouvre la connexion vers le remote AVANT que `githooks/pre-push` tourne. Un contrôle
# long lancé DANS le hook tourne donc connexion déjà ouverte, et un remote qui coupe les
# connexions longues interrompt le transfert avant la fin — tests verts ou pas. La parade :
# lancer le contrôle ICI, avant toute connexion, poser un TÉMOIN qui certifie « cet arbre a son
# contrôle local vert, à telle heure », puis pousser. `githooks/pre-push` reconnaît un témoin
# frais et ne relance rien.
#
# TÉMOIN INDEXÉ SUR L'ARBRE, PAS LE COMMIT. Un commit de fusion `--no-ff` sur une branche non
# divergente (`git merge --ff-only` puis `--no-ff`) porte un sha neuf pour un arbre identique à
# celui déjà testé. Indexer le témoin sur le commit ferait rejouer le contrôle local pour un
# contenu déjà certifié — piège vécu, corrigé avant d'être généralisé ici.
#
# CE SCRIPT NE SAIT PAS CE QU'EST « TESTER ». Il lance les lints du noyau, puis délègue tout le
# reste à scripts/pousser-local.sh s'il existe. Sans ce fichier, il n'y a rien de coûteux à
# protéger : lints, puis push direct.
#
# Usage :  scripts/pousser.sh [remote] [branche]     (défaut : origin, branche par défaut du remote)
set -euo pipefail

remote="${1:-origin}"
# Sous pipefail, un « git symbolic-ref » qui échoue (origin/HEAD absent) ferait échouer toute
# la pipeline malgré le « sed » qui suit : le « || true » l'assume, « defaut » retombe sur main.
defaut=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
defaut="${defaut:-main}"
branche="${2:-$defaut}"

root=$(git rev-parse --show-toplevel)
cd "$root"
temoin="$(git rev-parse --git-common-dir)/temoin-pousser-local"

# ── Garde : sans hooks, rien de ce qui suit n'est garanti au commit ────────────────────────────
if [ "$(git config --get core.hooksPath || true)" != "scripts/githooks" ]; then
    echo "pousser.sh : REFUSÉ — les hooks git ne sont pas posés dans ce dépôt." >&2
    echo "             Lance d'abord : bash scripts/installer-hooks.sh" >&2
    exit 1
fi

# ── L'amont d'abord : tester un arbre qu'il faudra refusionner, c'est payer deux fois ─────────
git fetch "$remote" "$branche" --quiet 2>/dev/null || true
git fetch "$remote" "$defaut" --quiet 2>/dev/null || true
sha=$(git rev-parse "$branche")
arbre=$(git rev-parse "$sha^{tree}")

if git rev-parse --verify --quiet "$remote/$branche" >/dev/null; then
    retard=$(git rev-list --count "$branche..$remote/$branche")
    if [ "$retard" != "0" ]; then
        echo "pousser.sh : REFUSÉ — $remote/$branche a $retard commit(s) d'avance." >&2
        echo "             Fusionne l'amont d'abord (git merge $remote/$branche), puis relance." >&2
        exit 1
    fi
fi

echo "== pousser.sh : lints (doc + code) =="
bash scripts/doc-lint.sh >/dev/null || { echo "pousser.sh : doc-lint ROUGE — rien n'est poussé." >&2; exit 1; }
bash scripts/code-lint.sh >/dev/null || { echo "pousser.sh : code-lint ROUGE — rien n'est poussé." >&2; exit 1; }

if [ -f scripts/pousser-local.sh ]; then
    # La suite tourne sur l'ARBRE DE TRAVAIL et le témoin porte le hash de CET arbre : un arbre
    # sale ferait certifier un contenu qui n'est pas celui qui part.
    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
        echo "pousser.sh : REFUSÉ — l'arbre de travail a des modifications non commitées." >&2
        echo "             Committe ou remise (stash) d'abord : le témoin ne certifie que du commité." >&2
        exit 1
    fi
    if [ "$(git rev-parse HEAD)" != "$sha" ]; then
        echo "pousser.sh : REFUSÉ — HEAD n'est pas la branche poussée ($branche)." >&2
        echo "             Bascule dessus d'abord : le contrôle local doit juger ce qui part." >&2
        exit 1
    fi
    echo "== pousser.sh : scripts/pousser-local.sh, AVANT la connexion (arbre $(git rev-parse --short "$arbre")) =="
    bash scripts/pousser-local.sh
    date +%s > "$temoin.tmp"
    echo "$arbre" >> "$temoin.tmp"
    mv "$temoin.tmp" "$temoin"
    echo "== contrôle local vert — témoin posé, push =="
else
    echo "== pousser.sh : pas de scripts/pousser-local.sh — push direct =="
fi

# `set -e` suffirait, mais on le dit à voix haute : un push refusé n'est pas un succès.
if ! git push "$remote" "$branche"; then
    echo "pousser.sh : ÉCHEC — le push a été REFUSÉ, rien n'est parti." >&2
    exit 1
fi
