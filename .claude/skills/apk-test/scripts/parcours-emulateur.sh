#!/usr/bin/env bash
#
# Joue le parcours visuel d'une app Android dans le téléphone virtuel de l'intégration continue.
#
# D'OÙ VIENT CE FICHIER
# ---------------------
# Il est la version générique d'un script né chez un projet équipé, le 2026-08-10, et durci par
# une vingtaine de runs perdus jusqu'au 2026-08-21. Chaque bloc porte le numéro du run qui l'a
# rendu nécessaire. Tout ce qui nommait ce projet est devenu un réglage, lu par reglages.sh.
#
# POURQUOI UN FICHIER, ET PAS LE BLOC `script:` DU WORKFLOW (run 31428980946)
# ---------------------------------------------------------------------------
# L'action `reactivecircus/android-emulator-runner` ne lance PAS le bloc `script:` comme un
# programme : elle le découpe ligne par ligne et exécute chaque ligne isolément. Une boucle `for`
# écrite sur plusieurs lignes se retrouve donc amputée, et l'interpréteur répond :
#
#     /usr/bin/sh: 1: Syntax error: end of file unexpected (expecting "done")
#
# La parade est d'appeler un fichier, une seule ligne côté YAML, un vrai script ici.
#
# UTILISATION
#     bash .claude/skills/apk-test/scripts/parcours-emulateur.sh "debug release"
#
# Le paramètre est la liste des MOUTURES à passer, séparées par des espaces :
#   - `debug`   : la version de travail, non minifiée, celle qu'on teste au quotidien ;
#   - `release` : la version telle que le magasin la reçoit, passée au réducteur R8. C'est la
#                 seule qui révèle les casses dues au renommage des classes.
#
# Variables d'environnement attendues :
#   JETON_TEST   jeton du compte d'essai, injecté depuis un secret de la CI. Sans lui, l'app reste
#                à l'écran d'accueil et le parcours ne montre presque rien.
#   COUPLES      dossier contenant les paquets produits à l'étape de compilation (défaut /tmp/couples)
#   SORTIE       dossier où déposer film, captures et journaux (défaut /tmp/parcours)
#
# Les réglages du projet (paquet, activité, chemins) viennent de apk-test.env, voir reglages.sh.

set -u

ICI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=reglages.sh
. "$ICI/reglages.sh"
charger_reglages

# ── LE VERDICT ────────────────────────────────────────────────────────────────────────────────
#
# Rendu appelable seul (`--verdict <fichier> [<journal>]`) pour qu'il soit TESTABLE sans
# émulateur : voir scripts/tests/test_parcours_emulateur.py, qui lui soumet de vraies sorties
# relevées sur une machine de build.
#
# RÉGRESSION FONDATRICE (2026-08-10, run 31431701893) : la première version ne cherchait que des
# marques d'ÉCHEC. Or le jeton de test manquait, la commande a été refusée par Android, qui a
# répondu par sa page d'aide, et AUCUN test n'a tourné. Cette sortie ne contient aucune marque
# d'échec : le run a donc été déclaré VERT alors que rien ne s'était exécuté. Un contrôle qui ne
# sait pas distinguer « tout va bien » de « il ne s'est rien passé » ne contrôle rien.
#
# D'où le principe inverse : on exige une preuve POSITIVE de succès, et le doute vaut échec.
#
# DEUXIÈME RÉGRESSION (2026-08-11, run 31471955570) : JUnit disait « OK (3 tests) », 13 images
# étaient là, et pourtant l'app n'avait JAMAIS été à l'écran. Un dialogue système bloqué (ANR du
# launcher et demande de permission) recouvrait tout le parcours. Le journal SYSTÈME écrit une
# ligne au moment précis où une fenêtre finit de se dessiner. Elle n'est jamais apparue pour
# l'activité principale : la preuve la plus directe qu'on ait que l'app n'a pas pris l'écran.
verdict() {
  fichier="$1"
  journal="${2:-}"
  [ -s "$fichier" ] || { echo "sortie vide, aucun test n'a tourné"; return 1; }
  # Un plantage du processus, ou un test tombé : les deux marques que JUnit laisse.
  grep -qE "FAILURES!!!|Process crashed|INSTRUMENTATION_CODE: 0" "$fichier" && {
    echo "des tests ont échoué (ou le processus a planté)"; return 1; }
  # La preuve positive : JUnit résume toujours par « OK (n tests) » quand il a fini.
  grep -qE "^OK \([0-9]+ test" "$fichier" || {
    echo "aucun compte rendu de test dans la sortie, la commande n'a probablement pas été acceptée"
    return 1; }
  # Preuve que l'écran principal a RÉELLEMENT été affiché, écrite par Android, pas par nous.
  # Journal absent (pas de deuxième argument) : rétrocompatible, le contrôle est simplement sauté.
  if [ -n "$journal" ] && [ -s "$journal" ]; then
    grep -qF "Displayed $PAQUET/$ACTIVITE_PRINCIPALE" "$journal" || {
      echo "$ACTIVITE_PRINCIPALE n'a jamais été affichée selon le journal système. L'app est"
      echo "probablement restée bloquée derrière un dialogue (ANR, permission) tout du long."
      return 1; }
  fi
  return 0
}

