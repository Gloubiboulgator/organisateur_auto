#!/usr/bin/env bash
# rapatrier-parcours.sh — ramène l'artefact d'un run sur la machine, et le prépare au jugement.
#
# POURQUOI CE FICHIER EXISTE
# --------------------------
# Les preuves mécaniques disent qu'un parcours a tourné, que la machine était vivante, que le film
# se décode. Aucune ne regarde CE QUI EST MONTRÉ. Le run 31471955570 du projet d'origine passait
# toutes les preuves de l'époque, et l'app n'avait jamais pris l'écran. Ce niveau-là, le jugement
# sur les images, demande un lecteur. Ce script lui prépare le dossier, dans l'ordre où il doit
# être lu.
#
# CE QU'IL FAIT, DANS L'ORDRE
# ---------------------------
# 1. Télécharge l'artefact du run par `gh`, dans un dossier local.
# 2. Rejoue les trois contrôles mécaniques sur les fichiers rapatriés : santé de la machine,
#    verdict, film. Une machine malade ARRÊTE là : ses images ne veulent rien dire, et les juger
#    reviendrait à imputer à l'app les défauts d'un Android à l'agonie.
# 3. Découpe le film en images fixes, pour qu'un lecteur qui ne lit pas la vidéo voie ce qui vit
#    ENTRE deux captures. Un bandeau système a vécu quinze secondes entre deux photos au run
#    31509968766, invisible sur toutes, visible sur le film seul.
# 4. Imprime un relevé : verdicts, comptes, et le chemin de chaque dossier à lire.
#
# CE QU'IL N'EST PAS
# ------------------
# Il ne juge rien lui-même. Le jugement suit la grille du skill, references/grille-de-jugement.md,
# et se rend en session. Rien ne le lance non plus : c'est l'étape 4 de /apk-test.
#
# COMMENT ON S'EN SERT
# --------------------
#     bash .claude/skills/apk-test/scripts/rapatrier-parcours.sh <run> [<dossier>] [--sans-jeton]
#
# <run> est l'identifiant du run, ou son compteur affiché. <dossier> vaut ./parcours-<run> par
# défaut. Deux outils sont exigés, et leur absence arrête tout en nommant le paquet : `gh`, qui
# télécharge, et `ffmpeg`, qui découpe. Réglages lus : ARTEFACT_PARCOURS (requis), SEUIL_SCENE et
# PAS_FILM (la découpe), plus ceux des trois contrôles.
#
# `--sans-jeton` dit que le run a tourné SANS jeton de test. L'absence de film y est normale,
# `Assume` ayant sauté le parcours filmé. Le défaut est l'inverse, un run AVEC jeton, parce que
# c'est le seul qu'on rapatrie pour juger des images. L'artefact ne porte pas cette information :
# le journal du jeton est celui du job, pas celui de l'appareil. On la DEMANDE donc, plutôt que
# de la deviner, et le relevé nomme ce qu'il a supposé.
set -uo pipefail

positionnels=()
sans_jeton=0
for arg in "$@"; do
  case "$arg" in
    --sans-jeton) sans_jeton=1 ;;
    *) positionnels+=("$arg") ;;
  esac
done
set -- "${positionnels[@]+"${positionnels[@]}"}"

run="${1:?usage: rapatrier-parcours.sh <run> [<dossier>] [--sans-jeton]}"
ICI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=reglages.sh
. "$ICI/reglages.sh"
charger_reglages
exiger_reglage ARTEFACT_PARCOURS
dossier="${2:-./parcours-$run}"
# Ce que `film_lisible` attend en troisième argument : une chaîne non vide vaut « jeton fourni ».
jeton_du_run="present"
[ "$sans_jeton" -eq 1 ] && jeton_du_run=""

for outil in gh ffmpeg; do
  command -v "$outil" >/dev/null 2>&1 || echouer_reglage "$outil est absent, rien n'a été rapatrié.
      gh : https://cli.github.com (paquet gh). ffmpeg : paquet ffmpeg de la distribution."
done

# ── 1. TÉLÉCHARGER ────────────────────────────────────────────────────────────────────────────
# Un compteur affiché (« 46 ») se traduit en identifiant par la liste des runs. Un identifiant
# à onze chiffres passe tel quel.
if [ "${#run}" -lt 8 ]; then
  identifiant=$(gh run list --limit 100 --json number,databaseId \
                  --jq ".[] | select(.number == $run) | .databaseId" 2>/dev/null | head -1)
  [ -n "$identifiant" ] || echouer_reglage "aucun run n'affiche le compteur $run parmi les cent derniers"
else
  identifiant="$run"
fi
mkdir -p "$dossier"
echo "run $identifiant, artefact $ARTEFACT_PARCOURS, vers $dossier"
gh run download "$identifiant" -n "$ARTEFACT_PARCOURS" -D "$dossier" \
  || echouer_reglage "le téléchargement a échoué. L'artefact existe-t-il encore sur ce run ?"

