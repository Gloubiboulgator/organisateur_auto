#!/usr/bin/env bash
# garde-lecture-a-froid.sh — REFUSE la publication d'un questionnaire tant qu'aucune lecture à
# froid ne l'a lue, depuis le dernier message de l'admin et depuis sa dernière retouche.
#
# POURQUOI. Le 2026-10-26, une session d'un projet équipé a publié vingt-trois questionnaires
# sans la lecture à froid que demande docs/ton-des-echanges.md. Ses pages d'images générées sont
# parties jugées par leur seul auteur, qui savait ce qu'elles devaient montrer et l'y voyait.
# L'admin les a presque toutes refusées, après cent générations payées pour une seule page.
#
# LE QUESTIONNAIRE se reconnaît par questionnaire_publie.py, comme pour les deux autres gardes de
# questionnaire. C'est une page publiée ou envoyée en fichier, qui déclare VALIDER et QUESTIONS.
# Le garde ne lit pas le tableau, et des questions bâties par un appel de fonction comptent aussi.
# LA LECTURE À FROID se reconnaît à un appel d'agent, Agent ou Task selon la version, dont la
# description dit « à froid » et nomme la page par son nom de fichier complet. Une page jointe
# par `files` peut aussi l'être par son nom publié. La consigne entière ne compte pas : une
# consigne qui cite garde-lecture-a-froid ne vaut pas lecture. L'appel doit avoir rendu son
# résultat, et une lecture refusée ou interrompue ne compte pas. Lancée en arrière-plan, elle
# rend un résultat dès son départ : elle ne compte qu'une fois un retour de tâche arrivé après.
# UNE RETOUCHE DANS LE GESTE DE PUBLIER se refuse : les `edits` d'Artifact s'appliquent après
# ce garde, et la page partirait sans relecture.
# QUAND. Depuis le dernier message de l'admin, et après la dernière retouche de la page. Une
# carte réécrite repasse ainsi la lecture. Décidé par l'admin le 2026-10-27, par questionnaire.
# NE VOIT PAS ce que le relecteur a vraiment lu, ni s'il a regardé les images. Il ne juge pas
# la lecture, il lit ce que l'agent a annoncé. Un retour de tâche ne dit pas de quelle tâche il
# vient : n'importe lequel, arrivé après la lecture en arrière-plan, la fait compter.
# Points réglés par le questionnaire du 2026-10-27, validés par l'admin.
# UNE RETOUCHE FAITE DANS LE MÊME MESSAGE que l appel d agent, et placée avant lui, ne l invalide
# pas. Sa règle vit dans questionnaire_publie.py, à retouchee_dans_le_message. Corrigé le 2026-11-07.
# ÉCHOUE OUVERT : toute charge inattendue sort en zéro, sans rien dire. Une entrée illisible du
# journal se saute, sans arrêter la lecture. Un appel sans heure ne se compare pas à la retouche.
set -uo pipefail
charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0
verdict=$(printf '%s' "$charge" | python3 -c '
import json, os, re, sys
sys.path.insert(0, sys.argv[1])
try:
    from questionnaire_publie import pages_envoyees, est_questionnaire, retouches_reussies, retouchee_dans_le_message, heure
    d = json.load(sys.stdin)
    ti = d.get("tool_input") or {}
    cwd = d.get("cwd") if isinstance(d.get("cwd"), str) else os.getcwd()
    racine = os.path.join(cwd, ti["root"]) if isinstance(ti.get("root"), str) else cwd
    # Le nom publié d une page jointe, par le chemin de sa source.
    publies = {}
    if isinstance(ti.get("files"), dict):
        for publie, source in ti["files"].items():
            source = source.get("from") if isinstance(source, dict) else source
            if isinstance(source, str):
                publies[os.path.join(racine, source)] = os.path.basename(publie).lower()
    pages = {}
    for p in pages_envoyees(d):
        if os.path.isfile(p):
            with open(p, encoding="utf-8") as f:
                if not est_questionnaire(f.read()):
                    continue
            noms = {os.path.basename(p).lower()} | ({publies[p]} if p in publies else set())
            pages[p] = (os.path.getmtime(p), noms)
    if not pages:
        sys.exit(1)
    # Les retouches ne portent que sur la page principale : une page jointe intacte ne les subit pas.
    principale = os.path.join(cwd, ti["file_path"]) if isinstance(ti.get("file_path"), str) else None
    if d.get("tool_name") == "Artifact" and ti.get("edits") and principale in pages:
        print("RETOUCHE")
        sys.exit(0)
    lignes = open(d["transcript_path"], encoding="utf-8").read().splitlines()
except Exception:
    sys.exit(1)
# Un skill chargé, un retour d agent, une notification, une interruption ou la sortie d une
# commande arrivent comme des messages, sans venir de l admin. Le résumé d un compactage aussi.
MACHINE = ("<system", "<task-notification", "[SYSTEM NOTIFICATION", "[Request interrupted",
           "<bash-", "<local-command")
# « à froid », même avec une espace insécable ou un trait d union. Le « a » d un nom de fichier,
# collé à un trait d union, ne compte pas.
A_FROID = re.compile(r"(?<![\w-])(?:à|a)[\s\u00a0-]+froid\b")
def humain(e):
    if e.get("type") != "user" or e.get("isMeta") or e.get("isCompactSummary"):
        return False
    o = e.get("origin")
    if isinstance(o, dict) and o.get("kind") != "human":
        return False
    c = e.get("message", {}).get("content")
    if isinstance(c, list):
        if any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c):
            return False
        image = any(isinstance(x, dict) and x.get("type") == "image" for x in c)
        c = " ".join(x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text")
        # Une image seule ne vient de l admin que si l entrée le dit.
        if not c.strip():
            return image and isinstance(o, dict) and o.get("kind") == "human"
    return isinstance(c, str) and bool(c.strip()) and not c.lstrip().startswith(MACHINE)
# Les retouches ne se lisent que si un appel en a besoin : une publication ordinaire n en paie rien.
faites = None
def couverte(place, mid, page, fin, ecrite):
    global faites
    if faites is None:
        faites = retouches_reussies(lignes, cwd)
    return retouchee_dans_le_message(faites, place, mid, page, fin, ecrite)
rendus, lues, retour = {}, set(), False
for n in range(len(lignes) - 1, -1, -1):
    l = lignes[n]
    try:
        e = json.loads(l)
        # Les messages d un agent lancé, inscrits au journal, ne sont pas ceux de l admin.
        if not isinstance(e, dict) or e.get("isSidechain"):
            continue
        if humain(e):
            break
        o = e.get("origin")
        contenu = e.get("message", {}).get("content")
        texte = contenu if isinstance(contenu, str) else " ".join(
            x.get("text", "") for x in contenu or [] if isinstance(x, dict))
        if (isinstance(o, dict) and o.get("kind") == "task-notification") or texte.lstrip().startswith("<task-notification"):
            retour = True
        if not isinstance(contenu, list):
            continue
        for k, x in enumerate(contenu):
            if not isinstance(x, dict):
                continue
            if x.get("type") == "tool_result" and x.get("is_error") is not True:
                rendus[x.get("tool_use_id")] = heure(e)
            if x.get("type") == "tool_use" and x.get("name") in ("Agent", "Task") and x.get("id") in rendus:
                entree = x.get("input") or {}
                desc = str(entree.get("description", "")).lower()
                if not A_FROID.search(desc) or (entree.get("run_in_background") and not retour):
                    continue
                h = heure(e)
                for p, (retouche, noms) in pages.items():
                    nomme = any(re.search(r"(?<![\w.-])" + re.escape(nm) + r"(?![\w-])", desc) for nm in noms)
                    if nomme and (h is None or h >= retouche or couverte(
                            (n, k), e["message"].get("id"), p, rendus[x.get("id")], retouche)):
                        lues.add(p)
    except Exception:
        continue
if set(pages) <= lues:
    sys.exit(1)
print("ALERTE")
' "$(dirname "$0")" 2>/dev/null) || exit 0
if [ "$verdict" = "RETOUCHE" ]; then
    cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Questionnaire publie avec une retouche dans le meme geste. Les edits s appliquent apres ce garde, et la page partirait sans relecture. Retouche la page avant, fais-la relire a froid, puis publie sans edits."}}
JSON
elif [ "$verdict" = "ALERTE" ]; then
    cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Questionnaire publie sans lecture a froid valable. Il faut, depuis le dernier message de l admin et apres la derniere retouche de la page, un appel d agent termine dont la description dit a froid et nomme le fichier de la page, extension comprise (par exemple questionnaire.html). docs/ton-des-echanges.md : un agent sans acces au depot lit chaque carte et redit ce qui se decide. Ce garde demande aussi de lui faire regarder les images de la page, sans le verifier. Corrige, puis publie."}}
JSON
fi
exit 0
