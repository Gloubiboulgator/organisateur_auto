#!/usr/bin/env bash
# garde-publication-non-sollicitee.sh — DEMANDE confirmation avant toute PUBLICATION
# d'artifact. Publier expose une page hors du dépôt, et le mandat du tour doit l'avoir demandé.
#
# POURQUOI CE GARDE EXISTE
# -------------------------------------------------------
# L'admin a demandé de REFORMULER une explication trop technique. La session a répondu en
# fabriquant une page HTML de sept cents lignes et en la PUBLIANT. Réponse de l'admin : « efface
# cette merde je t'ai jamais demandé ça ». `CLAUDE.md` § « Explorer ou documenter n'autorise pas
# à coder »  couvrait le cas. Le mandat se limite à ce qui est demandé, et le
# passage se nomme et se CONFIRME avant. La règle n'a pas tenu, pour la troisième fois, et le
# registre la donnait déjà pour « mécanisée par ailleurs : non ». Ce garde mécanise la part
# mécanisable, le « se CONFIRME ».
#
# PÉRIMÈTRE : UNE LISTE D'EXCLUS, JAMAIS UNE LISTE D'ACTIONS SURVEILLÉES
# -----------------------------------------------------------------------
# L'outil `Artifact`, et TOUTE action sauf celles qui n'exposent rien. Le sens de la liste
# n'est pas cosmétique, c'est la leçon des dettes du dépôt : une liste d'exclus qui ne fait
# que rétrécir, jamais une liste d'autorisés. Une action neuve de l'outil naît donc surveillée.
#
# La première version surveillait la seule action `publish`. La revue de code a
# montré ce que ça laissait passer. `upload_asset` pousse un fichier LOCAL arbitraire dans le
# magasin d'un artifact publié, lisible par tous ses spectateurs. `delete_asset` en détruit un
# définitivement. `reply` publie du texte visible. Aucun n'est une lecture, et tous franchissent
# la porte que ce garde prétend tenir.
#
# Le régime est `ask`, jamais `deny`. L'admin demande de vraies publications, et un refus sec
# les empêcherait. Ce garde ne juge pas l'intention, il la fait NOMMER.
#
# L'ABSENCE ET L'INCONNU DEMANDENT, ILS NE SE TAISENT PAS
# --------------------------------------------------------
# Le champ `action` est facultatif, et son absence vaut « publier ». C'est la forme exacte du
# cas fondateur, qui n'en portait aucun. La même règle vaut pour un `tool_input` absent, mal
# formé, ou portant une action inconnue : le garde demande. « Artifact appelé, forme non
# comprise » n'est pas un cas à ignorer, et demander coûte un clic.
#
# Cela ne contredit PAS l'échec ouvert. Une charge qu'on ne sait pas lire du tout, ou qui vise
# un autre outil, sort en silence. C'est seulement quand `tool_name` vaut `Artifact` que le
# doute penche vers la question.
#
# CE QU'IL NE COUVRE PAS (limites connues, mesurées à l'écriture)
# ---------------------------------------------------------------
# - Du contenu non sollicité écrit avec `Write` sans être publié (cas FAQ).
# - Du contenu non sollicité déversé directement dans la réponse, sans aucun appel d'outil.
#   Couvert en partie depuis le 2026-09-16 par `garde-avis-non-sollicite.sh`, sur une liste
#   fermée de marqueurs de recommandation.
# - Un fichier poussé par `SendUserFile`. Autre outil, hors matcher.
# Ces trois trous sont réels et assumés. Ce garde tient la porte de SORTIE du dépôt, pas
# l'ensemble de la dérive.
#
# INSTALLATION — aucune. Déclaré dans le `.claude/settings.json` versionné, qui suit le
# clone. La règle vit dans `docs/garde-fous.md`, section « Les gardes d'agent ».
#
# Le script reste dans `scripts/`, et ce n'est pas du rangement : le volet 4 du contrôle 15 de
# `scripts/doc-lint.sh` balaie `scripts/garde-*.sh` pour exiger sa ligne au registre et sa
# déclaration dans les hooks. Ailleurs, il deviendrait invisible à son propre contrôle.
#
# ÉCHEC OUVERT : tout chemin inattendu sort en 0. Un hook qui plante bloquerait l'outil qu'il
# surveille, donc toute la session. Même règle que pour tous les gardes d'agent.

charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0

verdict=$(printf '%s' "$charge" | python3 -c '
import json, sys

# Liste d EXCLUS, jamais de surveilles : cf. section dediee en tete de fichier. Ces actions
# lisent ou suivent, elles ne poussent rien vers un spectateur.
SANS_EXPOSITION = {
    "read", "list", "status", "comments", "watch", "unwatch", "resume_replies",
    "list_assets", "read_asset",
}
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(d, dict) or d.get("tool_name") != "Artifact":
    sys.exit(0)
ti = d.get("tool_input")
# tool_input absent ou mal forme : Artifact est appele, la forme n est pas comprise. On
# demande, cf. section « L ABSENCE ET L INCONNU DEMANDENT ».
if not isinstance(ti, dict):
    print("EXPOSE")
    sys.exit(0)
action = ti.get("action")
if action is None:
    action = "publish"          # le defaut de l outil publie
if not isinstance(action, str) or action.strip().lower() not in SANS_EXPOSITION:
    print("EXPOSE")
' 2>/dev/null) || exit 0

[ "$verdict" = "EXPOSE" ] || exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Cet appel Artifact expose ou detruit quelque chose hors du depot : publier une page, y televerser un fichier LOCAL, en supprimer un, ou poster un texte visible. Le mandat de ce tour l a-t-il demande ? CLAUDE.md § Explorer ou documenter n autorise pas a coder : le mandat se limite a ce qui est explicitement demande, et le passage se NOMME et se CONFIRME avant. Reformuler, expliquer ou documenter n autorisent pas a publier. Valide si l admin l a demande."}}
JSON
exit 0
