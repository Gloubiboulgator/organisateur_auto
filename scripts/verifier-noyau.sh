#!/usr/bin/env bash
# verifier-noyau.sh — dit si un projet a dérivé du noyau, dans les DEUX sens.
#
# À ne pas confondre avec verifier-derive.sh, à la racine du dépôt du noyau, qui existe et fait
# autre chose : il lance CE script sur un projet cible.
#
# LES DEUX DÉRIVES, ET POURQUOI IL FAUT LES DEUX
# -----------------------------------------------
# BRICOLAGE : un fichier du noyau modifié sur place dans le projet. Une règle changée là plutôt
# que dans le noyau crée une deuxième vérité, exactement ce que la règle mère interdit.
#
# RETARD : le noyau a avancé, le projet est resté. C'est la dérive qu'une simple empreinte
# locale ne voit JAMAIS, parce qu'elle ne compare qu'à ce qu'elle a enregistré. Un essai l'a
# montré, une copie restait verte avec une règle de moins que sa source.
#
# Le retard demande d'atteindre le noyau. Sans lui, ce script dit qu'il n'a pas pu vérifier,
# plutôt que de rendre un vert qui ne couvre que la moitié de la question.
#
# CE FICHIER EST POSÉ DANS LE PROJET, et c'est voulu. Le hook pre-commit doit pouvoir vérifier
# le bricolage hors ligne, sans savoir où vit le dépôt du noyau. Le chemin du noyau, lui, est
# celui que l'installateur a enregistré. Une seule implémentation, deux appelants.
#
# DEUX RÉGIMES, ET LA DIFFÉRENCE EST LE CŒUR DU CONTRÔLE (revue de code du 2026-08-31).
#
# Le BRICOLAGE et les MANQUANTS refusent le commit. Un fichier du noyau modifié ou supprimé dans
# le projet est une incohérence de CE dépôt, donc du ressort du commit en cours.
#
# Le RETARD avertit seulement. L'état du dépôt du noyau n'est pas un défaut du commit qu'on
# écrit. Le faire bloquer gelait le projet ENTIER dès que le noyau avançait d'un commit : plus
# aucun travail possible, y compris sur un fichier sans le moindre rapport. Vérifié en
# exécutant, sur un projet installé dont le noyau avait pris un commit d'avance.
#
# L'option --strict rétablit le blocage sur le retard, pour qui le veut.
#
# Usage :  bash scripts/verifier-noyau.sh [/chemin/du/projet] [--strict]
set -uo pipefail

strict=0
args=""
for a in "$@"; do
    if [ "$a" = "--strict" ]; then strict=1; else args="$a"; fi
done
cible="${args:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cible="$(cd "$cible" 2>/dev/null && pwd)" || { echo "chemin introuvable" >&2; exit 1; }
empreintes="$cible/.noyau-empreintes"

if [ ! -f "$empreintes" ]; then
    echo "verifier-noyau : le noyau n'est pas posé dans « $cible » (pas d'empreintes)." >&2
    echo "                  Lancer d'abord l'installateur du noyau." >&2
    exit 1
fi

fail=0

# ── 1) Bricolage, hors ligne, toujours possible ───────────────────────────────────────────────
bricoles=""
manquants=""
while read -r attendu rel; do
    case "$attendu" in '#'*) continue ;; esac
    [ -n "${rel:-}" ] || continue
    if [ ! -f "$cible/$rel" ]; then
        manquants="$manquants\n  $rel"
        continue
    fi
    actuel=$(sha256sum "$cible/$rel" | cut -d' ' -f1)
    [ "$actuel" = "$attendu" ] || bricoles="$bricoles\n  $rel"
done < "$empreintes"

if [ -n "$bricoles" ]; then
    echo "❌ BRICOLAGE — ces fichiers du noyau ont été modifiés dans le projet :" >&2
    printf '%b\n' "$bricoles" >&2
    echo "   Une règle se change dans le noyau, puis se rediffuse. Un contrôle propre au projet" >&2
    echo "   vit dans scripts/doc-lint-local.sh." >&2
    fail=1
