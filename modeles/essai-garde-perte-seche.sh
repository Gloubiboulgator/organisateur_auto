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
  [ -z "$manque" ] || echouer "le montage est incomplet, rien n'a été joué. Il manque :$(printf "$manque")"
}

# ── LE JEU ───────────────────────────────────────────────────────────────────────────────────
jouer() {
  RACINE="$DEPOT" LIEN="$LIEN" PRINCIPALE="$PRINCIPALE" GARDE="$GARDE" python3 - "$CAS" <<'PY'
import json, os, re, subprocess, sys

racine, lien = os.environ["RACINE"], os.environ["LIEN"]
principale, garde = os.environ["PRINCIPALE"], os.environ["GARDE"]

# Le garde est lancé SOUS UN CHRONOMÈTRE, parce que sa pire panne est d'être tué. Le harnais lit
# alors sa sortie vide comme « rien à signaler », et la commande part. Sans ce butoir, la classe
# de panne que l'en-tête du garde appelle la plus grave ne se mesurait pas.
BUTOIR = 30
GROS = "1234567890" * 20000

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
                        .replace("\\n", "\n"))
    charge = json.dumps({"tool_name": "Bash", "cwd": racine,
                         "tool_input": {"command": commande}})
    try:
        sortie = subprocess.run(["bash", garde], input=charge, capture_output=True,
                                text=True, timeout=BUTOIR).stdout
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
