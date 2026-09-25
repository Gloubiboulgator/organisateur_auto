#!/usr/bin/env bash
# reglages.sh — les réglages d'un projet pour apk-test, lus par les scripts du skill.
#
# POURQUOI CE FICHIER EXISTE
# --------------------------
# Les scripts d'origine portaient le nom du paquet Android en dur, à onze endroits. Un projet
# neuf aurait dû les recopier et les retoucher, donc bricoler un fichier figé du noyau. Ici, un
# projet écrit ses valeurs UNE fois, dans un fichier à lui, et les scripts du skill les lisent.
#
# COMMENT ÇA MARCHE
# -----------------
# Ce fichier se SOURCE, il ne se lance pas. Il lit `apk-test.env` à la racine du dépôt, un fichier
# de lignes CLE=valeur. Toute clé se surcharge par une variable d'environnement du même nom, ce
# dont la CI se sert pour passer ce qu'elle tient en secret. Le chemin du fichier lui-même se
# surcharge par APK_TEST_REGLAGES.
#
# ORDRE DE RÉSOLUTION : l'environnement d'abord, le fichier ensuite, la valeur par défaut enfin.
# Une clé REQUISE sans valeur arrête le script en la nommant. Aucune valeur par défaut ne désigne
# un projet réel : l'exemple du skill est `fr.exemple.app`.
#
# LES CLÉS, avec leur rôle, sont décrites dans references/reglages-et-fiches.md. Ce fichier ne
# les explique pas une seconde fois.

echouer_reglage() { printf 'apk-test : %s\n' "$1" >&2; exit 1; }

_racine_depot() {
  git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null
}

# Le fichier, lu ligne à ligne. Une clé déjà posée par l'environnement n'est pas écrasée.
_lire_fichier() {
  fichier="$1"
  [ -f "$fichier" ] || return 0
  while IFS= read -r ligne || [ -n "$ligne" ]; do
    case "$ligne" in ''|'#'*) continue ;; esac
    cle="${ligne%%=*}"
    valeur="${ligne#*=}"
    case "$cle" in *[!A-Z0-9_]*) echouer_reglage "clé illisible dans $fichier : « $cle »" ;; esac
    # `${!cle+x}` vaut « x » si la variable est déjà posée, même vide. L'environnement gagne.
    [ -n "${!cle+x}" ] && continue
    printf -v "$cle" '%s' "$valeur"
  done < "$fichier"
}

charger_reglages() {
  racine="$(_racine_depot)"
  fichier="${APK_TEST_REGLAGES:-${racine:+$racine/apk-test.env}}"
  [ -n "$fichier" ] && _lire_fichier "$fichier"

  # Les requises, sans défaut. Le message nomme la clé ET l'endroit où l'écrire.
  for cle in PAQUET ACTIVITE_PRINCIPALE; do
    [ -n "${!cle:-}" ] || echouer_reglage "réglage requis absent : $cle
      À écrire dans ${fichier:-apk-test.env} à la racine du projet, ou à passer par
      l'environnement. Voir references/reglages-et-fiches.md du skill."
  done

  # Les autres, avec leur défaut. Chacune se dérive du paquet ou des conventions du gabarit.
  : "${PAQUET_TEST:=$PAQUET.test}"
  : "${RUNNER:=androidx.test.runner.AndroidJUnitRunner}"
  : "${DOSSIER_APPAREIL:=/sdcard/Android/data/$PAQUET/files/Pictures/parcours}"
  : "${NOM_FILM:=navigation.mp4}"
  : "${TEST_FILME:=parcoursDeNavigationFilme}"
  : "${TAG_JOURNAL:=ParcoursVisuel}"
  : "${ARG_JETON:=jetonTest}"
  : "${PERMISSIONS:=android.permission.POST_NOTIFICATIONS}"
  : "${TESTS_EXCLUS:=}"
  : "${CROCHET_APRES_INSTALLATION:=}"
  : "${MOUTURES_SEUIL_DERIVE:=debug}"
  : "${ECRANS_EXCLUS:=}"
  : "${TAG_BASE:=play/*}"
  : "${SEUIL_CHARGE:=8}"
  : "${PARCOURS_KT:=}"
  : "${ECRANS_GLOBS:=}"
  : "${ARTEFACT_PARCOURS:=}"
  : "${MAQUETTES:=}"              # lu par rapatrier-parcours.sh, pour l'étape 4 de la grille
  : "${SEUIL_SCENE:=0.3}"
  : "${PAS_FILM:=5}"
}

# Une clé requise seulement par CERTAINS scripts. Chacun l'exige au moment où il s'en sert,
# pour qu'un `--verdict` joué sur un journal n'exige pas le chemin d'un fichier Kotlin.
exiger_reglage() {
  cle="$1"
  [ -n "${!cle:-}" ] || echouer_reglage "réglage requis absent : $cle
      Ce script s'en sert. À écrire dans apk-test.env, voir references/reglages-et-fiches.md."
}
