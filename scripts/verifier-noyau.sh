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
# LE DOSSIER PRINCIPAL, pas le worktree. Le dépôt du noyau se cherche aussi à côté de lui. Depuis
# un worktree, le voisin du worktree n'est pas celui du projet, et le retard n'était jamais
# comparé. Joué sur une pose neuve, le 2026-10-30. rappel-retard-noyau.sh l'avait déjà appris.
# git le nomme en tête de « worktree list ». Le parent du dossier commun se trompait pour un
# sous-module, dont le dossier commun vit sous .git/modules du projet hôte. Relevé par la revue
# de la 111, le 2026-11-19.
# Un dépôt nu n'est pas un dossier de projet : son worktree de tête ne compte pas.
principal=$(git -C "$cible" worktree list --porcelain 2>/dev/null |
            awk 'BEGIN { RS = ""; FS = "\n" } NR == 1 { if ($0 !~ /\nbare(\n|$)/) { sub(/^worktree /, "", $1); print $1 }; exit }')
[ -n "$principal" ] || principal="$cible"
# Un worktree lié a son propre dossier git, distinct du dossier commun.
commun=$(git -C "$cible" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || commun=""
propre=$(git -C "$cible" rev-parse --path-format=absolute --git-dir 2>/dev/null) || propre=""
lie=""
[ -n "$commun" ] && [ "$(cd -P "$propre" 2>/dev/null && pwd)" != "$(cd -P "$commun" 2>/dev/null && pwd)" ] && lie=1
empreintes="$cible/.noyau-empreintes"
# Un fichier d'empreintes ignoré par git n'est pas dans un worktree. Il se lit au dossier principal.
# Un fichier suivi, lui, ne se remplace pas : sa suppression indexée doit rester visible.
if [ ! -f "$empreintes" ] && git -C "$cible" check-ignore -q .noyau-empreintes 2>/dev/null; then
    empreintes="$principal/.noyau-empreintes"
fi

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
    # Des empreintes lues au dossier principal décrivent sa pose, pas celle de ce worktree. Une
    # pose plus récente là-bas fait accuser une branche qui ne l'a pas encore. Relevé par la
    # revue de la 111, le 2026-11-19.
    if [ "$empreintes" != "$cible/.noyau-empreintes" ]; then
        echo "   Empreintes lues au dossier principal : si sa pose est plus récente, fusionner sa" >&2
        echo "   branche ici, puis recommencer." >&2
    fi
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
for piste in "${NOYAU_METHODE:-}" "$enregistre" "$cible/../structure_projet" "$cible/../methodo" \
             "$principal/../structure_projet" "$principal/../methodo"; do
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
# LE REPÈRE EST LA BRANCHE PRINCIPALE DU NOYAU, jamais la branche ouverte dans son dossier. Le
# 2026-11-07, ce dossier était sur une branche de travail plus ancienne que le noyau posé. Le
# contrôle criait au retard à chaque commit, et il ratait le vrai, quatre commits arrivés sur la
# copie distante. La copie distante passe d'abord, puisque les fusions y arrivent. Elle n'est
# fraîche que du dernier fetch, et ce contrôle n'en lance aucun, pour ne jamais dépendre du réseau.
# Sans aucune branche principale, la branche ouverte reste le seul repère, et l'alerte le dit.
# UNE BRANCHE PRINCIPALE LOCALE EN AVANCE L'EMPORTE. Une fusion locale pas encore poussée ne se
# voit pas sur la copie distante, et le retard sur elle serait tu.
reference=""
ouverte=""
installer=""
if [ -n "$source_depot" ]; then
    for ref in "$(git -C "$source_depot" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null)" \
               refs/remotes/origin/main refs/remotes/origin/master refs/heads/main refs/heads/master; do
        [ -n "$ref" ] || continue
        git -C "$source_depot" rev-parse -q --verify "$ref^{commit}" >/dev/null 2>&1 || continue
        reference="$ref"; break
    done
    for locale in refs/heads/main refs/heads/master; do
        [ -n "$reference" ] && [ "$reference" != "$locale" ] || continue
        git -C "$source_depot" rev-parse -q --verify "$locale^{commit}" >/dev/null 2>&1 || continue
        git -C "$source_depot" merge-base --is-ancestor "$reference" "$locale" 2>/dev/null || continue
        reference="$locale"; break
    done
    # Le tampon posé est le dernier commit qui a TOUCHÉ noyau/. On le compare au même repère,
    # sinon tout commit hors noyau déclencherait un faux retard.
    actuelle=$(git -C "$source_depot" log -1 --format=%H "${reference:-HEAD}" -- noyau 2>/dev/null || echo "")
    # L'installateur pose la branche ouverte. Si elle n'a pas le noyau du repère, le remède affiché
    # ne lèverait pas l'alerte.
    ouverte=$(git -C "$source_depot" log -1 --format=%H HEAD -- noyau 2>/dev/null || echo "")
    # Le remède donne le chemin réel du noyau, et vise le dossier principal : posé dans un
    # worktree, le noyau repartirait avec lui.
    # Cité, pour qu'un chemin à espace se colle tel quel.
    installer="$(printf '%q' "$(cd "$source_depot" 2>/dev/null && pwd -P || echo "$source_depot")/installer.sh") $(printf '%q' "$principal")"
fi

# UNE POSE SANS VERSION NE SE COMPARE PAS. Vide, elle ferait lire « ..repère » comme
# « HEAD..repère », et un retard nul ferait taire toute alerte.
a_jour=""
if [ -n "$actuelle" ] && { [ -z "$pose" ] || [ "$pose" = "inconnue" ]; }; then
    echo "⚠️  RETARD NON VÉRIFIÉ — .noyau-empreintes ne note pas la version posée." >&2
    echo "    La régénérer : bash $installer" >&2
elif [ -z "$actuelle" ]; then
    echo "⚠️  RETARD NON VÉRIFIÉ — le dépôt du noyau est introuvable." >&2
    echo "    Cherché, dans l'ordre : la variable NOYAU_METHODE, le chemin enregistré à la pose," >&2
    echo "    puis ../structure_projet et ../methodo à côté du projet et de son dossier principal." >&2
    echo "    Le bricolage, lui, a bien été vérifié ci-dessus." >&2
elif [ "$pose" = "$actuelle" ]; then
    a_jour=1
# LE RETARD SE JUGE SUR LE CONTENU, PAS SUR LES COMMITS. Un changement suivi de son retour en
# arrière, ou une fusion qui ne garde pas les commits, laisse le même noyau. Le contrôle criait
# pourtant « RETARD » à chaque commit, et bloquait sous --strict. Relevé par deux revues le
# 2026-11-07. L'arbre noyau/ de la pose égal à celui du repère vaut « à jour ».
elif arbre_pose=$(git -C "$source_depot" rev-parse -q --verify "$pose:noyau" 2>/dev/null) && \
     [ -n "$arbre_pose" ] && \
     [ "$arbre_pose" = "$(git -C "$source_depot" rev-parse -q --verify "$actuelle:noyau" 2>/dev/null)" ]; then
    a_jour=1
else
    # Un noyau posé plus récent que le repère n'est pas en retard. Seuls comptent les commits du
    # noyau que le repère a et que la pose n'a pas. Le même avertissement disait « 0 version
    # d'écart » sur un projet en avance.
    retard=$(git -C "$source_depot" rev-list --count "$pose..$actuelle" -- noyau 2>/dev/null) || retard=""
    if [ -z "$retard" ]; then
        # UN RETARD INCALCULABLE N'EST PAS UN RETARD. Le script écrivait « ? version(s) d'écart »,
        # bloquait sous --strict et sautait le périmètre sans le dire. Relevé par une revue le
        # 2026-11-07.
        echo "⚠️  RETARD NON VÉRIFIÉ — git n'a pas su compter l'écart entre ${pose:0:8} et ${actuelle:0:8}." >&2
        echo "    Le périmètre des empreintes n'a donc pas été comparé non plus." >&2
    elif [ "$retard" = "0" ]; then
        a_jour=1
    else
        echo "⚠️  RETARD — le projet porte le noyau ${pose:0:8}, le noyau est à ${actuelle:0:8}." >&2
        echo "    $retard version(s) d'écart. Mettre à jour : bash $installer" >&2
        # Des empreintes suivies dans un worktree lié ne bougent qu'avec sa branche. La pose
        # faite au dossier principal n'y arrive que par une fusion. Relevé par la revue de la
        # 111, le 2026-11-19.
        if [ -n "$lie" ] && [ "$empreintes" = "$cible/.noyau-empreintes" ] && \
           git -C "$cible" ls-files --error-unmatch .noyau-empreintes >/dev/null 2>&1; then
            echo "    Ce worktree suit ses propres empreintes : y fusionner ensuite la pose commitée." >&2
        fi
        [ -n "$reference" ] || echo "    Repère : la branche ouverte du noyau, faute de branche principale." >&2
        if [ -n "$reference" ] && [ "$ouverte" != "$actuelle" ]; then
            echo "    Avant, ouvrir le dossier du noyau sur ${reference#refs/*/} à jour : l'installateur" >&2
            echo "    pose sa branche ouverte, pas le repère." >&2
        fi
        [ "$strict" = 1 ] && fail=1
    fi
fi

# ── 3) Le périmètre lui-même : une ligne retirée sortait un fichier du contrôle ────────────────
# La boucle du volet 1 ne vérifie que ce qui est ÉNUMÉRÉ dans .noyau-empreintes. Ce fichier
# n'était couvert par aucune empreinte et par aucun contrôle. Retirer une ligne suffisait donc à
# sortir un fichier du noyau du périmètre, définitivement et sans un mot. Le « NE PAS ÉDITER À
# LA MAIN » de son en-tête est une consigne, pas une mécanique.
#
# LA COMPARAISON N'A DE SENS QU'À VERSION ÉGALE. Un projet simplement EN RETARD porte moins
# d'empreintes que le noyau courant, et l'accuser de bricolage serait un faux positif. On ne
# compare donc la liste que si le projet est à jour. Elle se lit dans la pose, qui peut être plus
# récente que le repère : un projet posé depuis une branche pas encore fusionnée est à jour.
if [ -n "$source_depot" ] && [ -n "$a_jour" ]; then
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
                 "$pose" -- noyau)
    if [ -n "$absentes" ]; then
        echo "❌ HORS PÉRIMÈTRE — ces fichiers du noyau ont été sortis des empreintes :" >&2
        printf '%b\n' "$absentes" >&2
        echo "   Plus rien ne les surveille. Le fichier d'empreintes ne s'édite pas à la main," >&2
        echo "   il se régénère : bash $installer" >&2
        fail=1
    fi
fi

if [ "$fail" -ne 0 ]; then
    printf '\n\033[1;31m❌ verifier-noyau : le projet a dérivé du noyau.\033[0m\n'
    exit 1
fi
printf '\n\033[1;32m✅ verifier-noyau : aucun fichier du noyau bricolé ni manquant.\033[0m\n'
