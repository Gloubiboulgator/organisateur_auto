#!/usr/bin/env bash
# garde-options-sans-cas.sh — REFUSE l'envoi à l'admin d'un questionnaire dont une option à
# choisir ne dit pas dans quel cas elle gagne, en douze signes au moins, ou n'a pas sa maquette.
#
# POURQUOI. Le 2026-10-09, un questionnaire d'un projet équipé offrait, sur presque chaque
# question, une recommandée évidente entre deux options écrites pour perdre. La règle « Trois
# réponses possibles, toutes défendables. Jamais une évidente entre deux repoussoirs » existait,
# chargée à chaque session, et n'a pas tenu. Le modèle de page ne demandait qu'un `pourquoi`,
# qui défend la recommandée. Ce garde exige le champ `gagneSi` sur chaque option : une option
# qui ne peut pas le remplir est un leurre, et ça se voit avant que l'admin le lise.
#
# LA MAQUETTE. Le 2026-11-17, un questionnaire portait une capture de l'écran actuel par
# question, et aucune option dessinée. L'admin n'a pas pu choisir. Chaque option porte donc son
# `image`, sauf une question qui se dit sans écran par `sansEcran`.
#
# NE VOIT PAS un `gagneSi` écrit pour perdre, une image qui ne montre pas l'option, une question
# posée dans l'échange, ni une page de questions bâtie hors du modèle, sans tableau QUESTIONS.
# LA LECTURE de la page vit dans questionnaire_publie.py, partagée avec
# garde-questions-illisibles.sh.
# ÉCHOUE OUVERT : toute charge illisible, ou un fichier sans QUESTIONS lisible, sort en zéro.
set -uo pipefail
charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0
lecteur="$(dirname "$0")/questionnaire_publie.py"
# UNE SEULE LECTURE de la page pour les deux fautes, chacune préfixée par sa sorte.
fautes=$(printf '%s' "$charge" | python3 "$lecteur" options-et-maquettes 2>/dev/null) || exit 0
manque=$(printf '%s\n' "$fautes" | sed -n 's/^cas //p' | tr '\n' ' ' | sed 's/ *$//')
sans_maquette=$(printf '%s\n' "$fautes" | sed -n 's/^maquette //p' | tr '\n' ' ' | sed 's/ *$//')
[ -n "$manque$sans_maquette" ] || exit 0
raisons=()
if [ -n "$manque" ]; then
  raisons+=("Options sans gagneSi d au moins douze signes, ${manque}. Chaque option a choisir dit dans quel cas elle gagne, regle de docs/ton-des-echanges.md, « Trois reponses possibles, toutes defendables ». Une option qui ne peut pas le dire est un leurre : la reecrire, ou passer la question en texte a valider (options:VALIDER).")
fi
if [ -n "$sans_maquette" ]; then
  raisons+=("Options sans maquette, ${sans_maquette}. Chaque option a choisir porte son image, la variante posee sur l ecran reel, regle de docs/ton-des-echanges.md, « Pour ce qui se voit ». Elle s ecrit image:{src, alt}, propre a l option : ni la capture de la question, ni la meme image qu une autre option, ni la maquette d exemple du modele. Une question qui n a pas d ecran, ni capture, le dit dans son champ sansEcran, en douze signes au moins.")
fi
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Questionnaire refuse : %s"}}\n' "${raisons[*]}"
exit 0
