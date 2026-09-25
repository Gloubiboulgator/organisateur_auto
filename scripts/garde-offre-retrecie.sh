#!/usr/bin/env bash
# garde-offre-retrecie.sh — SIGNALE, à la lecture de la demande, qu'un mot d'accord suivi d'un
# geste nommé donne mandat pour CE geste, pas pour l'offre qui précède.
#
# POURQUOI CE GARDE EXISTE
# -------------------------
# Vécu le 2026-09-19, chez un projet équipé. Le tour d'avant finissait sur une offre en quatre
# gestes, « je fais le rangement, note de décision, roadmap et liens ». L'admin a répondu
# « ok inverse les 2 fichiers ». La session a fait l'échange, puis annoncé les trois autres
# gestes. Réponse de l'admin : « je t'ai pas demandé de changer la roadmap ».
#
# Une règle écrite couvrait le cas et n'a pas tenu, verdict B de l'auto-learn-skill. « Un
# changement ne contient que la demande », dans CLAUDE.md. Le garde de l'avis non sollicité,
# lui, juge la réponse, jamais la lecture de la demande. Ce garde mécanise la part mécanisable :
# la forme du message qui trompe, un « ok » en tête qui absorbe le geste qui le suit.
#
# CE QU'IL FAIT, ET CE QU'IL NE FAIT PAS
# ---------------------------------------
# Hook `UserPromptSubmit`. Il ne refuse rien. Il ajoute une ligne de contexte au tour, qui cite
# le geste nommé et rappelle que le mandat s'arrête là. Un faux déclenchement coûte une ligne
# lue, un refus coûterait la demande. Le régime est donc le signal, comme le pre-push.
#
# LA FORME QU'IL RECONNAÎT
# -------------------------
# Un mot d'accord en tête, « ok », « oui », « go », « vas-y », « d'accord », « ça marche »,
# « parfait ». Puis au moins deux mots qui portent une lettre ou un chiffre. Un remerciement
# court après le mot d'accord ne compte pas, « ok merci » n'est pas un geste.
#
# CE QU'IL NE COUVRE PAS (limites connues, mesurées à l'écriture)
# ---------------------------------------------------------------
# - Un geste nommé sans mot d'accord devant, « fais juste l'échange ». Rien ne le distingue
#   d'une demande ordinaire, et une demande ordinaire est déjà le mandat.
# - Un mot d'accord absent de la liste. La limite de toute liste fermée.
# - Un « ok » qui accepte VRAIMENT l'offre entière et ajoute un geste de plus. La ligne de
#   contexte est alors à côté, et elle coûte une ligne.
#
# INSTALLATION — aucune. Déclaré dans le `.claude/settings.json` versionné, qui suit le clone.
# La règle vit dans `docs/garde-fous.md`, section « Les gardes d'agent ».
#
# IL ÉCHOUE OUVERT. Un hook qui plante à la lecture de chaque demande gênerait toute la
# session. Bash et python3 de la bibliothèque standard, sortie à zéro sur tout chemin inattendu.
set -uo pipefail

charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0

python3 - "$charge" <<'PY' 2>/dev/null || exit 0
import json, re, sys

try:
    demande = (json.loads(sys.argv[1]).get("prompt") or "").strip()
except Exception:
    sys.exit(0)
# Une balise ou une commande de skill n'est pas une réponse à une offre.
if demande.startswith("<") or demande.startswith("/"):
    sys.exit(0)

ACCORD = r"(ok|okay|oui|go|vas[- ]y|d['’]accord|ça marche|parfait)"
forme = re.match(r"^\s*" + ACCORD + r"[\s,.!:;]+(\S.*)$", demande, re.I | re.S)
if not forme:
    sys.exit(0)
geste = forme.group(2).strip()
mots = [m for m in re.split(r"\s+", geste) if re.search(r"\w", m)]
if len(mots) < 2:
    sys.exit(0)
if len(mots) < 4 and re.match(r"^(merci|super|génial|top|cool|nickel)\b", geste, re.I):
    sys.exit(0)

texte = (
    "Ce message repond a une offre en nommant un geste : « " + geste[:120] + " ». "
    "Le mandat du tour est CE geste, pas l offre qui precede. Ce que l offre contenait de "
    "plus se consigne, il ne se fait pas (CLAUDE.md, Un changement ne contient que la demande)."
)
print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
                                         "additionalContext": texte}}, ensure_ascii=False))
PY
exit 0
