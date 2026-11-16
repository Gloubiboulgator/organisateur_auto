#!/usr/bin/env bash
# garde-revue-de-conception.sh — REFUSE la publication d'un questionnaire à choix tant qu'aucune
# revue de conception ne l'a jugé, depuis le dernier message de l'admin et sa dernière retouche.
#
# POURQUOI. Le 2026-11-07, une session d'un projet équipé a publié six décisions sur un jeu. Ses
# recommandations, cochées d'avance, jugeaient la cohérence de l'écran, jamais le jeu. L'admin a
# répondu : « Si j'avais accepté les suggestions j'aurais fortement dégradé le jeu ». La lecture à
# froid était passée trois fois. Sans accès au dépôt, elle juge la compréhension, pas la qualité.
#
# LE QUESTIONNAIRE À CHOIX se reconnaît par questionnaire_publie.py. C'est une page qui déclare
# VALIDER et QUESTIONS, dont au moins une carte n'a pas `options` à VALIDER, comme le dit
# estChoix dans le modèle de page. Une page de textes à valider seulement n'a aucune
# recommandation à juger, et passe. Toute clé `options` des scripts de la page se lit, étalement,
# `push` et carte bâtie par une fonction compris. Le doute va à la revue.
# LA REVUE se reconnaît à un appel d'agent, Agent ou Task selon la version, dont la description
# dit « revue de conception » et nomme la page par son nom de fichier complet. Elle a le dépôt,
# contrairement à la lecture à froid. Un appel qui dit aussi « à froid » ne compte pas : un même
# agent ne peut pas avoir le dépôt et le lire sans. Le reste suit garde-lecture-a-froid.sh, dont
# ce garde dérive : appel terminé, retour de tâche pour un appel en arrière-plan, retouche refusée
# dans le geste de publier.
# QUAND. Depuis le dernier message de l'admin, et après la dernière retouche de la page.
# NE VOIT PAS ce que la revue a jugé. Une revue complaisante passe. Une recommandation posée dans
# l'échange, sans page, ne passe par aucun garde. L'ordre entre la revue et la lecture à froid ne
# se contrôle pas. Une retouche après la revue relance la lecture, et sans retouche les deux ont lu
# la même page.
# UNE RETOUCHE FAITE DANS LE MÊME MESSAGE que l appel d agent, et placée avant lui, ne l invalide
# pas. Sa règle vit dans questionnaire_publie.py, à retouchee_dans_le_message. Corrigé le 2026-11-07.
# ÉCHOUE OUVERT : toute charge inattendue sort en zéro, sans rien dire.
set -uo pipefail
charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0
verdict=$(printf '%s' "$charge" | python3 -c '
import json, os, re, sys
sys.path.insert(0, sys.argv[1])
try:
    from questionnaire_publie import pages_envoyees, est_questionnaire, retouches_reussies, retouchee_dans_le_message, heure, porte_un_choix
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
                texte = f.read()
                # Seule une carte à choisir porte une recommandation à juger.
                if not est_questionnaire(texte) or not porte_un_choix(texte):
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
# « revue de conception », même avec une espace insécable ou un trait d union.
REVUE = re.compile(r"\brevue[\s\u00a0-]+de[\s\u00a0-]+conception\b")
# « à froid », le motif de garde-lecture-a-froid.sh. Une lecture à froid n est pas une revue.
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
                if not REVUE.search(desc) or A_FROID.search(desc) \
                        or (entree.get("run_in_background") and not retour):
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
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Questionnaire publie avec une retouche dans le meme geste. Les edits s appliquent apres ce garde, et la page partirait sans relecture. Retouche la page avant, fais-la juger par la revue de conception, puis publie sans edits."}}
JSON
elif [ "$verdict" = "ALERTE" ]; then
    cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Questionnaire a choix publie sans revue de conception. Il faut, depuis le dernier message de l admin et apres la derniere retouche de la page, un appel d agent termine dont la description dit revue de conception, ne dit pas a froid, et nomme le fichier de la page, extension comprise. docs/ton-des-echanges.md : un agent qui a le depot juge chaque option a choisir sur ce qu elle ferait vivre a l utilisateur. Une option qui degrade le produit sort, et garder l existant reste une reponse quand il se defend. Corrige, puis publie."}}
JSON
fi
exit 0
