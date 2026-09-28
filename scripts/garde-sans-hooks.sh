#!/usr/bin/env bash
# garde-sans-hooks.sh — refuse à l'agent tout geste git qui saute les hooks.
#
# POURQUOI CE GARDE EXISTE (2026-09-25)
# -------------------------------------
# L'agent a corrigé le message d'un commit de fusion avec `git commit --amend --no-verify`, sans
# aucune nécessité. Trois textes disaient l'option « à éviter » : le glossaire, la page qui
# explique la doc, l'en-tête du hook pre-commit. Aucun n'était lu au moment du geste.
#
# CE QU'IL REFUSE
# ---------------
# - `--no-verify` sur un sous-geste qui déclenche des hooks (commit, push, merge, rebase…) ;
# - `commit -n`, sa forme courte, seule ou groupée (`-an`, `-nm`) ;
# - `core.hooksPath` désarmé : `-c`, `--config-env`, `git config` (et `set`, `unset`,
#   `--remove-section core`), ou les variables `GIT_CONFIG_*`. Remettre la clé sur un dossier
#   `githooks` qui existe passe, la lire aussi.
# - l'un de ces gestes porté par un alias passé en `-c alias.*`, en `!` compris, déplié jusqu'à
#   trois fois.
# Un préfixe (`if`, `time`, `env`, `sudo`…), un `bash -c`, un `eval` ou une substitution ne
# cachent pas la commande. Une option abrégée (`--no-ver`) compte comme l'option entière.
# Aucune exemption. Un bac à sable qui éprouve des hooks demande le geste à l'admin.
#
# POURQUOI PYTHON, ET PAS GREP
# ----------------------------
# La première version tenait en motifs grep. Deux revues de code du 2026-09-25 y ont trouvé neuf
# trous : une valeur entre guillemets, `git config set`, `git --no-pager`, un `-n` au milieu
# d'un message, une continuation de ligne… Un motif ne sait pas découper une ligne de commande.
# `shlex`, lui, la découpe comme le shell. Même choix que garde-perte-seche.sh.
#
# IL ÉCHOUE OUVERT, ET C'EST VOULU
# --------------------------------
# Un hook PreToolUse qui plante bloque l'outil qu'il surveille. Tout chemin inattendu sort en
# zéro. Seule exception : une commande que shlex ne sait pas découper, mais qui porte à la fois
# `git` et `--no-ver`, est refusée. C'est la forme exacte du cas fondateur.
set -uo pipefail
charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0
fichier=$(mktemp 2>/dev/null) || exit 0
trap 'rm -f "$fichier"' EXIT
printf '%s' "$charge" > "$fichier" 2>/dev/null || exit 0
CHARGE_FICHIER="$fichier" python3 - 2>/dev/null <<'PY' || exit 0
import json, os, re, shlex, subprocess

AVEC_HOOKS = {"commit", "push", "merge", "rebase", "am", "cherry-pick", "revert", "pull"}
# Options globales de git qui prennent leur valeur au mot suivant.
GLOBALES_A_VALEUR = {"-c", "-C", "--git-dir", "--work-tree", "--namespace", "--config-env",
                     "--exec-path", "--super-prefix", "--list-cmds"}
# Options de commit à valeur séparée : leur valeur n'est pas une option, même si elle commence
# par un tiret. Le cas vécu : `-m "fix: -n handling"`, refusé à tort par la version grep.
COMMIT_A_VALEUR = {"--message", "--file", "--author", "--date", "--template", "--reuse-message",
                   "--reedit-message", "--fixup", "--squash", "--trailer", "--cleanup",
                   "--pathspec-from-file"}
