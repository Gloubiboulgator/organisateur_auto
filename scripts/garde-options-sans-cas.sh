#!/usr/bin/env bash
# garde-options-sans-cas.sh — REFUSE l'envoi à l'admin d'un questionnaire dont une option à
# choisir ne dit pas dans quel cas elle gagne, en douze signes au moins.
#
# POURQUOI. Le 2026-10-09, un questionnaire d'un projet équipé offrait, sur presque chaque
# question, une recommandée évidente entre deux options écrites pour perdre. La règle « Trois
# réponses possibles, toutes défendables. Jamais une évidente entre deux repoussoirs » existait,
# chargée à chaque session, et n'a pas tenu. Le modèle de page ne demandait qu'un `pourquoi`,
# qui défend la recommandée. Ce garde exige le champ `gagneSi` sur chaque option : une option
# qui ne peut pas le remplir est un leurre, et ça se voit avant que l'admin le lise.
#
# NE VOIT PAS un `gagneSi` écrit pour perdre, une question posée dans l'échange, ni une page
# de questions bâtie hors du modèle, sans tableau QUESTIONS.
# LA LECTURE de la page vit dans questionnaire_publie.py, partagée avec
# garde-questions-illisibles.sh.
# ÉCHOUE OUVERT : toute charge illisible, ou un fichier sans QUESTIONS lisible, sort en zéro.
set -uo pipefail
charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0
manque=$(printf '%s' "$charge" | python3 "$(dirname "$0")/questionnaire_publie.py" options 2>/dev/null) || exit 0
[ -n "$manque" ] || exit 0
liste=$(printf '%s' "$manque" | tr '\n' ' ')
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Questionnaire refuse : options sans gagneSi d au moins douze signes, %s. Chaque option a choisir dit dans quel cas elle gagne, regle de docs/ton-des-echanges.md, « Trois reponses possibles, toutes defendables ». Une option qui ne peut pas le dire est un leurre : la reecrire, ou passer la question en texte a valider (options:VALIDER)."}}\n' "$liste"
exit 0