# ── LA SANTÉ DE LA MACHINE ────────────────────────────────────────────────────────────────────
#
# Rendu appelable seul (`--sante <journal>`), même motif que le verdict.
#
# POURQUOI (2026-08-16, run 31967863064). Le run est vert, treize captures et un film sont là,
# `verdict()` passe, et pourtant l'Android SOUS l'app s'est fait tuer DEUX FOIS pendant le run :
#
#     E ActivityManager: ANR in com.android.systemui
#     E ActivityManager: Load: 45.83 / 18.2 / 6.74          (sur un AVD à 2 cœurs)
#     I WindowManager: WIN DEATH: Window{… StatusBar}
#     I WindowManager: WIN DEATH: Window{… NavigationBar0}
#
# Conséquence VISIBLE sur les artefacts : plus aucune barre d'état sur les images, une bande noire
# en haut d'un écran, une autre en bas du film, et le bandeau système « Viewing full screen ».
# Autant de « défauts d'interface » qui ne sont PAS ceux de l'app. Une session d'analyse s'y est
# laissé prendre et allait les imputer à l'app.
#
# CE QUI FAIT ÉCHOUER (le doute vaut échec) : la mort d'une fenêtre système, ou l'ANR de SystemUI
# ou de notre app. Dans ces trois cas les images ne valent plus rien.
# CE QUI FAIT SEULEMENT AVERTIR : une charge élevée sans dégât constaté. La lenteur seule abîme
# les captures (écrans photographiés trop tôt) sans les rendre fausses.
#
# Le seuil de charge, réglage SEUIL_CHARGE, vaut 8 par défaut. Il est posé faute d'observation de
# ce qui est normal sur un runner : à réviser à la première alerte qui tombe sur un parcours dont
# les images sont, elles, parfaitement lisibles.
sante_machine() {
  journal="$1"
  [ -s "$journal" ] || { echo "journal système absent, santé de la machine inconnue"; return 0; }
  malade=0

  # Une fenêtre système qui meurt = barre d'état ou barre de navigation absente de TOUTES les
  # images qui suivent. C'est le symptôme le plus trompeur : il ressemble à un défaut de mise en
  # page de l'app.
  fenetres=$(grep -cE "WIN DEATH: Window\{[^}]*(StatusBar|NavigationBar)" "$journal" || true)
  if [ "${fenetres:-0}" -gt 0 ]; then
    echo "::error::les barres système d'Android sont mortes $fenetres fois pendant le parcours."
    echo "::error::Les captures et le film ne montrent PAS l'app telle qu'elle s'affiche."
    malade=1
  fi

  # ANR = l'application ne répond plus. Celui de SystemUI emporte l'affichage entier. Celui de
  # notre app est un vrai défaut, invisible autrement puisque `hide_error_dialogs` masque la boîte.
  for paquet in com.android.systemui "$PAQUET"; do
    n=$(grep -c "ANR in $paquet" "$journal" || true)
    if [ "${n:-0}" -gt 0 ]; then
      echo "::error::$paquet a cessé de répondre $n fois pendant le parcours (ANR)"
      malade=1
    fi
  done

  # La charge est relevée par Android lui-même dans le rapport d'ANR. On garde la plus forte vue :
  # elle chiffre l'état de la machine au moment où les images ont été prises.
  charge=$(grep -oE "Load: [0-9]+\.[0-9]+" "$journal" | cut -d' ' -f2 | sort -rn | head -1)
  if [ -n "$charge" ]; then
    echo "charge maximale relevée par Android : $charge"
    if [ "${charge%%.*}" -ge "$SEUIL_CHARGE" ]; then
      echo "::warning::machine saturée pendant le parcours (charge $charge). Les écrans mettent"
      echo "::warning::plusieurs secondes à s'afficher, les captures peuvent partir trop tôt."
    fi
  fi

  [ "$malade" -eq 0 ]
}

