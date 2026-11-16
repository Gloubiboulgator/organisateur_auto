#!/usr/bin/env bash
# essai-garde-perte-seche.sh — rejoue les cas du garde des pertes sèches, à la main.
#
# POURQUOI CE FICHIER EXISTE (2026-09-15)
# ---------------------------------------
# Le garde scripts/garde-perte-seche.sh a connu deux rondes de contournements en cinq jours. Six
# le 2026-09-10, trente-neuf le 2026-09-15, tous trouvés en lui JOUANT des commandes plutôt qu'en
# lisant son code. Les trois plus graves ne le trompaient pas, ils l'éteignaient : un chevron
# dans un message de commit, une variable inconnue derrière un `cd`, ou une commande assez
# longue pour que le harnais le tue. Un garde éteint rend une sortie vide, que le harnais lit
# comme « rien à signaler ».
#
# Le savoir de ces deux rondes vivait dans un dépôt d'essai monté à la main, qui mourait avec la
# session. La ronde suivante le refabriquait. C'est ce que ce fichier arrête.
#
# CE QU'IL N'EST PAS
# ------------------
# Ce n'est PAS un garde-fou, et il n'a pas de ligne au registre. Rien ne le lance, ni hook, ni
# lint, ni contrôle de commit. On l'appelle à la main, comme le prompt d'audit voisin.
#
# C'est un choix, pas un oubli. Le jeu monte un vrai dépôt git et joue tous les cas du fichier
# voisin, une centaine, ce qui coûte quelques secondes. Le brancher sur le pre-commit le ferait payer à
# chaque commit de chaque projet équipé, et le registre le dit : un contrôle qui gêne se
# contourne.
#
# COMMENT ON S'EN SERT
# --------------------
#     bash modeles/essai-garde-perte-seche.sh              # monte, joue, démonte
#     bash modeles/essai-garde-perte-seche.sh --garder     # laisse le dépôt d'essai en place
#
# Sortie en zéro si tous les cas concordent, en un sinon. Chaque écart est nommé.
#
# LE NOMBRE DE CAS NE S'ÉCRIT PAS DANS CET EN-TÊTE. Il y a vécu à trois endroits, et il a menti
# dès le premier ajout. Le seul compte qui fait foi est la ligne « CAS_ATTENDUS » du fichier
# voisin, que le script confronte à ce qu'il lit vraiment.
#
# CE QUE LE MONTAGE DOIT TENIR, ET QUE LA PREMIÈRE VERSION NE TENAIT PAS
# ----------------------------------------------------------------------
# Une revue a testé ce jeu PAR MUTATION, en recassant le garde correctif par correctif. Elle a
# montré qu'un montage raté jouait les cas quand même, et rendait des écarts
# qui ne disaient rien du garde. Le montage se vérifie donc, pièce par pièce, avant de jouer.
#
# Le dépôt d'essai ne peut PAS vivre sous /tmp. Le garde y voit du jetable, et la mutation le
# mesure : un HOME sous /tmp rend trente-cinq écarts, pas un vert. Le chemin est donc refusé,
# plutôt que décrit.
#
# Son dépôt est posé SOUS UN DOSSIER NOMMÉ « build ». Le garde a un correctif du 2026-09-10 qui
# borne la recherche des dossiers jetables à la racine du dépôt, sans quoi un projet rangé sous
# un tel nom n'est plus gardé du tout. Sans ce décor, ce correctif ne se mesure pas.
#
# Son nom de branche principale est imposé. Une machine qui nomme la sienne « master » et une
# autre « main » ne jouent pas les mêmes cas, et l'écart se lit comme un défaut du garde.
set -uo pipefail

ici=$(cd "$(dirname "$0")" && pwd)
GARDE="${GARDE:-$ici/../scripts/garde-perte-seche.sh}"
CAS="${CAS:-$ici/essai-garde-perte-seche.txt}"
# Ni sous /tmp, ni sous un nom que le garde tient pour jetable, le dépôt mis à part.
RACINE="${DOSSIER_ESSAI:-$HOME/.essai-garde-perte-seche}"
DEPOT="$RACINE/build/depot"
LIEN="${LIEN_ESSAI:-/tmp/lien-essai-garde-perte-seche}"
# Les worktrees vivent HORS du dépôt. Rangés dedans, ils deviendraient du non suivi, que les cas
# de `git clean` et de `rm` jugeraient aussi. Un seul vit sous /tmp, exprès.
ARBRES="$RACINE/arbres"
ARBRE_TEMP="${ARBRE_TEMP_ESSAI:-/tmp/arbre-essai-garde-perte-seche}"
ARBRE_TEMP_ORPHELIN="$ARBRE_TEMP-orphelin"
PRINCIPALE=principale
# Posé à la racine du dossier d'essai, et exigé avant tout effacement. Voir nettoyer().
MARQUE=".ceci-est-un-depot-d-essai-jetable"
garder=0
[ "${1:-}" = "--garder" ] && garder=1

