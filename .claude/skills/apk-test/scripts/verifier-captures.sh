#!/usr/bin/env bash
# Contrôle « TOUT ÉCRAN MODIFIÉ EST PHOTOGRAPHIÉ ».
#
# Un écran touché par un lot mais absent du parcours visuel est un écran livré SANS AVOIR ÉTÉ VU.
# C'est ce qui s'est produit chez le projet d'origine le 2026-08-09 : un correctif clavier
# touchait deux écrans, personne n'a regardé ni l'un ni l'autre avant de livrer, et le bandeau
# couvrait la saisie sur les deux.
#
# Ce script compare les ÉCRANS MODIFIÉS depuis le dernier build publié aux CAPTURES produites par
# le parcours, et échoue s'il en manque. Les écrans sont les fichiers que le réglage ECRANS_GLOBS
# désigne. Le nom d'un écran se dérive du nom de son fichier : sans extension, sans le préfixe
# `activity_`, sans le suffixe `Activity`, en minuscules. Le gabarit Kotlin du skill nomme ses
# captures ainsi, pour que « 04-creation.png » couvre l'écran « creation ».
#
# Usage : verifier-captures.sh <dossier-des-captures>
#
# Volontairement TOLÉRANT dans deux cas, pour ne pas transformer un garde-fou en obstacle :
#   • aucune capture du tout : le parcours a été ignoré faute de jeton de test, on AVERTIT.
#     (Échouer ici punirait une absence de configuration, pas un défaut de l'app.)
#   • aucune base de comparaison : premier run, ou historique absent, on AVERTIT.
set -uo pipefail

captures="${1:?usage: verifier-captures.sh <dossier-des-captures>}"
ICI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=reglages.sh
. "$ICI/reglages.sh"
charger_reglages
exiger_reglage ECRANS_GLOBS
exiger_reglage PARCOURS_KT
racine="$(git -C "$ICI" rev-parse --show-toplevel)"

# CE QUI COMPTE COMME UNE CAPTURE : une IMAGE, et le nom du FICHIER, jamais son chemin.
#
# Le dossier que le job passe ici porte aussi ce que le parcours y a écrit — `echecs.txt`,
# `resultat-<mouture>.txt`, `logcat-<mouture>.txt`, et le film. Deux conséquences, trouvées en
# revue au portage vers ce skill :
#   • le tester « vide » le rendait TOUJOURS non vide, donc la tolérance ci-dessous était
#     inatteignable : un run sans jeton partait en mode strict et rougissait sur chaque écran ;
#   • un écran nommé « navigation » était « photographié » par `navigation.mp4`, un écran
#     « debug » par `logcat-debug.txt`. Un contrôle satisfait par un fichier qui ne montre rien
#     ne contrôle rien.
images_du_dossier() {
    find "$1" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
         -iname "${2:-*}" 2>/dev/null
}

if [ ! -d "$captures" ] || [ -z "$(images_du_dossier "$captures")" ]; then
    echo "::warning::aucune capture produite. Le parcours visuel a-t-il tourné ? (jeton de test absent ?)"
    exit 0
fi

# La base de comparaison : le dernier build publié, repéré par un tag du motif TAG_BASE. À défaut
# de tag, on retombe sur le commit précédent, imparfait mais toujours mieux que rien.
#
# `--verify --quiet` n'est PAS cosmétique (run 32254733286). `git rev-parse` ÉCRIT SON ARGUMENT
# sur sa sortie standard quand il ne sait pas le résoudre, avant de sortir en 128. La base valait
# alors la chaîne « HEAD~1 », jamais vide, et le garde-fou ci-dessous restait inatteignable : le
# script imprimait un succès sans avoir rien comparé. Le clone d'une chaîne CI ne portant qu'UN
# commit, c'est arrivé à chaque run. D'où le `fetch-depth: 0` du gabarit de workflow : sans lui,
# ce script devient jaune à chaque run, et un garde-fou qui crie toujours finit ignoré.
base="$(git -C "$racine" describe --tags --match "$TAG_BASE" --abbrev=0 2>/dev/null || true)"
[ -z "$base" ] && base="$(git -C "$racine" rev-parse --verify --quiet 'HEAD~1^{commit}' || true)"
if [ -z "$base" ]; then
    echo "::warning::AUCUNE BASE DE COMPARAISON RÉSOLUBLE. CE CONTRÔLE N'A RIEN VÉRIFIÉ."
    echo "::warning::ni tag $TAG_BASE, ni commit parent. Le clone est-il superficiel (fetch-depth) ?"
    exit 0
fi

# Les écrans touchés, d'après les motifs du projet. ECRANS_GLOBS est une liste de pathspecs git
# séparés par des espaces, volontairement non guillemetée ici pour que git les reçoive un à un.
# shellcheck disable=SC2086
modifies="$(git -C "$racine" diff --name-only "$base" -- $ECRANS_GLOBS 2>/dev/null || true)"

if [ -z "$modifies" ]; then
    # On nomme la base RÉSOLUE, pas l'expression demandée : c'est ce qui distingue « j'ai comparé
    # et rien n'a bougé » de « je n'ai comparé à rien ».
    echo "✅ comparé à $base, aucun écran modifié, rien à photographier de plus."
    exit 0
fi

echo "Écrans touchés depuis $base :"
manquants=()
for f in $modifies; do
    nom="$(basename "$f" | sed -e 's/\.[^.]*$//' -e 's/^activity_//' -e 's/Activity$//' | tr '[:upper:]' '[:lower:]')"
    # Les fragments d'interface sans écran propre (feuilles, éléments de liste) ne sont pas des
    # destinations : on ne peut pas exiger une capture d'un morceau qui n'existe pas seul. Le
    # projet les nomme dans ECRANS_EXCLUS, un motif de `case`. Vide par défaut : un projet neuf
    # exige tout, et retire ce qu'il a nommé.
    # Les motifs se testent UN PAR UN : un `|` sorti d'une variable n'est pas une alternative
    # pour `case`, c'est un caractère, et « feuille_*|*_item » n'excluait alors plus rien.
    exclu=0
    IFS='|' read -ra motifs <<< "$ECRANS_EXCLUS"
    for motif in "${motifs[@]}"; do
        [ -n "$motif" ] || continue
        # shellcheck disable=SC2254
        case "$nom" in $motif) exclu=1 ;; esac
    done
    if [ "$exclu" -eq 1 ]; then
        echo "  · $nom (porté par le parcours, non exigible séparément)"; continue
    fi

    # Recherche RÉCURSIVE : les images sont rangées dans un sous-dossier par mouture. Le nom
    # reste cherché en SOUS-CHAÎNE, et c'est voulu : « 04-creation.png » couvre l'écran
    # « creation ». C'est le TYPE de fichier qui borne, pas le nom.
    if images_du_dossier "$captures" "*$nom*" | grep -q .; then
        echo "  ✅ $nom, photographié"
    else
        echo "  ❌ $nom, AUCUNE capture"
        manquants+=("$nom")
    fi
done

if [ ${#manquants[@]} -gt 0 ]; then
    echo "::error::écrans modifiés sans capture : ${manquants[*]}. Ajoute-les au parcours ($PARCOURS_KT) avant de livrer"
    exit 1
fi

echo "✅ chaque écran modifié a sa capture."
