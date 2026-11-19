#!/usr/bin/env bash
# garde-generations-montrees.sh — BLOQUE la fin du tour tant qu'une image générée par Pixel Lab
# n'a pas été montrée à l'admin, gardée ou écartée.
#
# POURQUOI CE GARDE EXISTE
# -------------------------
# Vécu le 2026-11-15, chez un projet équipé. L'admin avait confié une maquette à Pixel Lab, « tu
# peux laisser libre cours à la créativité de pixellab ». Pixel Lab a rendu 121 images, la
# maquette publiée en montrait 12. L'agent avait écarté une animation et choisi un chat parmi 25
# et une voiture parmi 25, seul. Réponse de l'admin : « tu as généré des trucs que tu ne m'as
# même pas présenté. tu trouves ça normal ? ». Rejoué sur une autre session du même projet, ce
# garde y trouve 208 images jamais montrées.
#
# Des règles écrites couvraient le cas et n'ont pas tenu, verdict B de l'auto-learn-skill. « Un
# trou est une décision de l'admin », dans CLAUDE.md. Et « Trier avant de poser », dans
# docs/ton-des-echanges.md. Ce garde mécanise la part mécanisable : le compte.
#
# CE QU'IL FAIT
# --------------
# Hook `Stop`. Il relit le journal de la session. Chaque tâche de Pixel Lab y annonce son nombre
# d'images, `candidates: N`, ou `frames: N` plus l'image de départ. Chaque page publiée, widget
# affiché ou fichier envoyé à l'admin retranche les images qu'il porte : fichiers image joints ou
# téléversés, images appelées par la page, et images intégrées en `data:image/`. Une image se
# compte une fois, par son nom de fichier ou par la page qui l'intègre, même republiée. Une page
# se compte sur le texte que la session a écrit et sur le disque, au plus haut des deux. S'il en
# reste, et que le tour a lui-même généré des images, la fin du tour est bloquée une fois.
#
# CE QU'IL NE COUVRE PAS (limites connues, mesurées à l'écriture)
# ---------------------------------------------------------------
# - Un outil de Pixel Lab qui n'annonce ni `candidates` ni `frames`. Il n'est pas compté.
# - Une image sans rapport, une capture du jeu par exemple, compte comme une image montrée.
# - Deux images différentes du même nom de fichier, dans deux dossiers, comptent pour une.
# - Un second refus dans le même tour. `stop_hook_active` laisse passer, pour ne jamais boucler.
# - Un tour qui ne génère rien. Les images en retard attendent le prochain tour qui génère.
# - Une page écrite hors de la session puis effacée avant la fin du tour. Elle n'a plus rien à lire.
# - Une page modifiée après sa publication. Le garde lit le disque à la fin du tour, et compte
#   au plus haut entre ce texte et celui que la session a écrit. Des images ajoutées ensuite
#   comptent donc comme montrées, et des images retirées avant la publication aussi. Le choix
#   inverse bloquait à tort la page complétée par Bash avant d'être publiée. Relevé par la revue
#   de la 111, le 2026-11-19.
#
# INSTALLATION — aucune. Déclaré dans le `.claude/settings.json` versionné, qui suit le clone.
# La règle vit dans `docs/garde-fous.md`, section « Les gardes d'agent ».
#
# IL ÉCHOUE OUVERT. Bash et python3 de la bibliothèque standard, sortie à zéro sur tout chemin
# inattendu.
set -uo pipefail

charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0

# LA CHARGE PASSE PAR L'ENTRÉE, jamais en argument : un argument de plus de 128 Kio fait échouer
# le lancement de python3, et le garde se tairait.
IFS= read -r -d '' lecteur <<'PY' || true
import json, os, re, sys

IMAGE = re.compile(r"\.(png|gif|webp|jpe?g)$", re.I)
INTEGREE = re.compile(r"data:image/(?:png|gif|webp|jpe?g)", re.I)
# Le compte doit suivre son propre id : sans le refus d'un « id: » intermédiaire, une tâche sans
# compte prendrait celui de la suivante, que le dédoublonnage par id compterait ensuite deux fois.
TACHE = re.compile(r"^id: ([0-9a-f-]{36})$(?:(?!^id: ).)*?^(candidates|frames): (\d+)$",
                   re.M | re.S)
REF = re.compile(r"""(?:src|href)\s*=\s*["']?([^"'\s>]+\.(?:png|gif|webp|jpe?g))\b""", re.I)
PLAFOND = 20_000_000

def sources(ti, cwd):
    """Les fichiers locaux d'un appel, en chemins absolus. `file_path` et `file_paths` partent du
    dossier de travail, les sources de `files` de `root`. `files` est une liste de {path} ou une
    table dont les valeurs sont un chemin, {from}, ou {artifact, path} copié d'un autre artefact."""
    racine = os.path.join(cwd, ti["root"]) if isinstance(ti.get("root"), str) else cwd
    out = [(cwd, c) for c in [ti.get("file_path")] + list(ti.get("file_paths") or [])]
    f = ti.get("files") or []
    for v in (f.values() if isinstance(f, dict) else f):
        if isinstance(v, dict):
            v = None if "artifact" in v else v.get("from") or v.get("path")
        out.append((racine, v))
    return [os.path.abspath(os.path.join(r, c)) for r, c in out if isinstance(c, str)]

