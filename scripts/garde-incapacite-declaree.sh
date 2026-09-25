#!/usr/bin/env bash
# garde-incapacite-declaree.sh — bloque la fin d'un tour dont le dernier message déclare une
# incapacité à compiler, tester ou déployer, sans trace d'une tentative par les voies du projet.
#
# POURQUOI CE GARDE EXISTE (2026-09-17, auto-learn-skill)
# ---------------------------------------------------------
# Un message de clôture a dit « Ce que je n'ai pas pu faire : compiler. Ce conteneur n'a pas le
# SDK Android, et l'accès au dépôt Maven de Google y est fermé. » Le constat local était exact.
# La conclusion ne l'était pas. L'intégration continue du projet était lançable à distance
# depuis cette même session, et le run déclenché au tour suivant a compilé sans une erreur.
#
# `CLAUDE.md` couvrait déjà ce cas, à sa section sur l'accès qu'on déclare manquant.
# Son motif est plus large que son titre. Un refus prouve qu'UNE voie est fermée,
# jamais que la chose est impossible. `docs/garde-fous.md` la rangeait parmi les règles écrites,
# en la marquant non mécanisée. Verdict B de l'auto-learn-skill, donc mécanisation.
#
# Ses deux voisins ne l'attrapaient pas, chacun nommant lui-même sa limite.
# `garde-provenance-affirmee.sh` ne juge qu'une décision attribuée aux conventions du
# dépôt. `garde-verifie-par-lecture.sh` ne regarde qu'un plan soumis à l'admin.
#
# CE QU'IL REFUSE, ET CE QU'IL LAISSE PASSER
# -------------------------------------------
# Une tournure d'incapacité, à moins de 120 caractères d'un objet que l'intégration sait
# produire. La fenêtre doit alors porter la trace d'une tentative à distance. Un numéro de run,
# une adresse de run, le nom d'un workflow, ou le fait d'avoir lancé quelque chose.
#
# Dire son incapacité reste donc permis, et c'est voulu. Ce qui devient impossible, c'est de la
# dire SANS avoir nommé ce qu'on a essayé. Les deux listes sont fermées et volontairement
# étroites, comme chez ses voisins. Une liste large refuse des phrases justes, ce qui apprend à
# contourner le garde plutôt qu'à corriger le geste.
#
# INSTALLATION
# ------------
# Il se déclare dans le `.claude/settings.json` VERSIONNÉ, en `Stop`, avec un chemin en
# `${CLAUDE_PROJECT_DIR}`. Le fichier suit donc le clone, et aucune pose manuelle n'est
# nécessaire. C'est la forme à préférer pour tout garde neuf.
#
# CE QU'IL NE COUVRE PAS (limites connues)
# ------------------------------------------
# - L'orthographe exacte des tournures. Une reformulation qui évite la liste passe, comme pour
#   tout garde fondé sur une liste fermée. Il vise l'excès de prudence ordinaire, pas une
#   évasion construite exprès.
# - Une incapacité vraie, sur un objet vraiment hors de portée. Le garde exige alors de nommer
#   ce qui a été essayé, ce qui reste le geste attendu.
# - Les objets hors intégration. Un accès à un service tiers, une donnée absente. Élargir le
#   périmètre est un choix à trancher à part.
# - Une incapacité mise entre guillemets pour passer. C'est le prix de la neutralisation des
#   citations, et il est accepté : citer sa propre excuse est une tournure que personne n'écrit
#   par accident. Le garde vise l'excès de prudence ordinaire, pas l'évasion délibérée.
#
# IL ÉCHOUE OUVERT, ET C'EST VOULU
# ----------------------------------
# Un hook qui plante bloquerait la fin de chaque tour. Toute sortie inattendue rend zéro.
set -uo pipefail

charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0

CHARGE_JSON="$charge" python3 - 2>/dev/null <<'PYGARDE'
import json
import os
import re
import sys

RAISON = (
    "Incapacité déclarée sans tentative nommée : ce passage conclut à une impossibilité de "
    "compiler, tester ou déployer, sans dire ce qui a été essayé par les voies du projet "
    "(un run, un workflow, une chaîne lancée à distance). Passage suspect : {}. "
    "Essayer ces voies, ou nommer ce qui a été tenté et pourquoi ça a échoué."
)

# Reconnaît les refus que CE garde a rendus, à sa signature, et en ressort la fenêtre exacte.
# Se fier au préfixe du harnais ferait compter le retour de n'importe quel autre hook `Stop`.
DEJA = re.compile(r"Incapacité déclarée sans tentative nommée.*Passage suspect : (.*)\. "
                  r"Essayer ces voies, ou nommer ce qui a été tenté et pourquoi ça a échoué\.",
                  re.S)

