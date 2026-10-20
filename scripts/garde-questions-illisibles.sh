#!/usr/bin/env bash
# garde-questions-illisibles.sh — REFUSE l'envoi à l'admin d'un questionnaire dont une question
# parle la langue du dépôt au lieu de celle de l'admin.
#
# POURQUOI. Le 2026-10-12, un questionnaire de quatorze cartes d'un projet équipé a reçu quatre
# « incompréhensible » et cinq cartes jamais touchées. Ses titres et ses contextes citaient des
# sigles de décision, des noms de fichiers et un nom d'outil, et aucune carte ne partait d'un
# moment que l'admin vit. La règle « Une scène d'abord » en est née, dans
# docs/ton-des-echanges.md.
#
# CE QU'IL VÉRIFIE, dans le tableau QUESTIONS. Chaque question à choisir porte une `scene` d'au
# moins quarante signes. Aucun titre, aucun « quand » et aucune scène ne contient un sigle à
# chiffre (PL2, MO1), un numéro d'issue (#140), un nom de fichier (.md, .js, .json, .html, .sh,
# .py, .css), un accent grave de code, ou un nom d'outil (mcp__).
# NE VOIT PAS une scène écrite dans le jargon sans sigle ni fichier, ni le contexte, ni les
# options. La lecture à froid de la règle couvre le sens.
# SE TROMPE sur un mot courant qui a la forme d'un sigle, comme F1 ou PS5. Le refus dit alors
# de l'écrire en toutes lettres, ce qui coûte une phrase. Laisser passer un vrai sigle coûtait
# un questionnaire incompris.
# LA LECTURE de la page vit dans questionnaire_publie.py, partagée avec
# garde-options-sans-cas.sh.
# UN QUESTIONNAIRE QUE LE LECTEUR NE SAIT PAS LIRE DEMANDE CONFIRMATION. Le taire laissait
# passer toute une page sur une seule tournure qu'il ne connaît pas.
# ÉCHOUE OUVERT : toute charge illisible, ou une page qui n'est pas un questionnaire, sort en zéro.
set -uo pipefail
charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0
fautes=$(printf '%s' "$charge" | python3 "$(dirname "$0")/questionnaire_publie.py" illisibles 2>/dev/null) || exit 0
[ -n "$fautes" ] || exit 0
illisibles=$(printf '%s\n' "$fautes" | sed -n 's/^?//p' | tr '\n' ' ')
fautes=$(printf '%s\n' "$fautes" | grep -v '^?')
if [ -z "$fautes" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Questionnaire que le garde ne sait pas lire : %s. Son tableau QUESTIONS porte une tournure inconnue du lecteur, donc ni la scene ni le jargon ne sont verifies. Le simplifier, ou confirmer l envoi en le relisant soi-meme."}}\n' "$illisibles"
    exit 0
fi
# Douze fautes au plus dans le message. Le reste se compte, pour que l'agent sache qu'un second
# refus suivra s'il ne corrige que celles-là.
liste=$(printf '%s\n' "$fautes" | head -12 | sed 's/$/ ;/' | tr '\n' ' ')
reste=$(( $(printf '%s\n' "$fautes" | wc -l) - 12 ))
[ "$reste" -gt 0 ] && liste="$liste et $reste autres ;"
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Questionnaire refuse, questions dans la langue du depot : %s Chaque question part d une scene vecue par l admin, sans sigle, fichier ni nom de code. Les sigles et les fichiers restent dans les sources. Un mot courant pris pour un sigle, comme F1, s ecrit en toutes lettres. Un nom de produit pris pour un fichier, comme Node.js, perd son extension."}}\n' "$liste"
exit 0