# ── OÙ EST LE FILM ? ──────────────────────────────────────────────────────────────────────────
#
# Pas forcément à la racine du dossier de sortie, et c'est tout le piège (run 25 du projet
# d'origine, 2026-09-17). Le bloc de trace ANR crée `$SORTIE/$mouture` AVANT le rapatriement. La
# destination existe donc déjà, et `adb pull` y niche le contenu dans un sous-dossier.
#
# Le journal de ce run le montre en toutes lettres. Les fichiers atterrissent sous
# `/tmp/parcours/debug/parcours/`, alors que le contrôle lisait `/tmp/parcours/debug/`. Onze
# captures, trois tests verts, un film de 3 953 964 octets, et un job rouge sur « aucun film ».
# Le compte de captures, lui, passait : il cherche en récursif, comme `captures-attendues.py`.
#
# ON NE FIGE PAS LA DISPOSITION, ON CHERCHE. Faire pointer le contrôle une couche plus bas
# marcherait aujourd'hui et retomberait le jour où le rapatriement cesse de nicher. Ce
# comportement appartient à un outil tiers, et personne ne l'a observé ici. Chercher ne dépend
# de rien, et survit aux deux dispositions.
#
# Le chemin plat reste le repli. C'est celui qui part dans le message quand il n'y a aucun film,
# et c'est le seul cas où cette fonction ne trouve rien.
chemin_du_film() {
  dossier="$1"
  film_trouve=$(find "$dossier" -type f -name "$NOM_FILM" -print -quit 2>/dev/null) || film_trouve=""
  echo "${film_trouve:-$dossier/$NOM_FILM}"
}

# ── LE FILM EST-IL REGARDABLE ? ───────────────────────────────────────────────────────────────
#
# Ce contrôle tient à `ffprobe`. Son absence fait rougir : un contrôle qui saute en silence est un
# contrôle qu'on croit avoir. Un film présent mais indécodable rougit aussi. Celui du run
# 32254733286 n'avait pas d'atome `moov`, donc aucune image lisible, et il est parti comme
# artefact valide.
#
# Le troisième argument dit si le jeton de test était fourni. Sans lui, le parcours filmé est sauté
# par `Assume` et l'absence de film est NORMALE. La punir rendrait rouge tout run lancé pour
# vérifier autre chose, et un garde-fou qui rougit toujours finit contourné.
film_lisible() {
  film="$1"
  journal="${2:-}"
  jeton="${3:-}"

  if [ ! -s "$film" ]; then
    if [ -n "$jeton" ]; then
      echo "::error::aucun film alors que le jeton de test était fourni. Le parcours filmé"
      echo "::error::devait tourner. Voir « screenrecord » dans le journal système."
      return 1
    fi
    echo "::warning::aucun film. Sans jeton de test, le parcours filmé est sauté."
    return 0
  fi

  if ! command -v ffprobe >/dev/null 2>&1; then
    echo "::error::ffprobe absent de cette machine : la lisibilité du film n'a PAS pu être"
    echo "::error::vérifiée. C'est une panne d'outillage du runner, pas un défaut de l'app."
    return 1
  fi

  # Une durée vide sur un fichier non vide, c'est la signature d'un enregistrement jamais fermé :
  # l'atome `moov` s'écrit à la fermeture, et sans lui aucune image n'est décodable.
  # « N/A » n'est pas une durée non plus (vérifié sur un flux H.264 brut : ffprobe l'imprime et
  # sort en 0). Seul un entier compte.
  duree_film=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$film" 2>/dev/null | cut -d. -f1)
  case "$duree_film" in
    ''|*[!0-9]*)
      echo "::error::le film est présent mais INDÉCODABLE (pas de durée lisible, atome moov absent)."
      echo "::error::L'enregistrement n'a pas été fermé proprement, aucune image ne peut en sortir."
      return 1 ;;
  esac

  # Durée du test filmé, lue dans le journal système (horodatages de JUnit lui-même).
  [ -s "$journal" ] || { echo "film : ${duree_film}s (parcours de durée inconnue)"; return 0; }
  debut=$(grep -m1 "TestRunner: started: $TEST_FILME" "$journal" | awk '{print $2}')
  fin=$(grep -m1 "TestRunner: finished: $TEST_FILME" "$journal" | awk '{print $2}')
  [ -n "$debut" ] && [ -n "$fin" ] || { echo "film : ${duree_film}s (parcours non horodaté)"; return 0; }
  s_debut=$(date -d "$debut" +%s 2>/dev/null || echo 0)
  s_fin=$(date -d "$fin" +%s 2>/dev/null || echo 0)
  duree_test=$((s_fin - s_debut))
  echo "film : ${duree_film}s pour un parcours de ${duree_test}s"
  # Le seuil des deux tiers RESTE un avertissement : on ne durcit pas un seuil sans mesure.
  if [ "$duree_test" -gt 0 ] && [ "$duree_film" -lt $((duree_test * 2 / 3)) ]; then
    echo "::warning::le film ne couvre que ${duree_film}s des ${duree_test}s du parcours. Un"
    echo "::warning::défaut transitoire peut s'y cacher. Voir « screenrecord » dans le logcat."
  fi
  return 0
}