# L'APOSTROPHE EST UN JOKER, jamais un caractère. Le texte d'un message porte l'apostrophe
# typographique aussi souvent que l'ASCII, et une liste écrite avec l'une rate l'autre. Le cas
# fondateur lui-même passait, écrit avec la courbe. Le garde voisin de la provenance affirmée
# prend la même précaution, pour la même raison.
#
# « SUR UN GESTE DE L'ADMIN » A ÉTÉ RETIRÉ de cette liste (revue du 2026-09-17, avant la
# fusion). Il bloquait « le build partira sur un geste de l'admin, je ne bumpe jamais de
# moi-même », qui est exactement le geste que `CLAUDE.md` exige. Un marqueur qui refuse la
# règle du dépôt coûte plus qu'il ne rapporte.
MARQUEUR = (r"je n.ai pas pu|je ne peux pas|je n.ai pas les moyens"
            r"|il m.est impossible|rien (?:ici )?n.a compilé|non compilé")

OBJET = (r"compil|build|bundle|chaîne|chaine|émulateur|emulateur|déploie|deploie"
         r"|intégration continue|integration continue|\bCI\b|parcours visuel")

# Ce qui DÉSARME : la preuve qu'une voie distante a été essayée, ou nommée avec son identifiant.
TENTATIVE = (r"run \d|runs/\d|workflow_dispatch|actions_run_trigger|\.ya?ml\b"
             r"|j.ai lancé|j.ai déclenché|lancée? à distance|déclenchée? à distance"
             r"|le run \w|la chaîne tourne|en cours d.exécution")


# CE QUI EST ENTRE GUILLEMETS EST CITÉ, PAS ASSERTÉ. Même principe que l'étalon de prose du
# dépôt, où un signe entre accents graves est cité et non employé (`scripts/etalon_prose.py`).
# Sans cela, rapporter une phrase pour la RÉFUTER devient impossible, ce qui est l'inverse du
# but : le garde existe pour qu'une incapacité se corrige, donc se cite quand on la corrige.
CITATION = re.compile(r"«[^«»]*»|“[^“”]*”|\"[^\"\n]*\"")


def neutraliser_citations(texte):
    """Le même texte, les passages cités remplacés par des espaces.

    La LONGUEUR est conservée, caractère pour caractère. Les positions restent donc justes, et
    la fenêtre montrée dans le refus se découpe dans le texte d'origine, guillemets compris.
    """
    return CITATION.sub(lambda m: " " * len(m.group(0)), texte)


def suspect(aplati):
    """La première fenêtre qui déclare une incapacité sur un objet d'intégration, sans tentative.

    Une fenêtre PAR OCCURRENCE du marqueur. Un `grep -o` fusionnerait deux marqueurs proches
    dans une seule fenêtre, et la tentative nommée pour le premier couvrirait le second à tort.

    Le marqueur se cherche dans le texte SANS ses citations, la fenêtre se découpe dans le texte
    entier. Une incapacité cotoyant une citation garde donc son objet et sa tentative.
    """
    sans_citations = neutraliser_citations(aplati)
    for m in re.finditer(MARQUEUR, sans_citations, re.I):
        fenetre = aplati[max(0, m.start() - 120):m.end() + 120]
        if re.search(OBJET, fenetre, re.I) and not re.search(TENTATIVE, fenetre, re.I):
            return fenetre
    return ""


try:
    charge = json.loads(os.environ.get("CHARGE_JSON") or "")
except (json.JSONDecodeError, TypeError):
    sys.exit(0)

entrees = []
try:
    with open(charge.get("transcript_path") or "", encoding="utf-8") as f:
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

# Frontière du TOUR COURANT : dernier message utilisateur réel, ni meta, ni résultat d'outil,
# ni sidechain. Un texte déjà livré à un tour précédent ne doit jamais rouvrir le refus.
frontiere = -1
for i in range(len(entrees) - 1, -1, -1):
    e = entrees[i]
    if (e.get("type") == "user" and not e.get("isMeta")
            and not e.get("toolUseResult") and not e.get("isSidechain")):
        frontiere = i
        break

# UN SEUL PARCOURS, pour le texte à juger et pour ce qui a déjà été refusé dans ce tour.
texte = ""
deja = set()
for entree in entrees[frontiere + 1:]:
    if entree.get("isSidechain"):
        continue
    contenu = (entree.get("message") or {}).get("content")
    if entree.get("type") == "assistant":
        if not isinstance(contenu, list):
            continue
        candidat = "".join(b.get("text", "") for b in contenu
                           if isinstance(b, dict) and b.get("type") == "text")
        # Un bloc texte VIDE, en queue après un outil, ne doit pas écraser un texte réel.
        if candidat.strip():
            texte = candidat
    elif entree.get("type") == "user" and entree.get("isMeta"):
        trouve = DEJA.search(contenu) if isinstance(contenu, str) else None
        if trouve:
            deja.add(trouve.group(1))

if not texte.strip():
    sys.exit(0)

fenetre = suspect(texte.replace("\n", " "))

# UN PASSAGE NE SE REFUSE PAS DEUX FOIS. Le transcript n'est pas écrit quand ce hook lit, donc
# le garde peut relire le texte déjà refusé au lieu du message corrigé. Le refuser à nouveau ne
# dit rien de neuf. La comparaison est une ÉGALITÉ de fenêtres, une sous-chaîne laisserait
# passer toute réécriture qui raccourcit.
if not fenetre or fenetre in deja:
    sys.exit(0)

print(json.dumps({"decision": "block", "reason": RAISON.format(fenetre)}))
PYGARDE

exit 0
