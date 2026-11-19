#!/usr/bin/env bash
# garde-dessin-agent.sh — REFUSE un dessin de l'agent posé sur une image, sans mention visible.
#
# Dessiné par l'agent : ce fichier cite les tracés qu'il guette, et ne dessine rien lui-même.
#
# POURQUOI CE GARDE EXISTE
# -------------------------
# Vécu le 2026-11-15, chez un projet équipé. L'admin avait confié une maquette à Pixel Lab.
# L'agent a jugé seul un écran trop proche d'un jeu existant, et l'a redessiné en code. Il a
# éclairci des pads et dessiné des effets, présentés comme faisant partie du décor. L'admin :
# « à quel moment tu as cru que c'était une bonne idée que tu dessines, plutôt que pixellab ? ».
#
# Des règles écrites couvraient le cas et n'ont pas tenu, verdict B de l'auto-learn-skill. « Un
# trou est une décision de l'admin », dans CLAUDE.md. Ce garde mécanise la part mécanisable :
# le dessin qui remplace un rendu en silence.
#
# L'ORDRE DE PRIORITÉ, VALIDÉ PAR L'ADMIN
# ----------------------------------------
# D'abord l'outil de génération choisi, puis une image du produit réel, puis un dessin de
# l'agent. Le dernier rang reste permis, s'il est signalé. Le garde ne juge pas la raison.
#
# CE QU'IL FAIT
# --------------
# Hook `PreToolUse` sur la commande shell, l'écriture, l'édition, le carnet, la publication de
# page, l'envoi de fichier et le widget visuel. Il cherche un tracé, sur toile 2D, en forme SVG ou
# par ImageDraw de Pillow, à côté d'une image existante. Un tel texte doit porter la mention
# « Dessiné par l'agent : » suivie de sa raison, sur la même ligne. Dans une page, elle compte
# visible seulement, hors script, style et commentaire, balises ôtées. Sinon l'appel est refusé.
# Un schéma seul, sans image, passe : il ne remplace aucun rendu. Une édition se juge sur le
# fichier qu'elle laisse, quand elle apporte un tracé ou une image.
#
# CE QU'IL NE COUVRE PAS (limites connues, mesurées à l'écriture)
# ---------------------------------------------------------------
# - Un dessin fait en CSS seul, ombres ou dégradés. Le bloquer prendrait la mise en forme des pages.
# - `convert -draw` d'ImageMagick, `putpixel` de Pillow, un SVG créé par script.
# - Une image dessinée par un script mentionné, puis publiée dans une page sans la mention.
# - Une icône SVG, 48 unités de côté au plus et sans <image>, ne compte pas comme un tracé. Une
#   icône agrandie en CSS par-dessus une image passe donc.
# - Une seule mention vaut pour tous les tracés du même texte.
#
# INSTALLATION — aucune. Déclaré dans le `.claude/settings.json` versionné, qui suit le clone.
# La règle vit dans `docs/garde-fous.md`, section « Les gardes d'agent ».
#
# IL ÉCHOUE OUVERT. Bash et python3 de la bibliothèque standard, sortie à zéro sur tout chemin
# inattendu.
set -uo pipefail

charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0

# LE TRI RAPIDE. Le garde voit chaque commande shell de chaque session. Sans trace d'un tracé ni
# d'une image dans l'appel, python3 ne démarre pas. Une page publiée ou un fichier envoyé se lit
# sur disque, et passe toujours.
if ! printf '%s' "$charge" | grep -Eq '"tool_name"[[:space:]]*:[[:space:]]*"(Artifact|SendUserFile)"'; then
    printf '%s' "$charge" | grep -Eqi 'ImageDraw|<(svg|image|img|rect|circle|ellipse|path|polygon|polyline|line)|\.(fillRect|strokeRect|arc|lineTo|bezierCurveTo|quadraticCurveTo|createLinearGradient|createRadialGradient|putImageData|drawImage)|data:image|\.(png|gif|webp|jpe?g)|Image\.open|url\(' || exit 0
fi

# LA CHARGE PASSE PAR L'ENTRÉE, jamais en argument : un argument de plus de 128 Kio fait échouer
# le lancement de python3, et une page à grosse image intégrée passait sans contrôle.
IFS= read -r -d '' lecteur <<'PY' || true
import json, os, re, sys

TOILE = re.compile(
    r"\.(?:fillRect|strokeRect|arc|lineTo|bezierCurveTo|quadraticCurveTo|createLinearGradient"
    r"|createRadialGradient|putImageData)\s*\("
    r"|\bImageDraw\b")