fi
if [ -n "$manquants" ]; then
    echo "❌ MANQUANTS — ces fichiers du noyau ont disparu du projet :" >&2
    printf '%b\n' "$manquants" >&2
    fail=1
fi

# ── 1bis) Les hooks doivent être EXÉCUTABLES ──────────────────────────────────────────────────
# Les empreintes ne portent qu'un sha256, donc le mode est hors de leur champ. Un hook qui perd
# son bit x — une archive restaurée, un rsync sans -p, core.fileMode à false — est ignoré par
# git, qui n'imprime qu'un indice. Le doc-lint, le code-lint et ce script cessent alors de
# tourner tous les trois, sans qu'un seul octet ait bougé.
#
# Seuls les hooks sont testés. Les autres scripts s'appellent par « bash x.sh », où le bit
# n'entre pas en jeu, et l'exiger d'eux inventerait une règle que rien ne demande.
desarmes=""
for hook in "$cible"/scripts/githooks/*; do
    [ -f "$hook" ] || continue
    [ -x "$hook" ] || desarmes="$desarmes\n  scripts/githooks/$(basename "$hook")"
done
if [ -n "$desarmes" ]; then
    echo "❌ DÉSARMÉS — ces hooks ont perdu leur bit exécutable, git les ignore en silence :" >&2
    printf '%b\n' "$desarmes" >&2
    echo "   Aucun contrôle ne tourne plus au commit. Réparer : chmod +x scripts/githooks/*" >&2
    fail=1
fi

# ── 2) Retard, seulement si le noyau est atteignable ──────────────────────────────────────────
pose=$(grep '^# version-noyau:' "$empreintes" | cut -d' ' -f3)

# OÙ CHERCHER LE NOYAU, dans l'ordre. Le chemin enregistré est celui de la machine qui a POSÉ,
# et il n'existe pas ailleurs — une pose depuis une session éphémère laisse un chemin mort. On
# essaie donc trois pistes avant de déclarer le retard invérifiable.
enregistre=$(grep '^# source-noyau:' "$empreintes" | cut -d' ' -f3-)
# Le tilde noté à la pose se redéveloppe ici. Le fichier d'empreintes ne porte donc aucun compte.
case "$enregistre" in "~/"*) enregistre="${HOME:-}${enregistre#\~}" ;; esac
source_depot=""
# UN NOM DE DOSSIER N'IDENTIFIE PAS UN DÉPÔT. Les pistes acceptaient tout voisin homonyme
# portant un noyau/, et rendaient alors un RETARD calculé sur un dépôt sans rapport. On exige
# donc que le commit inscrit à la pose EXISTE chez le candidat. Quand la version est inconnue,
# il n'y a rien à confronter, et le nom reste le seul critère disponible.
pose_pour_piste=$(grep '^# version-noyau:' "$empreintes" | cut -d' ' -f3)
for piste in "${NOYAU_METHODE:-}" "$enregistre" "$cible/../structure_projet" "$cible/../methodo"; do
    [ -n "$piste" ] || continue
    # Le même piège qu'à l'installateur : dans un worktree et dans un sous-module, .git est un
    # FICHIER. Tester « -d .git » rejetait toutes les pistes, et le retard n'était jamais
    # vérifié alors que le script croyait le vérifier.
    git -C "$piste" rev-parse --git-dir >/dev/null 2>&1 || continue
    [ -d "$piste/noyau" ] || continue
    if [ "$pose_pour_piste" != "inconnue" ] && [ -n "$pose_pour_piste" ]; then
        git -C "$piste" cat-file -e "${pose_pour_piste}^{commit}" 2>/dev/null || continue
    fi
    source_depot="$piste"; break
done
actuelle=""
# Le tampon posé est le dernier commit qui a TOUCHÉ noyau/. On le compare au même repère, sinon
# tout commit hors noyau déclencherait un faux retard.
[ -n "$source_depot" ] && actuelle=$(git -C "$source_depot" log -1 --format=%H -- noyau 2>/dev/null || echo "")

if [ -z "$actuelle" ] || [ "$pose" = "inconnue" ]; then
    echo "⚠️  RETARD NON VÉRIFIÉ — le dépôt du noyau est introuvable." >&2
    echo "    Cherché, dans l'ordre : la variable NOYAU_METHODE, le chemin enregistré à la pose," >&2
    echo "    puis ../structure_projet et ../methodo à côté du projet." >&2
    echo "    Le bricolage, lui, a bien été vérifié ci-dessus." >&2
elif [ "$pose" != "$actuelle" ]; then
    retard=$(git -C "$source_depot" rev-list --count "$pose..$actuelle" -- noyau 2>/dev/null || echo "?")
    echo "⚠️  RETARD — le projet porte le noyau ${pose:0:8}, le noyau est à ${actuelle:0:8}." >&2
    echo "    $retard version(s) d'écart. Mettre à jour : bash <noyau>/installer.sh $cible" >&2
    [ "$strict" = 1 ] && fail=1
fi

# ── 3) Le périmètre lui-même : une ligne retirée sortait un fichier du contrôle ────────────────
# La boucle du volet 1 ne vérifie que ce qui est ÉNUMÉRÉ dans .noyau-empreintes. Ce fichier
# n'était couvert par aucune empreinte et par aucun contrôle. Retirer une ligne suffisait donc à
# sortir un fichier du noyau du périmètre, définitivement et sans un mot. Le « NE PAS ÉDITER À
# LA MAIN » de son en-tête est une consigne, pas une mécanique.
#
# LA COMPARAISON N'A DE SENS QU'À VERSION ÉGALE. Un projet simplement EN RETARD porte moins
# d'empreintes que le noyau courant, et l'accuser de bricolage serait un faux positif. On ne
# compare donc la liste que si le projet est à jour.
if [ -n "$source_depot" ] && [ -n "$actuelle" ] && [ "$pose" = "$actuelle" ]; then
    absentes=""
    # CE QUE GIT SUIT, ET RIEN D'AUTRE. Un « find » ramassait les artefacts ignorés, à
    # commencer par les __pycache__ que les outils du noyau créent dès qu'on les lance. Tout
    # projet à jour se voyait alors refuser ses commits pour un fichier qui n'a jamais fait
    # partie du noyau.
    # ON LIT LE COMMIT, PAS L'INDEX. « ls-files » rend l'index du dépôt source, alors que la
    # condition d'entrée juste au-dessus porte sur un COMMIT. Un simple « git add » chez la
    # source faisait donc refuser les commits de TOUS les projets installés, et le remède
    # affiché — relancer l'installateur — est refusé de son côté tant que le noyau n'est pas
    # commité. Impasse complète, causée par l'état de travail d'un autre dépôt.
    #
    # Le séparateur zéro, et pas le retour à la ligne : sans lui, git cite « docs/étape.md »
    # entre guillemets, le préfixe ne se retire plus et le fichier devient introuvable.
    while IFS= read -r -d '' rel; do
        [ -n "$rel" ] || continue
        rel="${rel#noyau/}"
        grep -qF "  $rel" "$empreintes" || absentes="$absentes\n  $rel"
    done < <(git -C "$source_depot" -c core.quotePath=false ls-tree -r -z --name-only \
                 "$actuelle" -- noyau)
    if [ -n "$absentes" ]; then
        echo "❌ HORS PÉRIMÈTRE — ces fichiers du noyau ont été sortis des empreintes :" >&2
        printf '%b\n' "$absentes" >&2
        echo "   Plus rien ne les surveille. Le fichier d'empreintes ne s'édite pas à la main," >&2
        echo "   il se régénère : bash <noyau>/installer.sh $cible" >&2
        fail=1
    fi
fi

if [ "$fail" -ne 0 ]; then
    printf '\n\033[1;31m❌ verifier-noyau : le projet a dérivé du noyau.\033[0m\n'
    exit 1
fi
printf '\n\033[1;32m✅ verifier-noyau : aucun fichier du noyau bricolé ni manquant.\033[0m\n'