def montrer(appel, cwd, ecrits, fichiers, pages):
    """Note ce que l'appel montre. Une image se compte par son nom de fichier, une image intégrée
    par la page qui la porte : republier la même page ne compte pas ses images deux fois. Une page
    se lit telle que la session l'a écrite, et sur disque."""
    nom, ti = appel.get("name", ""), appel.get("input") or {}
    if nom.endswith("show_widget"):
        code, cle = ti.get("widget_code") or "", "widget:" + str(ti.get("title"))
        pages[cle] = max(pages.get(cle, 0), len(INTEGREE.findall(code)))
        fichiers.update(os.path.basename(r) for r in REF.findall(code))
        return
    if nom not in ("Artifact", "SendUserFile"):
        return
    for p in sources(ti, cwd):
        if IMAGE.search(p):
            fichiers.add(os.path.basename(p))
        elif p.endswith((".html", ".htm")):
            # Les deux textes comptent, celui que la session a écrit et celui du disque. La
            # mémoire primait sur le disque, et ne voyait pas les images ajoutées ensuite par
            # Bash ou par une édition dont le passage ne correspondait plus. Le tour bloquait à
            # tort. Relevé par une revue le 2026-11-17, rejoué le 2026-11-18.
            textes = [ecrits.get(p) or ""]
            if os.path.isfile(p) and os.path.getsize(p) <= PLAFOND:
                textes.append(open(p, encoding="utf-8", errors="replace").read())
            pages[p] = max([pages.get(p, 0)] + [len(INTEGREE.findall(t)) for t in textes])
            for t in textes:
                fichiers.update(os.path.basename(r) for r in REF.findall(t))

def ecrire(appel, cwd, ecrits):
    """Garde le texte des pages que la session écrit, pour les compter telles que publiées."""
    nom, ti = appel.get("name", ""), appel.get("input") or {}
    p = ti.get("file_path")
    if not isinstance(p, str):
        return
    p = os.path.abspath(os.path.join(cwd, p))
    if nom == "Write":
        ecrits[p] = ti.get("content") or ""
    elif nom == "Edit" and p in ecrits and ti.get("old_string"):
        ecrits[p] = ecrits[p].replace(ti["old_string"], ti.get("new_string") or "",
                                      -1 if ti.get("replace_all") else 1)

# Un skill chargé, un rappel, un avis de tâche de fond, une interruption ou la sortie d'une
# commande arrivent comme des messages, en plein tour, sans venir de l'admin. Le résumé d'un
# compactage aussi. Les prendre pour une demande remettrait le tour à zéro, et le garde se tairait.
MACHINE = ("<system", "<task-notification", "[SYSTEM NOTIFICATION", "[Request interrupted",
           "<bash-", "<local-command")

def demande(e, contenu):
    """Vrai pour un message de l'admin, pas pour un retour d'outil ni pour un message machine."""
    if e.get("type") != "user" or e.get("isMeta") or e.get("isCompactSummary"):
        return False
    o = e.get("origin")
    if isinstance(o, dict):
        return o.get("kind") == "human"
    if isinstance(contenu, list):
        if any(isinstance(x, dict) and x.get("type") == "tool_result" for x in contenu):
            return False
        contenu = " ".join(x.get("text", "") for x in contenu
                           if isinstance(x, dict) and x.get("type") == "text")
    return isinstance(contenu, str) and not contenu.lstrip().startswith(MACHINE)

try:
    d = json.load(sys.stdin)
    if d.get("stop_hook_active"):
        sys.exit(0)
    cwd = d.get("cwd") or os.getcwd()
    lignes = open(d["transcript_path"], encoding="utf-8").read().splitlines()
except Exception:
    sys.exit(0)

attente, vues, appels, ecrits, fichiers, pages, montre, du_tour = 0, set(), {}, {}, set(), {}, 0, 0
for l in lignes:
    try:
        e = json.loads(l)
    except Exception:
        continue
    if not isinstance(e, dict) or e.get("isSidechain"):
        continue
    m = e.get("message")
    contenu = m.get("content") if isinstance(m, dict) else None
    if demande(e, contenu):
        du_tour = 0
    for x in contenu if isinstance(contenu, list) else []:
        if not isinstance(x, dict):
            continue
        if x.get("type") == "tool_use":
            appels[x.get("id")] = x
        if x.get("type") != "tool_result" or x.get("is_error"):
            continue
        r = x.get("content")
        r = r if isinstance(r, str) else " ".join(
            y.get("text", "") for y in r or [] if isinstance(y, dict))
        if "api.pixellab.ai" in r:
            for t in TACHE.finditer(r):
                if t.group(1) not in vues:
                    vues.add(t.group(1))
                    n = int(t.group(3)) + (t.group(2) == "frames")
                    attente, du_tour = attente + n, du_tour + n
        appel = appels.get(x.get("tool_use_id"), {})
        try:
            ecrire(appel, cwd, ecrits)
            montrer(appel, cwd, ecrits, fichiers, pages)
        except Exception:
            pass
        total = len(fichiers) + sum(pages.values())
        attente, montre = max(0, attente - (total - montre)), total

# Seul un tour qui a généré bloque. L'admin qui a dit de passer n'est pas relancé à chaque tour
# suivant, et les images des tours passés comptent encore au prochain tour qui génère.
if attente and du_tour:
    print(json.dumps({"decision": "block", "reason": (
        f"{attente} images Pixel Lab générées n'ont pas été montrées à l'admin. Montre-les "
        "toutes, gardées comme écartées, par une page publiée ou des fichiers envoyés, avec ton "
        "avis à côté. Le choix est à l'admin.")}, ensure_ascii=False))
PY
printf '%s' "$charge" | python3 -c "$lecteur" 2>/dev/null || exit 0
exit 0
