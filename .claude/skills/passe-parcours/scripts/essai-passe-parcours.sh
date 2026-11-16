#!/usr/bin/env bash
# essai-passe-parcours.sh — joue les tests des scripts du skill, à la main.
#
# POURQUOI CE FICHIER EXISTE
# --------------------------
# Les tests de scripts/tests/ dorment sans lanceur. pytest ignore les dossiers cachés, dont
# `.claude/`, et personne ne tape le chemin complet. Même raison, et même forme, que le lanceur
# d'apk-test.
#
# CE QU'IL N'EST PAS
# ------------------
# Ce n'est PAS un garde-fou. Rien ne le lance, ni hook, ni lint. Il ne lance aucun testeur, ni
# émulateur, ni navigateur : le pilote y joue contre un faux adb.
#
# COMMENT ON S'EN SERT
# --------------------
#     bash .claude/skills/passe-parcours/scripts/essai-passe-parcours.sh
set -uo pipefail

ici=$(cd "$(dirname "$0")" && pwd)

echouer() { printf 'essai : %s\n' "$1" >&2; exit 1; }

for outil in python3 ffmpeg ffprobe; do
  command -v "$outil" >/dev/null 2>&1 || echouer "$outil est absent, rien n'a été joué"
done
python3 -c 'import pytest' 2>/dev/null || echouer "pytest est absent, rien n'a été joué.
      Installer : python3 -m pip install pytest"

# Ni cache ni octets compilés : ce dossier est figé chez un projet équipé, et un fichier écrit
# ici par pytest ferait rougir son contrôle anti-dérive.
export PYTHONDONTWRITEBYTECODE=1
python3 -m pytest -q -p no:cacheprovider "$ici/tests"