SVG = re.compile(r"<svg\b([^>]*)>(.*?)(?:</svg>|\Z)", re.S | re.I)
FORME = re.compile(r"<(?:rect|circle|ellipse|path|polygon|polyline|line)\b", re.I)
VUE = re.compile(r"""viewBox\s*=\s*["']\s*[-\d.]+[\s,]+[-\d.]+[\s,]+([\d.]+)[\s,]+([\d.]+)""")
# `stroke-width` n'est pas une taille : un trait d'union devant le mot l'écarte.
TAILLE = re.compile(r"""(?<![\w-])(?:width|height)\s*=\s*["']?\s*(\d+(?:\.\d+)?)""")
# Une image existante, celle sur laquelle un tracé se pose. Le nom du fichier qu'un script écrit
# n'en est pas une : un schéma dessiné de zéro et enregistré en PNG passe.
IMAGE = re.compile(r"data:image/|\bImage\.open\b|<img\b|<image\b|\bdrawImage\s*\(|url\(", re.I)
# La mention se lit comme l'admin la voit : apostrophe typographique ou échappée, balises ôtées,
# et sans ce qu'une page ne montre pas, scripts, styles et commentaires. Une balise de bloc vaut
# un saut de ligne, pour que la raison reste sur la ligne de la mention.
APOSTROPHE = re.compile(r"’|&#0*39;|&#x0*27;|&rsquo;|&apos;|\\'", re.I)
CACHE = re.compile(r"<(script|style)\b.*?(?:</\1\s*>|\Z)|<!--.*?(?:-->|\Z)", re.S | re.I)
BLOC = re.compile(r"</?(?:p|div|br|li|h[1-6]|svg|figcaption|td|tr|section|canvas)\b[^>]*>", re.I)
BALISE = re.compile(r"<[^>]*>")
MENTION = re.compile(r"[Dd]essiné par l'agent\s*:\s*[^\n]{15,}")
ICONE = 48
LISIBLES = (".html", ".htm", ".svg", ".py", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".vue",
            ".svelte", ".css", ".sh", ".ipynb")

def icone(attrs):
    """Une icône SVG, 48 unités au plus de côté, n'est pas un dessin posé sur une image."""
    m = VUE.search(attrs)
    cotes = [float(x) for x in (m.groups() if m else TAILLE.findall(attrs))]
    return bool(cotes) and max(cotes) <= ICONE

def traces(texte):
    vus = {m.group(0).strip(".( ") for m in TOILE.finditer(texte)}
    for m in SVG.finditer(texte):
        if re.search(r"<image\b", m.group(2), re.I) or not icone(m.group(1)):
            vus |= {f.group(0) for f in FORME.finditer(m.group(2))}
    return vus

def mentionne(texte):
    """Une page HTML ne compte que la mention visible. Un script shell ou Python n'a rien de
    visible : sa mention compte où qu'elle soit."""
    texte = APOSTROPHE.sub("'", texte)
    if re.search(r"<(?:html|body|img|svg|p|div)\b", texte, re.I):
        texte = BALISE.sub("", BLOC.sub("\n", CACHE.sub("\n", texte)))
    return bool(MENTION.search(texte))

def fautes(texte):
    if not texte or not IMAGE.search(texte) or mentionne(texte):
        return []
    return sorted(traces(texte))

def lire(p):
    try:
        if not p.endswith(LISIBLES) or os.path.getsize(p) > 5_000_000:
            return ""
        return open(p, encoding="utf-8", errors="replace").read()
    except Exception:
        return ""

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

def apres(p, vieux, neuf, tous):
    """Le fichier tel qu'une édition le laisse. Seule une édition qui apporte un tracé ou une
    image est jugée, pour ne pas refuser une retouche sans rapport sur un fichier déjà fautif."""
    if not (TOILE.search(neuf) or FORME.search(neuf) or IMAGE.search(neuf)):
        return None
    avant = lire(p)
    if vieux and vieux in avant:
        return avant.replace(vieux, neuf, -1 if tous else 1)
    return neuf

def textes(d):
    ti, nom = d.get("tool_input") or {}, d.get("tool_name", "")
    cwd = d.get("cwd") or os.getcwd()
    if nom == "Bash":
        yield "la commande", ti.get("command", "")
    elif nom == "Write":
        yield ti.get("file_path", "?"), ti.get("content", "")
    elif nom == "Edit":
        p = ti.get("file_path", "?")
        t = apres(p, ti.get("old_string", ""), ti.get("new_string", ""), ti.get("replace_all"))
        if t is not None:
            yield p, t
    elif nom == "NotebookEdit":
        yield ti.get("notebook_path", "?"), ti.get("new_source", "")
    elif nom.endswith("show_widget"):
        yield "le widget", ti.get("widget_code", "")
    elif nom in ("Artifact", "SendUserFile"):
        for p in sources(ti, cwd):
            yield p, lire(p)

try:
    trouve = [(o, f) for o, t in textes(json.load(sys.stdin)) for f in [fautes(t)] if f]
except Exception:
    sys.exit(0)
if trouve:
    o, f = trouve[0]
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
        "permissionDecision": "deny", "permissionDecisionReason": (
            f"Dessin de l'agent sur une image, dans {o} ({', '.join(f)}), sans mention. Ordre de "
            "priorité : l'outil de génération choisi, puis une image du produit réel, puis un "
            "dessin de l'agent. Un dessin porte la mention visible « Dessiné par l'agent : » "
            "suivie de la raison pour laquelle les deux premiers n'ont pas convenu.")}},
        ensure_ascii=False))
PY
printf '%s' "$charge" | python3 -c "$lecteur" 2>/dev/null || exit 0
exit 0