if [ "${1:-}" = "--verdict" ]; then
  verdict "${2:?usage: --verdict <fichier> [<journal>]}" "${3:-}" && echo "succès" && exit 0
  exit 1
fi

if [ "${1:-}" = "--sante" ]; then
  sante_machine "${2:?usage: --sante <journal>}" && echo "machine saine" && exit 0
  exit 1
fi

if [ "${1:-}" = "--film" ]; then
  film_lisible "${2:?usage: --film <film.mp4> [<journal>] [<jeton>]}" "${3:-}" "${4:-}" \
    && echo "film regardable" && exit 0
  exit 1
fi

# Même raison que les trois drapeaux ci-dessus : la localisation du film se juge sans louer un
# émulateur. C'est ce qui manquait au run 25, dont le défaut vivait dans la construction du
# chemin, jamais dans `film_lisible`. Consommé par `tests/test_parcours_emulateur.py` et par
# `rapatrier-parcours.sh`, qui rapatrie un artefact porteur de la même nidification.
if [ "${1:-}" = "--trouver-film" ]; then
  chemin_du_film "${2:?usage: --trouver-film <dossier>}"
  exit 0
fi

# ── LE PARCOURS LUI-MÊME ──────────────────────────────────────────────────────────────────────

MOUTURES="${1:-debug}"
COUPLES="${COUPLES:-/tmp/couples}"
SORTIE="${SORTIE:-/tmp/parcours}"
JETON_TEST="${JETON_TEST:-}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

# Le seuil de captures se DÉRIVE du parcours, il ne s'écrit pas. Il faut donc savoir où le lire.
exiger_reglage PARCOURS_KT
command -v adb >/dev/null 2>&1 || echouer_reglage "adb est absent, rien n'a été joué. Ce script
      tourne dans le job de l'émulateur, où le SDK Android le fournit."

mkdir -p "$SORTIE"
: > "$SORTIE/echecs.txt"

# Les dialogues d'erreur des AUTRES apps système (ANR, crash) ne s'affichent plus, un réglage
# standard des bancs de test CI (run 31471955570). Ne masque PAS un plantage de NOTRE app :
# celui-ci reste détecté par le verdict JUnit (INSTRUMENTATION_CODE: 0) et par le journal système.
adb shell settings put global hide_error_dialogs 1

