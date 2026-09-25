#!/usr/bin/env bash
# garde-arriere-plan.sh — refuse au premier plan les commandes qui vont durer.
#
# POURQUOI CE GARDE EXISTE
# -------------------------------------
# L'exécuteur de commandes de l'agent tue toute commande au premier plan au bout de dix
# minutes. Une suite de tests en prend huit, une moisson en prend trente. Lancées au premier
# plan, elles sont tuées, et le travail est refait.
#
# Le problème n'est PAS l'ignorance de cette limite. L'agent l'a rencontrée deux fois le
# 2026-08-16, a écrit une consigne entre les deux, et l'a quand même enfreinte la seconde
# fois. La consigne nommait pourtant le geste exact, la boucle d'attente au premier plan.
# Une règle qui demande d'estimer une durée échoue, parce que l'estimation est le point
# faible. Ce hook ne demande rien à estimer : il reconnaît une liste fermée de motifs.
#
# CE QU'IL REFUSE
# ---------------
# Une commande qui contient l'un des motifs de LONGUES, ou une boucle d'attente
# `until … sleep`, alors qu'elle n'est PAS lancée en arrière-plan. La réponse dit quoi faire.
#
# La boucle d'attente compte autant que le travail attendu, et c'est le cas oublié : mettre
# la commande longue à l'abri puis l'attendre au premier plan ne déplace le problème que
# d'un cran, l'attente durant exactement aussi longtemps.
#
# COMMENT IL SAIT
# ---------------
# Le drapeau `run_in_background` n'apparaît dans la charge du hook que lorsqu'il vaut vrai,
# vérifié en journalisant trois appels. Son absence signifie premier plan.
#
# INSTALLATION — aucune. Déclaré dans le `.claude/settings.json` versionné, qui suit le
# clone. La règle vit dans `docs/garde-fous.md`, section « Les gardes d'agent ».
#
# IL ÉCHOUE OUVERT, ET C'EST VOULU
# --------------------------------
# Un hook `PreToolUse` qui plante bloque l'outil qu'il surveille. Ce script n'utilise que
# bash et grep, sans dépendance, et sort en zéro sur tout chemin inattendu.
set -uo pipefail

charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0