# Options courtes de commit qui prennent le reste du mot (-mMSG) ou, seules, le mot suivant.
COMMIT_COURTES_A_VALEUR = set("mFcCt")
# Options courtes dont la valeur est collée, et facultative : `-uno`, `-Scle`. Le reste du mot
# leur appartient, jamais le mot suivant. `-uno` était lu lettre à lettre, et refusé pour son n.
COMMIT_COURTES_COLLEES = set("uS")
CONFIG_A_VALEUR = {"-f", "--file", "--blob", "--type", "--default", "--comment"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh"}
# Ce qui peut précéder le vrai mot-commande sans en changer la nature.
PREFIXES = {"if", "then", "else", "elif", "do", "while", "until", "!", "{", "time", "env", "sudo",
            "nohup", "exec", "command", "nice", "ionice", "stdbuf", "timeout", "xargs", "builtin"}
PREFIXE_OPTIONS_A_VALEUR = {"-u", "-g", "-U", "-C", "-D", "-n", "-s", "-k"}
CLE = "core.hookspath"
ETAT = {"dossier": os.getcwd()}


def refuser():
    raison = ("Geste git qui saute les hooks refuse (--no-verify, commit -n, core.hooksPath). "
              "Les hooks portent doc-lint, code-lint et le verrou de fusion. Relance sans le "
              "contournement ; s il est vraiment necessaire, c est a l admin de le taper. "
              "Voir scripts/garde-sans-hooks.sh.")
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                             "permissionDecision": "deny",
                                             "permissionDecisionReason": raison}}))
    raise SystemExit(0)


def sans_heredocs(cmd):
    """Retire le corps des heredocs : du texte libre, où une apostrophe casserait shlex.

    Sauf quand c'est un shell qui le lit : `bash <<EOF` exécute son corps, qu'on garde donc.
    `<<<` est une chaîne, pas un heredoc, et n'ouvre rien.
    """
    # Un « << » compte seulement hors guillemets : écrit dans un message, ce n'est que du texte
    # (quatrième revue). Mais un `$(…)` rouvre un contexte neuf, même entre guillemets : le
    # `"$(cat <<'EOF' …)"` des messages de commit est un vrai heredoc (cinquième revue). D'où une
    # pile, un étage par `$(`, chacun avec ses guillemets. Elle court d'une ligne à l'autre.
    sortie, fin, apostrophe, pile = [], None, False, [False]
    for ligne in cmd.split("\n"):
        if fin is not None:
            if ligne.strip() == fin:
                fin = None
            continue
        sortie.append(ligne)
        ouvre, i = None, 0
        while i < len(ligne):
            c = ligne[i]
            guillemet = pile[-1]
            if apostrophe:
                apostrophe = c != "'"
            elif c == "\\":
                i += 2
                continue
            elif c == "#" and not guillemet and (i == 0 or ligne[i - 1] in " \t;&|("):
                break  # un commentaire : son apostrophe ne compte pas
            elif c == "'" and not guillemet:
                apostrophe = True
            elif c == '"':
                pile[-1] = not guillemet
            elif ligne.startswith("$((", i):
                # Arithmétique : son `<<` est un décalage de bits, pas un heredoc (sixième revue).
                fin_calcul = ligne.find("))", i + 3)
                i = fin_calcul + 2 if fin_calcul >= 0 else len(ligne)
                continue
            elif ligne.startswith("$(", i):
                pile.append(False)
                i += 2
                continue
            elif c == ")" and not guillemet and len(pile) > 1:
                pile.pop()
            elif not guillemet and ligne.startswith("<<", i) \
                    and not ligne.startswith("<<<", i) and (i == 0 or ligne[i - 1] != "<"):
                # Le délimiteur est tout mot sans blanc ni guillemet : `MSG-FIN` compris.
                m = re.match(r"<<-?\s*['\"]?([^\s'\"<>;&|()]+)['\"]?", ligne[i:])
                if m and ouvre is None:
                    ouvre = (i, m.group(1))
                i += 2
                continue
            i += 1
        if ouvre and not re.search(r"(^|[\s;&|(])(%s)(\s[^<]*)?$" % "|".join(SHELLS), ligne[:ouvre[0]]):
            fin = ouvre[1]
    return "\n".join(sortie)


def commandes(cmd):
    # `2>&1` n'est pas un « & » qui sépare deux commandes : on le retire avant de découper.
    cmd = re.sub(r"\d*[<>]&(\d+|-)", " ", cmd.replace("\\\n", " "))
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=";&|\n()")
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    courante = []
    for jeton in lex:
        if jeton and set(jeton) <= set(";&|\n()"):
            if courante:
                yield courante
            courante = []
        else:
            courante.append(jeton)
    if courante:
        yield courante


def saute(args):
    """`--no-verify`, ou l'un de ses préfixes que git accepte : `--no-ver`, `--no-verif`."""
    return any(len(a) >= 8 and "--no-verify".startswith(a) for a in args)