# Dire si le jeton est là, sans jamais l'afficher. On le saura en lisant le journal du run, au
# lieu de le supposer.
if [ -n "$JETON_TEST" ]; then
  echo "jeton de test : présent (${#JETON_TEST} caractères)"
else
  echo "::warning::jeton de test ABSENT, la variable JETON_TEST n'est pas définie. Le parcours"
  echo "::warning::s'arrêtera à l'écran d'accueil : une seule capture au lieu d'une douzaine."
fi

for mouture in $MOUTURES; do
  echo "══════════════════════ mouture : $mouture ══════════════════════"

  # Deux paquets sont nécessaires : l'application, et le « robot » qui la pilote. Ce dernier
  # porte `androidTest` dans son nom, d'où le filtre, qui l'écarte de la première recherche.
  app=$(find "$COUPLES" -name "*-$mouture.apk" ! -name "*androidTest*" | head -1)
  robot=$(find "$COUPLES" -path "*androidTest*$mouture*" -name '*.apk' | head -1)
  echo "  app   = ${app:-AUCUNE}"
  echo "  robot = ${robot:-AUCUN}"

  if [ -z "$app" ] || [ -z "$robot" ]; then
    echo "::error::paquet manquant pour la mouture $mouture, l'étape de compilation ne l'a pas produit"
    exit 1
  fi

  # `adb` est l'outil qui parle au téléphone (ici virtuel). `-r` remplace une version déjà
  # installée, `-t` autorise une application de test.
  adb install -r -t "$app"
  adb install -r -t "$robot"

  # Les permissions sont accordées D'AVANCE (run 31471955570) : demandée dès le démarrage sur
  # API 33 et plus, celle des notifications affiche sinon sa boîte de dialogue par-dessus l'app,
  # et plus rien n'y est cliquable. `|| true` : sur une image Android plus ancienne la permission
  # n'existe pas, `pm grant` échoue sans conséquence.
  for permission in $PERMISSIONS; do
    adb shell pm grant "$PAQUET" "$permission" 2>/dev/null || true
  done

  # Ce qu'un projet doit faire de PLUS entre l'installation et le lancement (un accès système à
  # accorder, un réglage à poser) vit dans un script à lui, nommé par le réglage. Le projet
  # d'origine y accordait un accès Notification Listener, dont le résultat devait être RELU
  # après coup : Android valide la liste et écarte ce qu'il n'a pas approuvé (run 31505523569).
  if [ -n "$CROCHET_APRES_INSTALLATION" ]; then
    echo "── crochet après installation : $CROCHET_APRES_INSTALLATION ──"
    bash "$CROCHET_APRES_INSTALLATION" "$mouture" || echo "::warning::le crochet a rendu $?"
  fi

  # On vide le journal système juste avant l'instrumentation : ce qu'on y lira ensuite viendra de
  # CETTE mouture seule. Sans quoi un « Displayed » d'une mouture réussie couvrirait à tort
  # l'échec de la suivante.
  adb logcat -c

  # `am instrument` demande à Android de LANCER les tests. `-w` veut dire « attends la fin »,
  # `-e` passe une valeur au test, ici le jeton du compte d'essai.
  #
  # LE JETON N'EST PASSÉ QUE S'IL EXISTE (run 31431701893). Écrire `-e jeton "$JETON_TEST"` avec
  # une valeur vide ne transmet pas « une valeur vide » : la commande traverse un second
  # interpréteur, celui du téléphone, qui fait purement disparaître l'argument. Le nom du robot se
  # retrouve alors avalé comme valeur du jeton, et Android refuse la commande. Aucun test ne tourne.
  if [ -n "$JETON_TEST" ]; then
    set -- -e "$ARG_JETON" "$JETON_TEST"
  else
    set --
  fi
  # Les tests qu'un projet lance AILLEURS, sous d'autres conditions, sortent de cette passe.
  if [ -n "$TESTS_EXCLUS" ]; then
    set -- "$@" -e notClass "$TESTS_EXCLUS"
  fi

  # On NOTE l'échec sans sortir tout de suite : les images et le film sont justement ce qu'on veut
  # voir quand un test tombe. Le job rougit à la fin, une fois les artefacts récupérés. Un
  # `|| true` posé ici ferait au contraire passer un échec pour un succès.
  adb shell am instrument -w "$@" "$PAQUET_TEST/$RUNNER" 2>&1 | tee "$SORTIE/resultat-$mouture.txt"

  # Journal de CETTE mouture seule : c'est lui qui porte la preuve d'affichage lue par verdict().
  adb logcat -d > "$SORTIE/logcat-$mouture.txt" || true

  if ! verdict "$SORTIE/resultat-$mouture.txt" "$SORTIE/logcat-$mouture.txt"; then
    echo "$mouture" >> "$SORTIE/echecs.txt"
  fi

  # LA MACHINE ÉTAIT-ELLE VIVANTE quand ces images ont été prises ? Séparé du verdict à dessein :
  # le verdict juge ce que l'app a fait, celui-ci juge si ce qu'on voit veut dire quelque chose.
  if ! sante_machine "$SORTIE/logcat-$mouture.txt"; then
    echo "$mouture-machine" >> "$SORTIE/echecs.txt"
  fi

  # LA TRACE DE L'ANR. `sante_machine()` dit QUE l'app a gelé, jamais POURQUOI : la trace dort
  # dans le téléphone. Par quel chemin la lire, on l'ignore : `/data/anr` demande des droits
  # jamais observés sur un runner. Ce bloc essaie, et IMPRIME ce qu'il trouve, pour que le chemin
  # se décide sur une observation. Aucune porte d'échec, il ajoute une preuve, il n'en exige pas.
  traces="$SORTIE/$mouture/anr"
  mkdir -p "$traces"
  echo "── trace ANR : ce que la machine veut bien donner ──"
  echo "adb root  : $(adb root 2>&1 | tr -d '\r' | head -1)"
  adb wait-for-device >/dev/null 2>&1 || true
  echo "/data/anr : $(adb shell ls /data/anr 2>&1 | tr -d '\r' | tr '\n' ' ' | cut -c1-200)"
  if adb pull /data/anr "$traces" >/dev/null 2>&1; then
    echo "  rapatrié : $(find "$traces" -type f | wc -l) fichier(s)"
  else
    echo "  /data/anr illisible depuis cette machine"
  fi
  if grep -q "ANR in" "$SORTIE/logcat-$mouture.txt" 2>/dev/null; then
    adb shell dumpsys dropbox --print 2>/dev/null | head -500 > "$traces/dropbox.txt" || true
    echo "dropbox   : $(wc -l < "$traces/dropbox.txt" 2>/dev/null || echo 0) ligne(s) retenues"
  else
    echo "dropbox   : aucun ANR dans le journal, rien à en tirer"
  fi
  adb unroot >/dev/null 2>&1 || true
  adb wait-for-device >/dev/null 2>&1 || true

  # ARRÊTER LE FILM AVANT DE LE PRENDRE (run 32254733286). Le parcours durait 77 s pour une
  # limite demandée de 120 s : `screenrecord` enregistrait donc encore quand le test s'achevait,
  # et rien ne l'ARRÊTAIT. Il était abandonné, et son fichier jamais fermé.
  #
  # La croyance derrière ce bloc, « screenrecord n'écrit l'atome moov qu'à la fermeture », est une
  # supposition, jamais mesurée sur un runner. Le skill la fait ficher chez le projet sous la clé
  # screenrecord-moov-a-la-fermeture, avec son canari : ce bloc IMPRIME ce que pgrep trouve et la
  # taille à laquelle le fichier se stabilise. Un run sans processus et sans film lisible
  # invaliderait la prémisse, et le dirait dans le journal.
  restant=$(adb shell pgrep -l screenrecord 2>&1 | tr -d '\r')
  echo "screenrecord au moment du rapatriement : ${restant:-aucun processus}"
  adb shell pkill -INT screenrecord >/dev/null 2>&1 || true
  # La fermeture écrit l'atome `moov`, ce qui prend un instant. Rapatrier pendant l'écriture donne
  # le même symptôme que ne pas arrêter du tout, on attend donc que la taille cesse de bouger.
  FILM_TEL="$DOSSIER_APPAREIL/$NOM_FILM"
  precedente=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    taille=$(adb shell stat -c %s "$FILM_TEL" 2>/dev/null | tr -d '\r')
    [ "$taille" = "$precedente" ] && break
    precedente="$taille"
    sleep 1
  done
  echo "taille du film stabilisée à ${precedente:-inconnue} octets"

  # Le film et les captures sont écrits par le test dans le dossier privé de l'app. On les
  # rapatrie pour qu'ils partent en artefact. `|| true` : un parcours tombé avant la première
  # image ne doit pas masquer l'erreur réelle par une erreur de copie.
  adb pull "$DOSSIER_APPAREIL" "$SORTIE/$mouture" || true
  # Ce que pèse CHAQUE fichier : un total seul ne dit pas quand l'écriture du film s'est arrêtée.
  find "$SORTIE/$mouture" -type f -printf '%10s  %p\n' 2>/dev/null | sort -k2 || true

  film=$(chemin_du_film "$SORTIE/$mouture")
  if ! film_lisible "$film" "$SORTIE/logcat-$mouture.txt" "$JETON_TEST"; then
    echo "$mouture-film" >> "$SORTIE/echecs.txt"
  fi
  # Ce que le test lui-même a constaté de screenrecord (durée réelle, sortie, exception).
  grep "$TAG_JOURNAL.*screenrecord" "$SORTIE/logcat-$mouture.txt" | sed 's/^/  /' || true

  # LE PLANCHER N'EST PAS ZÉRO, IL EST DÉRIVÉ DU TEST. Une seule image sur la douzaine attendue
  # passait pour un succès, faute que rien ne sache combien il en fallait. L'attendu vient du
  # fichier Kotlin du parcours. Aucun nombre en dur : il se périmerait au premier écran ajouté.
  images=$(find "$SORTIE/$mouture" -name '*.png' 2>/dev/null | wc -l)
  echo "images rapportées pour $mouture : $images"

  # Le seuil dérivé ne vise que les moutures du réglage MOUTURES_SEUIL_DERIVE, `debug` par
  # défaut : R8 est réputé préserver les identifiants de ressource que vise le parcours, mais
  # personne ne l'a observé. On durcira sur une mesure.
  case " $MOUTURES_SEUIL_DERIVE " in
    *" $mouture "*)
      if [ -n "$JETON_TEST" ]; then set -- --avec-jeton; else set --; fi
      absentes=$("$PYTHON_BIN" "$ICI/captures-attendues.py" verifier \
                   "$SORTIE/$mouture" "$PARCOURS_KT" --arg-jeton "$ARG_JETON" "$@" 2>&1)
      case "$?" in
        0) echo "✅ chaque capture attendue est là." ;;
        1) echo "::error::captures attendues et ABSENTES : $absentes"
           echo "::error::l'app n'a pas montré ces écrans, relire la santé de la machine ci-dessus"
           echo "$mouture-captures" >> "$SORTIE/echecs.txt" ;;
        # L'EXTRACTION A CASSÉ. On ne se rabat PAS sur zéro : un contrôle qui saute en silence est
        # un contrôle qu'on croit avoir.
        *) echo "::error::le seuil de captures n'a pas pu être dérivé du parcours :"
           echo "$absentes" | sed 's/^/::error::  /'
           echo "$mouture-seuil-inderivable" >> "$SORTIE/echecs.txt" ;;
      esac ;;
    # Les autres moutures gardent l'ancien plancher : ZÉRO image est un échec. Le retirer leur
    # avait enlevé toute porte, un parcours release sans la moindre capture partait vert.
    *)
      if [ "$images" -eq 0 ]; then
        echo "::error::aucune capture rapportée pour $mouture, l'app n'a rien montré"
        echo "$mouture-captures" >> "$SORTIE/echecs.txt"
      fi ;;
  esac
done

# Le journal système complet, une mouture après l'autre : c'est là que se lisent les plantages,
# les exceptions et les messages de l'app pendant le parcours.
cat "$SORTIE"/logcat-*.txt > "$SORTIE/logcat.txt" 2>/dev/null || true

if [ -s "$SORTIE/echecs.txt" ]; then
  echo "::error::tests en échec sur : $(tr '\n' ' ' < "$SORTIE/echecs.txt")"
  exit 1
fi

echo "parcours terminé sans échec"
