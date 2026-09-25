#!/usr/bin/env bash
# garde-avis-non-sollicite.sh — bloque la fin d'un tour dont la réponse porte une
# recommandation, alors que la demande du tour n'en appelait aucune.
#
# POURQUOI CE GARDE EXISTE
# -------------------------
# Vécu le 2026-09-16. La demande du tour disait « lis cet artefact ». La réponse l'a lu, puis
# l'a appliqué au dépôt en neuf étapes, et a conclu par « c'est le contenu candidat pour la
# branche ». Réponse de l'admin : « est-ce que je t'ai demandé ton avis ? ».
#
# Trois textes couvraient déjà le cas, et aucun n'a tenu. `docs/ton-des-echanges.md`, bloc sur
# la longueur, veut que ce qui déborde devienne une offre d'une ligne. `CLAUDE.md`, section
# « Explorer ou documenter n'autorise pas à coder », borne le mandat au demandé. Et le garde de
# publication nommait ce trou parmi ceux qu'il assume : du contenu non sollicité déversé dans la
# réponse, sans appel d'outil. Ce garde mécanise ce sous-cas, par le seul type de hook qui voit
# un message avant qu'il ne parte, `Stop`.
#
# CE QU'IL REFUSE, ET CE QU'IL LAISSE PASSER
# -------------------------------------------
# Deux listes fermées, une par côté. Les mots de la DEMANDE qui appellent un avis, et les
# marqueurs de RECOMMANDATION dans la réponse. Aucun mot du premier côté et un marqueur du
# second, il bloque. Un skill invoqué fixe sa propre forme, donc sa balise de commande exempte.
#
# La demande est le dernier message utilisateur réel du transcript. La réponse est TOUT le
# texte de l'assistant depuis la dernière entrée utilisateur, réelle ou non, résultats d'outil
# exclus. La revue a montré qu'un tour ordinaire enchaîne texte, outil, texte : ne juger que
# le dernier laissait passer une recommandation suivie d'un « Fait. ».
#
# LE REFUS SE DÉBLOQUE. Le retour d'un hook `Stop` entre au transcript comme une entrée
# utilisateur marquée méta. Elle borne la réponse jugée, sans déplacer la demande. Juger tout
# le tour depuis la demande rendait le premier refus définitif, le texte refusé restant dans
# le transcript. Trouvé par la revue de la redescente, sur un transcript réel.
#
# LES CITATIONS NE COMPTENT PAS. Ce qui est entre « et », entre accents graves ou dans un bloc
# de code se retire avant la recherche. Une réponse qui cite un gabarit du dépôt, saturé de
# « je propose » et de « premier geste », n'y recommande rien.
#
# LES MOTS SE CHERCHENT À LEUR FRONTIÈRE. Cherchés en sous-chaîne, « plan » exemptait
# « plantage » et « comment » exemptait « commentaire ». Trouvé par la revue, en exécutant.
#
# CE QU'IL NE COUVRE PAS (limites connues, mesurées à l'écriture)
# ---------------------------------------------------------------
# - Une recommandation qui évite les marqueurs. La limite de toute liste fermée.
# - Un avis livré dans un fichier écrit, jamais dans le message.
# - Une demande qui contient « avis » pour l'interdire. Le mot exempte, le sens non.
# - Un marqueur employé au sens factuel, « il faudrait 8 Go ». La liste ne garde « il faudrait »
#   que suivi d'un mot qui l'oriente, et « candidat » que suivi de « pour ».
# - Une citation sans guillemets ni accents graves compte comme du texte propre.
# - Une réponse refusée qui revient telle quelle est refusée à nouveau. La liste fermée borne.
#
# INSTALLATION — aucune. Déclaré dans le `.claude/settings.json` versionné, qui suit le clone.
# La règle vit dans `docs/garde-fous.md`, section « Les gardes d'agent ».
#
# IL ÉCHOUE OUVERT. Un hook `Stop` qui plante bloquerait la fin de chaque tour. Bash et grep,
# python3 pour lire le transcript et écrire le JSON, sortie à zéro sur tout chemin inattendu.
# Une ligne illisible du transcript se saute, elle ne rend pas le garde muet pour la session.
set -uo pipefail

charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0

paire=$(CHARGE_JSON="$charge" python3 -c '
import json, os, sys
try:
    chemin = json.loads(os.environ["CHARGE_JSON"]).get("transcript_path") or ""
    lignes = open(chemin, encoding="utf-8").read().splitlines()
except Exception:
    sys.exit(0)
entrees = []
for l in lignes:
    if not l.strip():
        continue
    try:
        entrees.append(json.loads(l))
    except json.JSONDecodeError:
        continue
def texte(e):
    c = (e.get("message") or {}).get("content")
    if isinstance(c, str): return c
    if isinstance(c, list):
        return "".join(b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text")
    return ""
# Deux frontieres. La demande est le dernier message utilisateur REEL. La reponse part de la
# derniere entree utilisateur quelle qu elle soit, retour de hook compris, resultats d outil exclus.
demande_i = reponse_i = -1
for i in range(len(entrees) - 1, -1, -1):
    e = entrees[i]
    if e.get("type") != "user" or e.get("toolUseResult") or e.get("isSidechain"):
        continue
    if reponse_i < 0:
        reponse_i = i
    if not e.get("isMeta"):
        demande_i = i
        break
if demande_i < 0: sys.exit(0)
demande = texte(entrees[demande_i])
reponse = " ".join(texte(e) for e in entrees[reponse_i + 1:]
                   if e.get("type") == "assistant" and not e.get("isSidechain"))
# Les citations sortent : blocs de code, accents graves, guillemets francais.
import re
reponse = re.sub(r"```.*?```", " ", reponse, flags=re.S)
reponse = re.sub(r"`[^`]*`", " ", reponse)
reponse = re.sub(r"«[^»]*»", " ", reponse, flags=re.S)
# Un seul flux, un separateur que la prose ne porte jamais : la demande, puis la reponse.
sys.stdout.write(demande.replace("\n", " ") + "\x1f" + reponse.replace("\n", " "))
' 2>/dev/null) || exit 0
[ -n "$paire" ] || exit 0
demande=${paire%%$'\x1f'*}
reponse=${paire#*$'\x1f'}
[ -n "${reponse// /}" ] || exit 0

# Accents en alternance pleine, jamais en classe : une classe POSIX ne voit que des octets.
export LC_ALL=C.UTF-8
APPEL_AVIS='\bavis\b|\bpenses?\b|\bpropos(e|es|er|ition|itions)\b|\brecommand|\bconseil|\bsugg(è|e)r|\bferais\b|\blequel\b|\blaquelle\b|\bcomment\b|\bpourquoi\b|\bque faire\b|\bquoi faire\b|\bplans?\b|\borganis|\bexpliqu|\bdétaill|\banalys|\bcompar|\bévalu|\bjuge|<command-name>'
MARQUEUR_AVIS='je propose|je recommande|je suggère|je conseille|à mon avis|il faudrait (aussi|donc|que tu|que vous|plutôt)|\bcandidats? pour\b|ce qu.il faut faire|le premier geste'

printf '%s' "$demande" | grep -qiE "$APPEL_AVIS" && exit 0
# Sans « head » dans le tube : sous pipefail, une sortie longue de grep mourait en SIGPIPE et
# la substitution échouait, donc la réponse la plus chargée en avis passait. Trouvé par la revue.
fenetres=$(printf '%s' "$reponse" | grep -ioE ".{0,80}($MARQUEUR_AVIS).{0,80}") || exit 0
suspect=${fenetres%%$'\n'*}
[ -n "$suspect" ] || exit 0

PHRASE="$suspect" python3 -c '
import json, os
raison = (
    "Avis non sollicité : la demande de ce tour ne demande ni avis, ni proposition, ni plan, et "
    "la réponse en porte un. Passage suspect : " + os.environ["PHRASE"] + ". "
    "CLAUDE.md § Explorer ou documenter n autorise pas à coder : le mandat se limite à ce qui est "
    "demandé. Retirer la recommandation, ou la réduire à une offre d une ligne "
    "(docs/ton-des-echanges.md, bloc sur la longueur)."
)
print(json.dumps({"decision": "block", "reason": raison}))
'
exit 0