def juger_config(args, dossier):
    mots, i = [], 0
    while i < len(args):
        a = args[i]
        if a in CONFIG_A_VALEUR:
            i += 2
            continue
        if a in ("--remove-section", "--rename-section") and i + 1 < len(args) \
                and args[i + 1].lower() == "core":
            refuser()
        if not a.startswith("-"):
            mots.append(a)
        i += 1
    options = [a for a in args if a.startswith("-")]
    sous = mots[0] if mots and mots[0] in ("set", "unset", "get") else None
    if sous:
        mots = mots[1:]
    if not mots or mots[0].lower() != CLE:
        return
    if sous == "unset" or any(o.startswith("--unset") for o in options):
        refuser()
    if sous == "get" or any(o.startswith("--get") or o in ("-l", "--list") for o in options):
        return
    if len(mots) < 2:
        return
    # Remettre la clé ne passe que vers un vrai dossier de hooks du dépôt. `githooks` nu, à la
    # racine d'un dépôt qui n'en a pas, rendait les hooks muets (troisième revue).
    if os.path.basename(mots[1].rstrip("/")) != "githooks":
        refuser()
    # Git lit un chemin relatif depuis la racine de l'arbre de travail, pas depuis le dossier
    # courant (quatrième revue). Une variable non développée ou un dépôt pas encore créé ne se
    # vérifient pas : le nom suffit alors.
    valeur = os.path.expanduser(mots[1])
    if "$" in valeur or dossier is None:
        return
    if not os.path.isabs(valeur):
        r = subprocess.run(["git", "-C", dossier, "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=5)
        if r.returncode != 0:
            return
        valeur = os.path.join(r.stdout.strip(), valeur)
    if not os.path.isdir(valeur):
        refuser()


def juger_commit(args):
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--":
            return
        if a in COMMIT_A_VALEUR:
            i += 2
            continue
        if a.startswith("-") and not a.startswith("--"):
            for j, c in enumerate(a[1:]):
                if c == "n":
                    refuser()
                if c in COMMIT_COURTES_COLLEES:
                    break
                if c in COMMIT_COURTES_A_VALEUR:
                    if j == len(a) - 2:
                        i += 1
                    break
        i += 1


def substitutions(cmd):
    """Le contenu des `$(…)` et des accents graves, hors apostrophes, où le shell n'en lance aucune.

    Une substitution entre guillemets reste un seul mot pour shlex. Son contenu est pourtant une
    commande à part entière. Une citation entre apostrophes, elle, n'est que du texte.
    """
    trouvees, i, apostrophe, guillemet = [], 0, False, False
    while i < len(cmd):
        c = cmd[i]
        if c == "\\" and not apostrophe:
            i += 2
            continue
        if c == "'" and not guillemet:
            apostrophe = not apostrophe
        elif c == '"' and not apostrophe:
            guillemet = not guillemet
        elif not apostrophe and c == "`":
            fin = cmd.find("`", i + 1)
            if fin > i:
                trouvees.append(cmd[i + 1:fin])
                i = fin
        elif not apostrophe and cmd.startswith("$(", i):
            niveau, j = 1, i + 2
            while j < len(cmd) and niveau:
                niveau += {"(": 1, ")": -1}.get(cmd[j], 0)
                j += 1
            trouvees.append(cmd[i + 2:j - 1])
            i = j - 1
        i += 1
    return trouvees


def juger_texte(texte, profondeur=0):
    # Le corps d'un heredoc est du texte : ses accents graves ne lancent rien (rejeu du 2026-09-25).
    texte = sans_heredocs(texte)
    for sous in substitutions(texte) if profondeur < 3 else ():
        juger_texte(sous, profondeur + 1)
    for mots in commandes(texte):
        juger(mots, profondeur)


def juger(mots, profondeur=0):
    # Une redirection n'est pas un argument : `config core.hooksPath 2>/dev/null` reste une lecture.
    propres, k = [], 0
    while k < len(mots):
        if re.match(r"^\d*(>>?|<)", mots[k]):
            k += 2 if re.fullmatch(r"\d*(>>?|<)", mots[k]) else 1
            continue
        propres.append(mots[k])
        k += 1
    mots = propres
    # Les affectations et les préfixes (`if`, `time`, `env`, `sudo -u x`, `timeout 5`…) ne
    # changent pas la commande qui suit. On les passe, avec leurs options et leurs durées.
    while mots and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", mots[0]) or mots[0] in PREFIXES):
        prefixe = mots.pop(0) in PREFIXES
        while prefixe and mots and (mots[0].startswith("-") or re.fullmatch(r"[\d.]+[smhd]?", mots[0])):
            # `sudo -u moi`, `nice -n 10`, `timeout -s KILL` : l'option emporte le mot suivant.
            if mots.pop(0) in PREFIXE_OPTIONS_A_VALEUR and mots:
                mots.pop(0)
    if not mots:
        return
    nom = os.path.basename(mots[0])
    if nom == "cd" and len(mots) > 1:
        connu = ETAT["dossier"] is not None and "$" not in mots[1]
        ETAT["dossier"] = os.path.join(ETAT["dossier"], os.path.expanduser(mots[1])) if connu else None
        return
    if profondeur < 3 and nom == "eval":
        juger_texte(" ".join(mots[1:]), profondeur + 1)
        return
    if profondeur < 3 and nom in SHELLS:
        # `-c`, `-lc`, `-ec`, `-x -c` : le premier mot qui n'est pas une option est le script.
        if any(a.startswith("-") and not a.startswith("--") and "c" in a for a in mots[1:]):
            juger_texte(next((a for a in mots[1:] if not a.startswith("-")), ""), profondeur + 1)
        return
    if nom != "git":
        return
    i, dossier, alias = 1, ETAT["dossier"], {}
    while i < len(mots) and mots[i].startswith("-"):
        o = mots[i]
        suivant = mots[i + 1] if i + 1 < len(mots) else ""
        if o in ("-c", "--config-env") or o.startswith("--config-env="):
            reglage = o.split("=", 1)[1] if "=" in o else suivant
            if reglage.split("=")[0].lower() == CLE:
                refuser()
            # UN ALIAS PASSÉ PAR `-c` PORTE UN GESTE ENTIER. `git -c alias.ci='commit
            # --no-verify' ci` sautait les hooks sans qu'aucun mot du geste ne le montre. Trouvé
            # en revue de code, le 2026-09-27. garde-depot-deploye.sh le lisait déjà.
            m = re.match(r"^alias\.([^=]+)=(.*)$", reglage, re.S | re.I)
            if m and o == "-c":
                alias[m.group(1).lower()] = m.group(2)
        if o == "-C":
            connu = dossier is not None and "$" not in suivant
            dossier = os.path.join(dossier, os.path.expanduser(suivant)) if connu else None
        i += 2 if o in GLOBALES_A_VALEUR else 1
    if i >= len(mots):
        return
    geste, args = mots[i], mots[i + 1:]
    # Trois dépliages au plus, comme ailleurs : un alias peut en nommer un autre.
    for _ in range(3):
        corps = alias.get(geste.lower())
        if corps is None:
            break
        if corps.lstrip().startswith("!"):
            # Un alias en `!` lance une commande du shell, qui se juge comme telle.
            if profondeur < 3:
                juger_texte(corps.lstrip()[1:] + " " + " ".join(args), profondeur + 1)
            return
        try:
            deplie = shlex.split(corps)
        except ValueError:
            deplie = corps.split()
        if not deplie:
            return
        geste, args = deplie[0], deplie[1:] + args
    if geste in AVEC_HOOKS and saute(args):
        refuser()
    if geste == "commit":
        juger_commit(args)
    if geste == "config":
        juger_config(args, dossier)


charge = json.load(open(os.environ["CHARGE_FICHIER"]))
cmd = charge.get("tool_input", {}).get("command", "")
if isinstance(charge.get("cwd"), str):
    ETAT["dossier"] = charge["cwd"]
if not isinstance(cmd, str) or "git" not in cmd:
    raise SystemExit(0)
if re.search(r"GIT_CONFIG_(PARAMETERS|KEY_\d+)=\S*core\.hookspath", cmd, re.I):
    refuser()
try:
    juger_texte(cmd)
except ValueError:
    if re.search(r"\bgit\b", cmd) and "--no-ver" in cmd:
        refuser()
PY
exit 0