# ── 2. LES TROIS CONTRÔLES, DANS L'ORDRE ─────────────────────────────────────────────────────
# Le journal de chaque mouture, tel que parcours-emulateur.sh l'a écrit. Une mouture sans journal
# se dit, elle ne se saute pas en silence.
verdicts=()
malade=0
for journal in "$dossier"/logcat-*.txt; do
  [ -e "$journal" ] || { echo "aucun journal logcat-<mouture>.txt dans l'artefact"; break; }
  mouture=$(basename "$journal" .txt)
  mouture="${mouture#logcat-}"
  echo "══════════════════════ mouture : $mouture ══════════════════════"
  echo "── santé de la machine ──"
  if bash "$ICI/parcours-emulateur.sh" --sante "$journal"; then
    verdicts+=("$mouture : machine saine")
  else
    verdicts+=("$mouture : MACHINE MALADE, images non jugeables")
    malade=1
    continue
  fi
  echo "── verdict ──"
  if bash "$ICI/parcours-emulateur.sh" --verdict "$dossier/resultat-$mouture.txt" "$journal"; then
    verdicts+=("$mouture : verdict vert")
  else
    verdicts+=("$mouture : verdict ROUGE")
  fi
  echo "── film ──"
  # Le film se CHERCHE, il ne se devine pas. L'artefact porte la nidification du run 25 : c'est
  # le même rapatriement qui l'a produite, en amont. Un chemin plat ici ferait échouer le
  # contrôle sur un film parfait, et la découpe ci-dessous n'aurait jamais lieu.
  film="$(bash "$ICI/parcours-emulateur.sh" --trouver-film "$dossier/$mouture")"
  if [ ! -s "$film" ]; then
    if [ "$sans_jeton" -eq 1 ]; then
      verdicts+=("$mouture : pas de film, run annoncé sans jeton de test")
    else
      verdicts+=("$mouture : film ABSENT (run supposé lancé AVEC jeton — sinon --sans-jeton)")
    fi
    continue
  fi
  if bash "$ICI/parcours-emulateur.sh" --film "$film" "$journal" "$jeton_du_run"; then
    verdicts+=("$mouture : film regardable")
  else
    verdicts+=("$mouture : film ILLISIBLE")
    continue
  fi

  # ── 3. DÉCOUPER LE FILM ─────────────────────────────────────────────────────────────────────
  # Deux jeux d'images, dans un même dossier, horodatés dans leur nom pour se lire dans l'ordre.
  # Les changements d'écran, par le détecteur de scène de ffmpeg au seuil SEUIL_SCENE. Et une
  # image toutes les PAS_FILM secondes, plancher qui attrape un bandeau immobile que le détecteur
  # ne verrait pas. Le seuil et le pas sont posés faute de mesure, et imprimés pour être révisés.
  images="$dossier/$mouture/film"
  mkdir -p "$images"
  echo "── découpe du film (seuil de scène $SEUIL_SCENE, une image toutes les ${PAS_FILM}s) ──"
  # `-v info` sur CETTE passe, et c'est la seule qui en a besoin : `showinfo` écrit ses lignes au
  # niveau INFO, que `-v error` fait taire. Le relevé des changements sortait donc toujours vide,
  # alors que les images, elles, étaient bien écrites. Mesuré sur un film à deux coupes : zéro
  # correspondance avec `-v error`, deux avec `-v info`.
  ffmpeg -v info -i "$film" -vf "select='gt(scene,$SEUIL_SCENE)',showinfo" -vsync vfr \
         -frame_pts 1 "$images/scene-%06d.png" 2>&1 | grep -oE 'pts_time:[0-9.]+' | sed 's/^/  changement à /' || true
  ffmpeg -v error -i "$film" -vf "fps=1/$PAS_FILM" -frame_pts 1 "$images/pas-%06d.png" || true
  # Le nom porte l'index de trame, pas la seconde : on renomme par la seconde, lisible à l'œil.
  for f in "$images"/pas-*.png; do
    [ -e "$f" ] || break
    n=$(basename "$f" .png); n="${n#pas-}"; n=$((10#$n * PAS_FILM))
    mv "$f" "$images/$(printf 'pas-%04ds.png' "$n")"
  done
  echo "  images de scène : $(find "$images" -name 'scene-*.png' | wc -l)"
  echo "  images plancher : $(find "$images" -name 'pas-*.png' | wc -l)"
done

# ── 4. LE RELEVÉ ─────────────────────────────────────────────────────────────────────────────
echo "══════════════════════ relevé ══════════════════════"
printf '  %s\n' "${verdicts[@]}"
echo "  captures nommées : $(find "$dossier" -name '*.png' -not -path '*/film/*' | wc -l)"
echo "  échecs notés par le parcours : $(tr '\n' ' ' < "$dossier/echecs.txt" 2>/dev/null || echo 'fichier absent')"
echo "  à lire, dans cet ordre : ce relevé, puis $dossier/<mouture>/*.png, puis $dossier/<mouture>/film/"
if [ "$sans_jeton" -eq 1 ]; then
  echo "  run annoncé SANS jeton de test : l'absence de film n'a pas été punie."
fi
# L'étape 4 de la grille de jugement compare une capture à sa maquette, quand le projet en tient
# un dossier. Ce réglage n'avait aucun lecteur : il était déclaré, documenté, et mort. Le relevé
# est l'endroit juste pour le lire, puisqu'il dit au juge où regarder.
if [ -n "$MAQUETTES" ] && [ -d "$MAQUETTES" ]; then
  echo "  maquettes à comparer : $MAQUETTES ($(find "$MAQUETTES" -type f | wc -l) fichier(s))"
elif [ -n "$MAQUETTES" ]; then
  echo "  maquettes : $MAQUETTES est introuvable, rien à comparer."
fi
if [ "$malade" -eq 1 ]; then
  echo "  ⛔ une mouture a une machine malade : le jugement des images ne prétend pas juger l'app."
  exit 1
fi
exit 0