# Liste FERMÉE. On l'allonge quand un cas se présente, on ne devine pas.
#
# Le motif est volontairement GROSSIER, et ne distingue pas une invocation d'une mention. Une
# première version essayait de le faire, en exigeant un début de commande. Elle était fausse :
# le hook lit la charge JSON entière, où le début d'une commande n'est pas un début de ligne,
# et quatre cas sur douze sortaient à l'envers. Mieux vaut un garde simple et prévisible.
#
# Faux positif connu, et ASSUMÉ : chercher le mot dans la doc le déclenche sans rien lancer, et
# se fait refuser. L'outil de recherche dédié n'est pas concerné, lui. Ce prix est celui d'un
# garde simple, et il reste payé volontiers.
#
# CE QUI N'ÉTAIT PAS ASSUMÉ, mesuré en séance : un motif NOYÉ DANS UN MOT PLUS LONG. Une lecture
# d'historique a été refusée parce qu'un nom de BRANCHE contenait le mot, sans qu'aucune commande
# longue ne soit lancée. Ce refus ne protège de rien, et son contournement consiste à épeler le
# mot autrement, ce qui est pire que le mal. Chaque motif doit donc finir sur autre chose qu'une
# lettre, un chiffre, un tiret ou un souligné. Les deux bornes servent chacune un cas mesuré :
# celle de DROITE laisse passer « ..motif-git-action », celle de GAUCHE laisse passer
# « feature/bump-motif ». Aucune des deux seule ne suffit.
#
# DEUX FAMILLES DE MOTIFS, PARCE QUE LA BORNE DE DROITE COÛTE. Elle fait perdre les commandes
# dont le nom CONTINUE après le motif. Un motif de COMMANDE la porte quand même, faute de mieux.
# Un motif de PRÉFIXE, qui désigne une famille de scripts, n'a que la borne de gauche : sans
# quoi « npm run build-prod » et « npm run build_all » échappaient au garde.
#
# LIMITE ASSUMÉE, mesurée : une commande dont le nom prolonge un motif de COMMANDE échappe. Le
# cas connu est la forme « <motif>-3 » de certaines distributions. La distinguer d'un nom de
# branche demanderait de savoir où commence une commande, décision déjà essayée puis retirée.
# L'ANCIEN NOM DE VARIABLE RESTE UN REPLI, ET IL REJOINT LES PRÉFIXES. Scinder les motifs en
# deux familles a renommé le réglage. Sans repli, un projet qui avait posé l'ancien nom perdait
# TOUS ses motifs sans un mot, et le garde cessait de refuser ses commandes longues.
#
# Le repli le versait d'abord dans la famille des COMMANDES, celle qui porte la borne de DROITE.
# Un motif de forme préfixe — et le défaut livré à l'époque, « moissonner- », en était un — ne
# reconnaissait alors plus rien : « moissonner-annonces --tout » passait, seul le motif nu était
# refusé. Le repli préservait la variable et désarmait le garde, l'inverse de ce qu'il visait.
# Un motif hérité vaut donc PRÉFIXE, la lecture la plus proche de ce que ces projets avaient, et
# celle qui ne perd aucun refus. Le prix est un refus de plus sur la forme « <motif>-3 », qui est
# le bon côté de l'erreur pour un garde.
#
# Les motifs LONGS dépendent du projet. Ils se règlent par l'environnement, sans toucher au
# noyau. La boucle d'attente, elle, vaut partout : mettre la commande longue à l'abri puis
# l'attendre au premier plan ne déplace le problème que d'un cran.
# ET IL REMPLACE, IL NE S'AJOUTE PAS. L'ancien réglage était un « :- » : le poser écrasait
# TOUTE la liste par défaut. Le repli l'ajoutait aux défauts, si bien qu'un projet qui avait
# délibérément RÉTRÉCI son garde les récupérait sans un mot — mesuré, une commande que ce
# projet laissait passer se faisait refuser. Un repli qui change le comportement n'est pas un
# repli. Les nouveaux noms, eux, restent maîtres : poser l'un d'eux désactive l'héritage.
COMMANDES="${GARDE_MOTIFS_COMMANDES:-pytest|gradlew}"
PREFIXES="${GARDE_MOTIFS_PREFIXES:-npm run build}"
if [ -n "${GARDE_MOTIFS_LONGS:-}" ] \
   && [ -z "${GARDE_MOTIFS_COMMANDES:-}" ] && [ -z "${GARDE_MOTIFS_PREFIXES:-}" ]; then
    COMMANDES=""
    PREFIXES="$GARDE_MOTIFS_LONGS"
fi

# UNE FAMILLE VIDE NE DONNE PAS « () ». Ce groupe vide reconnaît la chaîne vide, donc TOUT, et
# le garde refuserait la moindre commande. Chaque famille n'entre dans le motif que si elle
# porte quelque chose ; si les deux sont vides, seule la boucle d'attente reste gardée.
familles=""
[ -n "$COMMANDES" ] && familles="($COMMANDES)([^-[:alnum:]_]|$)"
if [ -n "$PREFIXES" ]; then
    [ -n "$familles" ] && familles="$familles|"
    familles="$familles$PREFIXES"
fi
if [ -n "$familles" ]; then
    LONGUES="([^-[:alnum:]_]|^)($familles)|until[^\"]*sleep"
else
    LONGUES="until[^\"]*sleep"
fi

# Le `--` est indispensable : le motif commence par `-m`, que grep prendrait pour une option.
if printf '%s' "$charge" | grep -qE -- "$LONGUES"; then
    if ! printf '%s' "$charge" | grep -qE -- '"run_in_background"[[:space:]]*:[[:space:]]*true'; then
        cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commande LONGUE au premier plan refusee : l executeur tue a 10 minutes, et une suite de tests, un build ou une boucle d attente depassent. Relance-la avec run_in_background, et attends-la avec une boucle elle aussi en arriere-plan. Voir scripts/garde-arriere-plan.sh."}}
JSON
        exit 0
    fi
fi
exit 0