echouer() { printf 'essai : %s\n' "$1" >&2; exit 1; }

for outil in git python3; do
  command -v "$outil" >/dev/null 2>&1 || echouer "$outil est absent, rien n'a été joué"
done
[ -f "$GARDE" ] || echouer "garde introuvable, $GARDE"
[ -f "$CAS" ] || echouer "fichier de cas introuvable, $CAS"

# LE CHEMIN D'ESSAI SE REFUSE, IL NE SE DÉCRIT PAS. Sous une racine temporaire, le garde voit du
# jetable partout et le jeu devient muet. L'invariant était écrit en commentaire, et rien ne le
# tenait : un HOME sous /tmp rendait trente-cinq écarts qui se lisaient comme des défauts.
reel=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$RACINE")
# UN WORKTREE EST LE NÔTRE si son lien vise le dépôt d'essai, sous sa forme écrite ou liens
# résolus. Git peut noter l'une ou l'autre, par exemple derrière un HOME qui passe par un lien.
depot_reel=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$DEPOT")
est_notre_arbre() {
  grep -qF "gitdir: $DEPOT/.git/worktrees/" "$1/.git" 2>/dev/null \
    || grep -qF "gitdir: $depot_reel/.git/worktrees/" "$1/.git" 2>/dev/null
}
case "$reel/" in
  /tmp/*|/var/tmp/*|/dev/shm/*)
    echouer "le dépôt d'essai ne peut pas vivre sous une racine temporaire, $reel
      Le garde y voit du jetable, donc les cas passeraient sans rien prouver.
      Posez DOSSIER_ESSAI ailleurs." ;;
esac

# UN EFFACEMENT QUI EXIGE SA MARQUE. Ce fichier efface un chemin que l'appelant peut poser par
# DOSSIER_ESSAI. Sans ce verrou, une variable mal tapée faisait de cet outil d'essai exactement
# la perte sèche que le garde qu'il teste existe pour refuser.
nettoyer() {
  if [ -e "$RACINE" ] && [ ! -f "$RACINE/$MARQUE" ]; then
    echouer "$RACINE existe et ne porte pas la marque d'un dépôt d'essai.
      Rien n'a été effacé. Posez DOSSIER_ESSAI sur un chemin à nous, ou retirez celui-ci."
  fi
  rm -rf "$RACINE"
  [ -L "$LIEN" ] && rm -f "$LIEN"
  # UN WORKTREE SOUS /tmp NE S'EFFACE QUE S'IL EST LE NÔTRE. Son lien doit viser le dépôt
  # d'essai. Un fichier `.git` seul ne suffit pas : tout vrai worktree en porte un, et le chemin
  # peut venir de ARBRE_TEMP_ESSAI.
  for arbre in "$ARBRE_TEMP" "$ARBRE_TEMP_ORPHELIN"; do
    est_notre_arbre "$arbre" && rm -rf "$arbre"
  done
  return 0
}

demonter() {
  [ "$garder" = 1 ] && { printf 'essai : dépôt d'"'"'essai gardé, %s\n' "$DEPOT"; return 0; }
  nettoyer
}
trap demonter EXIT

# ── LE DÉPÔT D'ESSAI ─────────────────────────────────────────────────────────────────────────
# Chaque pièce sert à au moins un cas, et le commentaire dit lequel. Retirer une pièce rend
# muets les cas qui en dépendent, sans les faire rougir : ils passeraient pour « rien à perdre ».
# C'est pourquoi verifier_montage() les recompte une à une.
monter() (
  set -e
  nettoyer
  mkdir -p "$RACINE"
  printf 'Monté par modeles/essai-garde-perte-seche.sh. Effaçable sans regret.\n' > "$RACINE/$MARQUE"
  mkdir -p "$DEPOT"
  git -C "$DEPOT" init -q
  git -C "$DEPOT" symbolic-ref HEAD "refs/heads/$PRINCIPALE"
  git -C "$DEPOT" config user.email essai@exemple.invalide
  git -C "$DEPOT" config user.name Essai
  mkdir -p "$DEPOT/important" "$DEPOT/data" "$DEPOT/precieux" "$DEPOT/node_modules" "$DEPOT/vide"
  printf 'preuve\n' > "$DEPOT/important/preuve.txt"
  printf 'preuve2\n' > "$DEPOT/important/preuve2.txt"
  printf 'donnee\n' > "$DEPOT/data/donnee.txt"
  printf 'garde\n' > "$DEPOT/garde.txt"
  # UN NOM AVEC UNE ESPACE. Le garde a compté ses fichiers suivis EN JETONS le 2026-09-10, donc
  # un tel nom en valait deux, dans les deux sens. Sans ce fichier, ce correctif ne se mesure pas.
  printf 'suivi\n' > "$DEPOT/data/note de suivi.txt"
  git -C "$DEPOT" add -A
  git -C "$DEPOT" commit -q -m "base"
  # DEUX COMMITS, PAS UN. Les cas de `reset --hard` et de `checkout -B` visent « HEAD~1 », qui
  # n'existe pas sur un dépôt d'un seul commit. Le jeu rendait alors un écart qui ne disait rien
  # du garde, seulement du montage.
  printf 'node_modules/\n' > "$DEPOT/.gitignore"
  git -C "$DEPOT" add .gitignore
  git -C "$DEPOT" commit -q -m "ignore les artefacts"
  # Un fichier SUIVI ET MODIFIÉ. C'est lui la perte sèche de référence : git ne rend pas une
  # modification non commitée.
  printf 'modif\n' >> "$DEPOT/important/preuve.txt"
  # Du non suivi, que git ne rend pas non plus.
  printf 'neuf\n' > "$DEPOT/non-suivi.txt"
  printf 'a\n' > "$DEPOT/precieux/a.txt"
  printf 'b\n' > "$DEPOT/precieux/b.txt"
  # UN NOM QUI FINIT PAR UN CHIFFRE, seul dans son cas. Un chiffre collé à la fin d'un nom était
  # pris pour un descripteur de redirection. Le cas ne vaut que si SEUL ce fichier est visé.
  printf 'a\nb\n' > "$DEPOT/important2"
  # Un artefact que la machine régénère, qui doit PASSER.
  printf 'x\n' > "$DEPOT/node_modules/x.js"
  # Une branche qui porte un commit qu'aucun distant ne rend, pour les cas de `-B` et `-C`.
  git -C "$DEPOT" branch -q autre
  git -C "$DEPOT" checkout -q -b travail
  git -C "$DEPOT" commit -q --allow-empty -m "commit propre à travail"
  git -C "$DEPOT" checkout -q "$PRINCIPALE"
  # Un lien SOUS /tmp qui vise une preuve du dépôt. Le garde doit suivre le lien, pas lire son
  # préfixe : c'est le cas qui a mis cinq jours à être vu.
  ln -sfn "$DEPOT/important/preuve.txt" "$LIEN"
  # UN DISTANT, pour `git push --delete`, assoupli le 2026-10-20. « fusionnee » est contenue dans
  # la principale, « travail » porte un commit à elle. « inconnue » vit sur le distant seul, son
  # commit n'existe pas ici.
  git init -q --bare "$RACINE/distant.git"
  git -C "$DEPOT" remote add origin "$RACINE/distant.git"
  git -C "$DEPOT" branch -q fusionnee "$PRINCIPALE~1"
  # Poussé par son adresse, pas par « origin » : aucune référence de suivi ne naît. Sinon les
  # commits de « travail » passeraient pour rendus par un distant, et les cas de `-B` mentiraient.
  git -C "$DEPOT" push -q "$RACINE/distant.git" "$PRINCIPALE" travail fusionnee
  git --git-dir="$RACINE/distant.git" symbolic-ref HEAD "refs/heads/$PRINCIPALE"
  arbre_vide=$(git --git-dir="$RACINE/distant.git" mktree </dev/null)
  commit_distant=$(git --git-dir="$RACINE/distant.git" -c user.name=Essai -c user.email=essai@exemple.invalide \
    commit-tree "$arbre_vide" -p "$PRINCIPALE" -m "commit du distant seul")
  git --git-dir="$RACINE/distant.git" update-ref refs/heads/inconnue "$commit_distant"
  # UN DISTANT EN AVANCE, comme juste après une fusion faite sur lui. Sa principale porte un
  # commit qui n'existe pas ici. « croise » lit le premier distant, et pousse vers celui-ci.
  git clone -q --bare "$RACINE/distant.git" "$RACINE/distant-avance.git"
  commit_avance=$(git --git-dir="$RACINE/distant-avance.git" -c user.name=Essai -c user.email=essai@exemple.invalide \
    commit-tree "$arbre_vide" -p "$PRINCIPALE" -m "fusion faite sur le distant")
  git --git-dir="$RACINE/distant-avance.git" update-ref "refs/heads/$PRINCIPALE" "$commit_avance"
  git -C "$DEPOT" remote add avance "$RACINE/distant-avance.git"
  git -C "$DEPOT" remote add croise "$RACINE/distant.git"
  git -C "$DEPOT" remote set-url --push croise "$RACINE/distant-avance.git"
  # SIX WORKTREES, pour le retrait forcé d'un worktree. Un propre, avec un artefact jetable. Un
  # sale, un avec du non suivi, un dont le commit ne tient sur aucune branche. Et deux sous /tmp.
  # L'un est sale exprès, et passe quand même. L'autre porte un commit orphelin, qui se perdrait.
  mkdir -p "$ARBRES"
  for nom in propre sale non-suivi orphelin; do
    git -C "$DEPOT" worktree add -q --detach "$ARBRES/$nom" "$PRINCIPALE"
  done
  git -C "$DEPOT" worktree add -q --detach "$ARBRE_TEMP" "$PRINCIPALE"
  git -C "$DEPOT" worktree add -q --detach "$ARBRE_TEMP_ORPHELIN" "$PRINCIPALE"
  mkdir -p "$ARBRES/propre/node_modules"
  printf 'x\n' > "$ARBRES/propre/node_modules/x.js"
  printf 'modif\n' >> "$ARBRES/sale/garde.txt"
  printf 'neuf\n' > "$ARBRES/non-suivi/neuf.txt"
  git -C "$ARBRES/orphelin" commit -q --allow-empty -m "commit qu'aucune branche ne porte"
  printf 'modif\n' >> "$ARBRE_TEMP/garde.txt"
  git -C "$ARBRE_TEMP_ORPHELIN" commit -q --allow-empty -m "commit orphelin sous /tmp"
)

# LE MONTAGE SE VÉRIFIE PIÈCE PAR PIÈCE. Un `monter` qui échoue à mi-chemin laissait jouer les
# les cas sur un décor incomplet, et rendait des écarts qui accusaient le garde.
# Mesuré : un dossier d'essai impossible donnait cinquante faux écarts, sans un mot.
verifier_montage() {
  local manque=""
  [ -d "$DEPOT/.git" ] || manque="$manque\n      le dépôt git"
  [ "$(git -C "$DEPOT" branch --show-current 2>/dev/null)" = "$PRINCIPALE" ] \
    || manque="$manque\n      la branche $PRINCIPALE"
  git -C "$DEPOT" rev-parse --verify --quiet HEAD~1 >/dev/null || manque="$manque\n      le deuxième commit"
  git -C "$DEPOT" rev-parse --verify --quiet travail >/dev/null || manque="$manque\n      la branche travail"
  git -C "$DEPOT" status --porcelain 2>/dev/null | grep -q '^ M' || manque="$manque\n      un fichier suivi et modifié"
  git -C "$DEPOT" status --porcelain 2>/dev/null | grep -q '^??' || manque="$manque\n      un fichier non suivi"
  [ -f "$DEPOT/data/note de suivi.txt" ] || manque="$manque\n      un nom de fichier avec une espace"
  [ -f "$DEPOT/important2" ] || manque="$manque\n      un nom qui finit par un chiffre"
  [ -d "$DEPOT/vide" ] || manque="$manque\n      un dossier vide"
  [ -f "$DEPOT/node_modules/x.js" ] || manque="$manque\n      un artefact régénérable"
  [ -f "$LIEN" ] || manque="$manque\n      le lien sous /tmp, qui doit viser une preuve"
  case "$DEPOT" in */build/*) ;; *) manque="$manque\n      un dossier « build » au-dessus du dépôt" ;; esac
  for b in "$PRINCIPALE" travail fusionnee inconnue; do
    git --git-dir="$RACINE/distant.git" rev-parse --verify --quiet "refs/heads/$b" >/dev/null \
      || manque="$manque\n      la branche $b sur le distant"
  done
  git -C "$DEPOT" cat-file -e "$(git --git-dir="$RACINE/distant.git" rev-parse refs/heads/inconnue 2>/dev/null)" 2>/dev/null \
    && manque="$manque\n      un commit du distant inconnu du dépôt"
  [ -f "$ARBRES/propre/node_modules/x.js" ] || manque="$manque\n      le worktree propre et son artefact"
  git -C "$ARBRES/sale" status --porcelain 2>/dev/null | grep -q '^ M' || manque="$manque\n      le worktree sale"
  git -C "$ARBRES/non-suivi" status --porcelain 2>/dev/null | grep -q '^??' || manque="$manque\n      le worktree au non suivi"
  [ -n "$(git -C "$ARBRES/orphelin" rev-list HEAD --not --branches --remotes 2>/dev/null)" ] \
    || manque="$manque\n      le worktree au commit orphelin"
  # Un `.git` étranger au même chemin ferait jouer les cas sur l'arbre d'un autre dépôt.
  for arbre in "$ARBRE_TEMP" "$ARBRE_TEMP_ORPHELIN"; do
    est_notre_arbre "$arbre" \
      || manque="$manque\n      le worktree d'essai $arbre"
  done
  [ -n "$(git -C "$ARBRE_TEMP_ORPHELIN" rev-list HEAD --not --branches --remotes 2>/dev/null)" ] \
    || manque="$manque\n      le worktree orphelin sous /tmp"
  git -C "$DEPOT" cat-file -e "$(git --git-dir="$RACINE/distant-avance.git" rev-parse "refs/heads/$PRINCIPALE" 2>/dev/null)" 2>/dev/null \
    && manque="$manque\n      un distant en avance sur le dépôt"
  [ "$(git -C "$DEPOT" remote get-url --push croise 2>/dev/null)" = "$RACINE/distant-avance.git" ] \
    || manque="$manque\n      un distant à l'adresse de poussée distincte"
  [ -z "$manque" ] || echouer "le montage est incomplet, rien n'a été joué. Il manque :$(printf "$manque")"
}

# ── LE JEU ───────────────────────────────────────────────────────────────────────────────────
jouer() {
  RACINE="$DEPOT" LIEN="$LIEN" PRINCIPALE="$PRINCIPALE" GARDE="$GARDE" ARBRES="$ARBRES" ARBRE_TEMP="$ARBRE_TEMP" ARBRE_TEMP_ORPHELIN="$ARBRE_TEMP_ORPHELIN" python3 - "$CAS" <<'PY'
import json, os, re, subprocess, sys

racine, lien = os.environ["RACINE"], os.environ["LIEN"]
principale, garde = os.environ["PRINCIPALE"], os.environ["GARDE"]
arbres, arbre_temp = os.environ["ARBRES"], os.environ["ARBRE_TEMP"]
arbre_temp_orphelin = os.environ["ARBRE_TEMP_ORPHELIN"]

# Le garde est lancé SOUS UN CHRONOMÈTRE, parce que sa pire panne est d'être tué. Le harnais lit
# alors sa sortie vide comme « rien à signaler », et la commande part. Sans ce butoir, la classe
# de panne que l'en-tête du garde appelle la plus grave ne se mesurait pas.
BUTOIR = 30
GROS = "1234567890" * 20000

# LE GARDE JOUE EN FRANÇAIS quand la machine le parle. Il lisait une sortie de git en anglais,
# et `git clean -fdx` passait sur une machine réglée en français. Jouer dans la langue de qui
# lance l'essai ne mesurait ce défaut que chez lui. Mesuré le 2026-10-20.
# Une machine sans la commande `locale` tombe dans la note, pas dans une trace Python.
try:
    langues = subprocess.run(["locale", "-a"], capture_output=True, text=True).stdout.split()
except OSError:
    langues = []
francais = next((l for l in langues if l.lower().replace("-", "") == "fr_fr.utf8"), None)
ENV_GARDE = {**os.environ, "LC_ALL": francais} if francais else dict(os.environ)
if not francais:
    print("  NOTE   aucune locale française sur cette machine, la langue de git n'est pas mesurée")

attendus, cas, erreurs = None, [], []
motif_suivant = None
for n, brute in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    brute = brute.rstrip("\n")
    if not brute.strip():
        continue
    if brute.startswith("#"):
        m = re.match(r"#\s*CAS_ATTENDUS\s+(\d+)", brute)
        if m:
            attendus = int(m.group(1))
        m = re.match(r"#\s*motif\s*:\s*(.+)", brute)
        if m:
            motif_suivant = m.group(1).strip()
        continue
    # UNE LIGNE MAL FORMÉE EST UNE ERREUR, PAS UN SAUT. Elle était ignorée en silence, donc la
    # couverture pouvait rétrécir sans que le jeu cesse d'être vert.
    if "|" not in brute:
        erreurs.append(f"ligne {n} sans barre verticale : {brute[:70]}")
        continue
    attendu, _, commande = brute.partition("|")
    attendu = attendu.strip()
    if attendu not in ("DOIT_REFUSER", "DOIT_PASSER"):
        erreurs.append(f"ligne {n}, verdict inconnu « {attendu} »")
        continue
    cas.append((n, attendu, commande, motif_suivant))
    motif_suivant = None

# LE NOMBRE DE CAS EST ÉPINGLÉ. Sans ce compte, retirer un cas ne fait rien rougir, et la liste
# rétrécit en silence. C'est le principe des listes de dette du dépôt, appliqué à l'envers.
if attendus is not None and len(cas) != attendus:
    erreurs.append(f"{len(cas)} cas lus, {attendus} annoncés par la ligne CAS_ATTENDUS")

ecarts = 0
for n, attendu, commande, motif in cas:
    commande = (commande.replace("@RACINE@", racine).replace("@LIEN@", lien)
                        .replace("@PRINCIPALE@", principale).replace("@GROS@", GROS)
                        .replace("@ARBRES@", arbres).replace("@ARBRE_TEMP_ORPHELIN@", arbre_temp_orphelin)
                        .replace("@ARBRE_TEMP@", arbre_temp)
                        .replace("\\n", "\n"))
    charge = json.dumps({"tool_name": "Bash", "cwd": racine,
                         "tool_input": {"command": commande}})
    try:
        sortie = subprocess.run(["bash", garde], input=charge, capture_output=True,
                                text=True, timeout=BUTOIR, env=ENV_GARDE).stdout
    except subprocess.TimeoutExpired:
        # Un garde tué rend une sortie vide. On le nomme, plutôt que de le lire comme un
        # laissez-passer : c'est la panne la plus grave, et la plus silencieuse.
        sortie = ""
        erreurs.append(f"ligne {n}, le garde a dépassé {BUTOIR} s, donc il serait tué et "
                       f"la commande passerait")
    reel = "DOIT_REFUSER" if sortie.strip() else "DOIT_PASSER"
    court = commande.replace("\n", " ⏎ ")
    court = (court[:80] + "…") if len(court) > 80 else court
    if reel != attendu:
        ecarts += 1
        print(f"  ÉCART  ligne {n}, attendu {attendu:<12} obtenu {reel:<12} {court}")
        continue
    # LE MOTIF DU REFUS, quand la ligne « # motif: » le demande. Juger sur « la sortie est-elle
    # vide » laissait invisible toute une classe de régressions : un refus qui part pour la
    # mauvaise raison, ou dont l'inventaire ment sur ce qui partirait.
    if motif and attendu == "DOIT_REFUSER" and motif not in sortie:
        ecarts += 1
        print(f"  ÉCART  ligne {n}, le refus ne porte pas « {motif} » : {court}")

for e in erreurs:
    print(f"  ERREUR {e}")
print(f"\n{len(cas)} cas joués, {ecarts} écart(s), {len(erreurs)} erreur(s)")
sys.exit(1 if ecarts or erreurs else 0)
PY
}

printf 'essai : montage du dépôt à %s\n' "$DEPOT"
monter || echouer "le montage a échoué, rien n'a été joué"
verifier_montage
jouer
