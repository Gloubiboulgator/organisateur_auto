#!/usr/bin/env bash
# garde-provenance-affirmee.sh — bloque la fin d'un tour dont le dernier message attribue une
# décision aux « conventions/règles du dépôt/projet », sans en citer la source à proximité.
#
# POURQUOI CE GARDE EXISTE
# ---------------------------------------------------------
# Un message de clôture a dit « Comme demandé par les conventions du dépôt, je n'ai pas ouvert
# de PR ». La vraie source était une consigne système du harnais, pas une règle du dépôt — et la
# vraie convention du dépôt dit l'inverse (PR en brouillon obligatoire, `CLAUDE.md` § Plusieurs
# sessions à la fois). `CLAUDE.md` § Les quatre règles du DIALOGUE couvrait déjà ce cas (règle 1 :
# rien de certain sans provenance nommable) et n'a pas tenu. Un garde antérieur, hors de ce dépôt, nommait
# lui-même la limite qui l'empêchait de l'attraper : « un message de conversation qui affirme la
# même certitude sans jamais toucher de fichier, ce hook n'agit que sur un appel d'outil ». Ce
# hook mécanise exactement ce sous-cas, via le seul type de hook qui voit un message avant qu'il
# ne parte : `Stop`, pas `PreToolUse`.
#
# CORRIGÉ PAR /code-review, AVANT LA PREMIÈRE FUSION
# -------------------------------------------------------------------
# La version initiale lisait `last_assistant_message` depuis le JSON d'entrée : ce champ
# n'existe PAS dans la charge d'un hook `Stop` (vérifié sur un hook `Stop` réel de cette même
# machine, `~/.claude/stop-hook-reply-gate.py`, qui lit `transcript_path` puis rejoue le
# transcript JSONL). La détection tournait donc toujours sur une chaîne vide, un no-op muet.
# Le blocage, lui, était émis en `{"hookSpecificOutput": {"hookEventName": "Stop",
# "permissionDecision": "deny", ...}}` — la forme d'un hook `PreToolUse`. Le même hook réel
# émet `{"decision": "block", "reason": ...}` à la racine. Les deux défauts corrigés ci-dessous.
#
# ÉLARGI LE 2026-08-20 (auto-learn-skill) — CAS VOISIN, MÊME HOOK
# -----------------------------------------------------------------
# Un message de clôture a dit « La PR reste en brouillon comme convenu », juste après avoir
# traité une revue de code — le signal même de passer en « ready » (`CLAUDE.md` § Plusieurs
# sessions à la fois), déjà cité verbatim plus tôt dans la MÊME conversation. Ce hook existait
# déjà et n'a pas rougi : « comme convenu » n'était pas dans la liste fermée des marqueurs.
# Verdict C de l'auto-learn-skill, testé sur dix cas (fondateur avant/après, quatre légitimes,
# trois reformulations qui échappent encore — même limite assumée ci-dessous, résiduelle).
#
# CORRIGÉ PAR /code-review, AVANT LA FUSION
# -------------------------------------------------------------------
# Deux défauts trouvés en EXÉCUTANT le hook sur des cas construits, pas en le relisant. (1) La
# citation, partagée avec « convention/règle du dépôt », ne reconnaissait aucune provenance
# RAPPORTÉE (`CLAUDE.md` § Les quatre règles du DIALOGUE) : un « comme convenu » correctement
# sourcé, qui renvoie à ce que l'admin a dit plus haut dans la conversation, était refusé quand
# même. (2) La même citation partagée, une fois élargie pour (1), désarmait aussi le premier
# marqueur : « comme le veut la convention du dépôt, ainsi que je l'ai dit plus haut » passait
# sans jamais nommer de fichier. Les deux marqueurs ont donc chacun leur citation, ci-dessous.
#
# CE QU'IL REFUSE, ET CE QU'IL LAISSE PASSER
# -------------------------------------------
# Le dernier message principal de l'assistant (dernière entrée `type: assistant`, hors
# sidechain, du transcript) porte, à proximité d'un marqueur d'attribution, aucune citation
# adaptée à sa CLASSE dans une fenêtre de 100 caractères de part et d'autre.
#
# Classe « convention/règle » (liste fermée : « convention(s) »/« règle(s) » + « du dépôt »/
# « du projet ») : rien n'excuse l'absence d'un fichier à suffixe connu
# (`.md`/`.py`/`.kt`/`.sh`/`.yml`/`.yaml`/`.html`/`.json`/`.txt`), ni `§`,
# ni « CLAUDE.md », ni l'attribution correcte « instruction système »/« consigne système ».
#
# Classe « accord » (« comme convenu ») : les mêmes citations fichier PASSENT, plus un renvoi
# explicite à la conversation elle-même — « plus haut », « ci-dessus », « au-dessus », « dans
# cet échange »/« cette conversation », ou une attribution nommée (« l'admin a dit/montré… »,
# « tu as dit/demandé… »). Un fichier reste toujours accepté : l'accord peut aussi être une
# règle écrite, auquel cas il se cite comme telle.
#
# Un backtick NU (un nom de branche, une commande) ne désarme PAS le refus : le cas fondateur
# en portait un sans rapport, à 25 caractères du marqueur, et un premier essai fondé sur le
# seul backtick le laissait passer à tort.
#
# INSTALLATION — aucune. Déclaré dans le `.claude/settings.json` versionné, qui suit le
# clone. La règle vit dans `docs/garde-fous.md`, section « Les gardes d'agent ».
# `Stop` ne filtre pas par nom d'outil, donc `matcher` peut rester vide.
#
# CE QU'IL NE COUVRE PAS (limites connues)
# ------------------------------------------
# - L'orthographe exacte des cinq marqueurs. Une reformulation qui les évite passe, comme
#   n'importe quel garde fondé sur une liste fermée. Constaté à nouveau sur
#   « ainsi que convenu », « tel qu'on l'avait convenu », « comme il avait été convenu » —
#   trois voisins de « comme convenu » qui échappent encore, testés et laissés tels quels.
# - Une citation à proximité mais SANS RAPPORT avec l'affirmation qu'elle désarme à tort. Un
#   garde antérieur, hors de ce dépôt, portait la même imprécision sur sa propre fenêtre de
#   proximité, et l'assumait pour la même raison : une analyse de sens est hors de portée d'un
#   garde en grep.
# - Deux marqueurs DISTINCTS à moins de ~200 caractères l'un de l'autre, l'un cité et l'autre
#   pas : `grep -o` fusionne les deux dans UNE fenêtre, et la citation du premier couvre à tort
#   le second. Trouvé par /code-review, sixième passe. Même famille de trou que celui déjà
#   assumé par un garde antérieur, hors de ce dépôt (fenêtres de certitude, pas de marqueurs) ; un vrai
#   correctif exigerait le même fenêtrage par position d'octet exacte, jugé disproportionné ici
#   aussi pour la même rareté du cas (deux affirmations distinctes dans un seul message).
# - Aucun garde-fou natif contre la boucle infinie : si l'agent répète la même formulation sans
#   jamais citer de source, le hook la refuse à chaque tour. La liste fermée borne le risque,
#   sans l'annuler.
#
# IL ÉCHOUE OUVERT, ET C'EST VOULU
# ----------------------------------
# Un hook `Stop` qui plante bloquerait la fin de CHAQUE tour, pas seulement celui qu'il
# surveille — pire qu'un `PreToolUse` qui plante. Bash et grep seuls, `python3` uniquement pour
# lire le transcript et écrire le JSON de sortie (déjà une dépendance du dépôt, comme pour
# un garde antérieur, hors de ce dépôt), sortie à zéro sur tout chemin inattendu.
set -uo pipefail

charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0

# Le dernier message PRINCIPAL de l'assistant : dernière entrée `type: assistant` du transcript,
# hors sidechain (un subagent ne dit rien de ce que le tour principal s'apprête à envoyer). Pas
# `last_assistant_message`, absent de la charge — cf. section CORRIGÉ ci-dessus.
message=$(CHARGE_JSON="$charge" python3 -c '
import json, os, sys

try:
    charge = json.loads(os.environ["CHARGE_JSON"])
except Exception:
    sys.exit(0)

chemin = charge.get("transcript_path") or ""
# Relit tout le transcript a chaque tour, sans borne de taille : meme cout que le hook Stop
# reel cite en tete de fichier (read_transcript, boucle for line in f complete). Un
# rembobinage cible serait plus sobre ; non fait ici pour rester sur le meme patron que la
# reference plutot que d en inventer un nouveau, signale par /code-review, cinquieme passe.
entrees = []
try:
    with open(chemin, encoding="utf-8") as f:
        for ligne in f:
            ligne = ligne.strip()
            if not ligne:
                continue
            try:
                entrees.append(json.loads(ligne))
            except json.JSONDecodeError:
                continue
except OSError:
    sys.exit(0)

# Frontiere du TOUR COURANT : dernier message utilisateur reel (ni meta, ni resultat
# outil, ni sidechain). Un texte deja livre a un tour precedent ne doit jamais rouvrir
# le refus - meme logique que le hook Stop reel cite en tete de fichier. Trouve par
# code-review en troisieme passe : sans cette frontiere, un tour termine par un simple
# outil (sans texte) restait juge sur le texte perime du tour d avant.
frontiere = -1
for i in range(len(entrees) - 1, -1, -1):
    e = entrees[i]
    if (e.get("type") == "user" and not e.get("isMeta")
            and not e.get("toolUseResult") and not e.get("isSidechain")):
        frontiere = i
        break

texte = ""
for entree in entrees[frontiere + 1:]:
    if entree.get("type") != "assistant" or entree.get("isSidechain"):
        continue
    blocs = (entree.get("message") or {}).get("content")
    if not isinstance(blocs, list):
        continue
    morceaux = [b.get("text", "") for b in blocs
                if isinstance(b, dict) and b.get("type") == "text"]
    candidat = "".join(morceaux)
    # Un bloc texte VIDE, en queue apres un outil et avant le texte final, ne doit
    # jamais ecraser un texte reel capture plus tot dans le meme tour, trouve par
    # code-review en deuxieme passe.
    if candidat.strip():
        texte = candidat

sys.stdout.write(texte)
' 2>/dev/null) || exit 0
[ -n "$message" ] || exit 0

# Accents en alternance pleine, jamais en classe [ée] : une classe POSIX/C ne voit que des
# octets, et un accent en pèse deux — cf. un garde antérieur, hors de ce dépôt, qui a vécu la casse.
export LC_ALL=C.UTF-8

# DEUX classes, DEUX citations — pas une liste fusionnée (/code-review, deux défauts
# trouvés en exécutant le hook sur des cas construits, pas en le relisant). « convention/règle du
# dépôt » n'attribue qu'à un ÉCRIT : sa citation reste fichier SEUL. « comme convenu » peut
# légitimement s'appuyer sur ce que l'admin a dit dans la conversation (`CLAUDE.md` § Les quatre
# règles du DIALOGUE, provenance « rapportée ») : sa citation accepte AUSSI ce renvoi. Les
# fusionner faisait passer « comme le veut la convention du dépôt, ainsi que je l'ai dit plus
# haut » sans jamais nommer de fichier — l'échappatoire du second marqueur désarmait le premier.
MARQUEUR_CONV='(convention|conventions|règle|règles) du (dépôt|projet)'
MARQUEUR_ACCORD='comme convenu'
CITATION_FICHIER='\.(md|py|kt|sh|yml|yaml|html|json|txt)\b|§|CLAUDE\.md|instruction système|consigne système'
CITATION_ACCORD="$CITATION_FICHIER"'|plus haut|ci-dessus|au-dessus|dans cet échange|dans cette conversation|(tu|vous) ((m.|t.|l.|me |te |nous |lui |leur |en )+)?(as|avez) (dit|demandé|validé)|l.admin ((m.|t.|l.|me |te |nous |lui |leur |en )+)?a (dit|montré|demandé|validé)'

# `tr` aplatit les sauts de ligne AVANT la fenêtre : `.` ne franchit jamais une ligne en grep,
# et un message réel est presque toujours multi-paragraphe. C'est le correctif qu'un garde
# antérieur, hors de ce dépôt, avait déjà reçu sur sa propre fenêtre de proximité — trouvé ici
# par /code-review, quatrième passe : une citation au paragraphe suivant du marqueur se lisait
# comme absente.
aplati=$(printf '%s' "$message" | tr '\n' ' ')

chercher_suspect() {
  local marqueur="$1" citation="$2"
  local fenetres suspect=""
  fenetres=$(printf '%s' "$aplati" | grep -ioE ".{0,100}($marqueur).{0,100}") || return 0
  while IFS= read -r fenetre; do
    [ -n "$fenetre" ] || continue
    if ! printf '%s' "$fenetre" | grep -qiE "$citation"; then
      suspect="$fenetre"
      break
    fi
  done <<< "$fenetres"
  [ -n "$suspect" ] && printf '%s' "$suspect"
}

suspect_conv=$(chercher_suspect "$MARQUEUR_CONV" "$CITATION_FICHIER")
suspect_accord=""
[ -n "$suspect_conv" ] || suspect_accord=$(chercher_suspect "$MARQUEUR_ACCORD" "$CITATION_ACCORD")

if [ -n "$suspect_conv" ]; then
  PHRASE="$suspect_conv" CLASSE=conv python3 -c '
import json, os
phrase = os.environ.get("PHRASE", "")
raison = (
    "Provenance non nommée : ce passage attribue une décision aux conventions/règles du "
    "dépôt/projet sans citer de source à proximité (un fichier à suffixe connu, §, "
    "CLAUDE.md, ou instruction système). Passage suspect : " + phrase + ". "
    "Nommer la source exacte avant de conclure."
)
print(json.dumps({"decision": "block", "reason": raison}))
'
elif [ -n "$suspect_accord" ]; then
  PHRASE="$suspect_accord" python3 -c '
import json, os
phrase = os.environ.get("PHRASE", "")
raison = (
    "Provenance non nommée : ce passage attribue une décision à un accord (« comme convenu »)"
    " sans dire qui l'\''a donné ni où (un fichier à suffixe connu, §, CLAUDE.md, une "
    "instruction/consigne système, ou un renvoi explicite à ce que l'\''admin a dit dans cette "
    "conversation). Passage suspect : " + phrase + ". "
    "Nommer la source exacte avant de conclure."
)
print(json.dumps({"decision": "block", "reason": raison}))
'
fi

exit 0
