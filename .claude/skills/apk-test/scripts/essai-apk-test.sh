#!/usr/bin/env bash
# essai-apk-test.sh — joue les tests des scripts du skill, à la main.
#
# POURQUOI CE FICHIER EXISTE
# --------------------------
# Les trois contrôles de parcours-emulateur.sh ont chacun un faux vert fondateur : une commande
# refusée déclarée réussie, une app jamais affichée déclarée vue, une machine morte déclarée
# saine. Les tests de scripts/tests/ les rejouent sur les sorties RÉELLES de ces runs. Sans un
# lanceur, ils dorment : pytest ignore les dossiers cachés, dont `.claude/`, et personne ne
# tape le chemin complet.
#
# CE QU'IL N'EST PAS
# ------------------
# Ce n'est PAS un garde-fou, et il n'a pas de ligne au registre. Rien ne le lance, ni hook, ni
# lint, ni contrôle de commit. Le brancher sur le pre-commit le ferait payer à chaque commit de
# chaque projet équipé, avec deux dépendances de plus, et un contrôle qui gêne se contourne.
#
# COMMENT ON S'EN SERT
# --------------------
#     bash .claude/skills/apk-test/scripts/essai-apk-test.sh              # tout
#     bash .claude/skills/apk-test/scripts/essai-apk-test.sh --sans-film  # sans ffmpeg
#
# `ffmpeg` absent est un REFUS : les cas du film fabriquent un vrai MP4, une imitation ne
# prouverait rien sur un format. `--sans-film` joue le reste en le sachant, et la sortie nomme
# les cas non joués. Un outil absent se signale, il ne se contourne pas.
set -uo pipefail

ici=$(cd "$(dirname "$0")" && pwd)
sans_film=0
[ "${1:-}" = "--sans-film" ] && sans_film=1

echouer() { printf 'essai : %s\n' "$1" >&2; exit 1; }

for outil in bash git python3; do
  command -v "$outil" >/dev/null 2>&1 || echouer "$outil est absent, rien n'a été joué"
done
python3 -c 'import pytest' 2>/dev/null || echouer "pytest est absent, rien n'a été joué.
      Installer : python3 -m pip install pytest"
if [ "$sans_film" -eq 0 ] && ! command -v ffmpeg >/dev/null 2>&1; then
  echouer "ffmpeg est absent, rien n'a été joué. Paquet ffmpeg de la distribution.
      Pour jouer le reste en le sachant : --sans-film"
fi

# Ni cache ni octets compilés : ce dossier est figé chez un projet équipé, et un fichier écrit
# ici par pytest ferait rougir son contrôle anti-dérive.
export PYTHONDONTWRITEBYTECODE=1
args=(-q -p no:cacheprovider)
[ "$sans_film" -eq 1 ] && args+=(-k "not film_decodable and not film_indecodable and not film_sans_duree")

python3 -m pytest "${args[@]}" "$ici/tests"
code=$?
[ "$sans_film" -eq 1 ] && echo "essai : joué SANS les trois cas du film (ffmpeg absent)"
exit "$code"
