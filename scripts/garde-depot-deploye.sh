#!/usr/bin/env bash
# garde-depot-deploye.sh — refuse à l'agent de faire quitter sa branche au répertoire déployé.
#
# POURQUOI CE GARDE EXISTE (2026-09-25)
# -------------------------------------
# Un agent de revue de code a tapé `git checkout -q a888841 -- 2>/dev/null` dans le répertoire
# que servent les units systemd. Il est resté détaché de `main` six secondes. Les units portent
# `Restart=on-failure` : un crash dans ce laps aurait mis en production un commit non fusionné.
# CLAUDE.md le disait (« le répertoire déployé ne quitte JAMAIS main »). Rien ne le tenait. Le
# rejeu de l'historique a trouvé dix-neuf autres départs, surtout des `checkout -b`.
#
# CE QU'IL REFUSE, dans un répertoire déployé
# -------------------------------------------
# Un geste git qui y déplace HEAD hors de la branche en place, qui déplace cette branche, ou qui
# y pose le contenu d'un autre commit :
# - checkout ou switch vers toute autre cible qu'elle, un fichier connu de git excepté. Une
#   branche seulement distante compte, git la crée à la volée. `-` et `origin/main` comptent ;
# - `-b`, `-c`, `--create`, `--detach`, `--orphan`, même groupées (`-qb`) ou collées (`-bfoo`),
#   et `-B main <point>` vers un autre point que HEAD ou l'amont ;
# - `checkout <commit> -- <fichiers>`, `restore --source`, `checkout -p <commit>` ;
# - reset vers un autre commit que HEAD ou l'amont, sous quelque nom qu'on les écrive (`@{u}`,
#   `origin/HEAD` au même commit). `FETCH_HEAD` et `ORIG_HEAD` bougent au fil de la ligne, donc
#   sont toujours refusés. Rebase aussi (sauf `--abort`, `--continue`, `--skip`),
#   `pull --rebase`, y compris par `-c pull.rebase=true` ;
# - `bisect start`, `bisect reset <commit>`, `symbolic-ref HEAD` ;
# - `update-ref` de la branche servie, même depuis un worktree voisin, car les branches sont
#   communes à tous les worktrees d'un dépôt ;
# - un alias passé par `-c alias.*` qui porte l'un de ces gestes.
# Revenir sur la branche, la remettre sur son amont, restaurer un fichier depuis HEAD, fusionner,
# tirer sans rebase ou committer passent. Une cible inconnue, comme `$B` ou `$(…)`, est refusée.
# Un préfixe (`if`, `time`, `sudo`…), un `cd`, `cd -`, `pushd`, `popd`, un `git -C`, un
# `env -C`, un `GIT_DIR=`, un `--git-dir`, un `bash -c` ou un `$(…)` ne cachent pas la
# commande. `$HOME` et `$PWD` se développent. Un `cd` dans `( … )`, `$( … )`, un pipe ou le
# heredoc d'un shell ne vaut que dedans, comme dans le shell. Une substitution se juge dans le
# dossier où elle tourne, à sa place dans la ligne.
#
# LE DÉCOUPAGE
# ------------
# `sans_heredocs` est copiée mot pour mot de garde-sans-hooks.sh, qui l'a durcie sur six revues.
# Dans le dépôt qui l'a vu naître, sa table de cas refuse tout écart entre les deux copies : un
# correctif fait là-bas doit se reporter ici. Le reste diffère, parce que ce garde suit le
# dossier courant. `decouper` lit le texte brut, guillemets compris, et rend à leur place les
# séparateurs, les commandes et leurs substitutions. `shlex` ne découpe ensuite qu'une commande.
#
# QU'EST-CE QU'UN RÉPERTOIRE DÉPLOYÉ
# ----------------------------------
# Un worktree git qui contient le `WorkingDirectory` d'une unit systemd qui redémarre d'elle-même
# (`Restart=` autre que `no`). C'est ce redémarrage qui met en production ce qui traîne. Une unit
# lancée à la main seulement n'est pas visée. Les fichiers d'units se lisent sur le disque, sans
# appeler systemctl, trop lent pour un hook. `%h` se développe, mais le dossier personnel seul
# n'est pas retenu : il ferait de tout dépôt de configuration un répertoire servi. Aucun nom d'unit n'est écrit ici, car le garde
# vient du noyau et sert tous les projets. Sur une machine sans units, il ne fait rien. Un
# worktree voisin change de branche librement, mais ne touche pas à la branche servie. Une table
# de cas remplace les dossiers servis par GARDE_DEPOT_DEPLOYE_DOSSIERS, ou les dossiers d'units
# par GARDE_DEPOT_DEPLOYE_UNITS (séparés par `:`).
#
# CE QU'IL NE VOIT PAS : un alias ou un `pull.rebase` écrits dans la config git du dépôt, et une
# édition directe des fichiers servis, qui n'est pas un geste git.
#
# IL ÉCHOUE OUVERT : un hook PreToolUse qui plante bloque l'outil. Tout imprévu sort en zéro.
set -uo pipefail
charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0
fichier=$(mktemp 2>/dev/null) || exit 0
trap 'rm -f "$fichier"' EXIT
printf '%s' "$charge" > "$fichier" 2>/dev/null || exit 0
CHARGE_FICHIER="$fichier" python3 - 2>/dev/null <<'PY' || exit 0
import glob, json, os, re, shlex, subprocess

MOTS_SUSPECTS = (r"\b(checkout|switch|reset|rebase|bisect|pull|restore|symbolic-ref|update-ref"
                 r"|alias\.)")
GESTES = {"checkout", "switch", "reset", "rebase", "bisect", "pull", "restore", "symbolic-ref",
          "update-ref"}
GLOBALES_A_VALEUR = {"-c", "-C", "--git-dir", "--work-tree", "--namespace", "--config-env",
                     "--exec-path", "--super-prefix", "--list-cmds"}
# Options de checkout et switch qui créent une branche ou détachent HEAD.
CREENT = {"-b", "-B", "-c", "-C", "--orphan", "--detach", "-d"}
LONGUES_ALIAS = {"--create": "-c", "--force-create": "-C", "--source": "-s", "--message": "-m"}
# Options à valeur séparée, par geste : leur valeur n'est pas une cible.
COURTES_A_VALEUR = {"rebase": "Xsx", "pull": "Xs", "restore": "s", "update-ref": "m",
                    "symbolic-ref": "m", "checkout": "", "switch": "", "reset": "", "bisect": ""}
LONGUES_A_VALEUR = {"--conflict", "--pathspec-from-file", "--strategy", "--strategy-option",
                    "--onto", "--exec", "-s", "-m"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh"}
PREFIXES = {"if", "then", "else", "elif", "do", "while", "until", "!", "{", "time", "env", "sudo",
            "nohup", "exec", "command", "nice", "ionice", "stdbuf", "timeout", "xargs", "builtin"}
PREFIXE_OPTIONS_A_VALEUR = {"-u", "-g", "-U", "-C", "-D", "-n", "-s", "-k", "--chdir"}
ETAT = {"dossier": os.getcwd(), "precedent": None, "servis": None, "pile": [], "empiles": [],
        "commits": {}, "accolades": []}


def refuser(geste, racine):
    nom = os.path.basename(racine)
    raison = ("Le repertoire deploye %s ne quitte jamais sa branche : « %s » y deplacerait HEAD, "
              "la branche servie ou son contenu, et un crash des units systemd le mettrait en "
              "production. Travaille dans un worktree voisin (git worktree add ../%s-<nom> -b "
              "<nom>) ou lis par git show <ref>:<fichier>. Voir scripts/garde-depot-deploye.sh."
              % (racine, geste[:80], nom))
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                             "permissionDecision": "deny",
                                             "permissionDecisionReason": raison}}))
    raise SystemExit(0)


# Du plus prioritaire au moins prioritaire, comme systemd les lit.
# Deux portées, système et utilisateur : une unit de même nom dans l'une ne masque pas l'autre.
DOSSIERS_UNITS = [
    ["/etc/systemd/system", "/run/systemd/transient", "/run/systemd/system",
     "/usr/local/lib/systemd/system", "/usr/lib/systemd/system", "/lib/systemd/system"],
    ["~/.config/systemd/user", "/etc/systemd/user", "/run/systemd/user",
     "~/.local/share/systemd/user", "/usr/local/lib/systemd/user", "/usr/lib/systemd/user"],
]


def lire_unit(fichier, reglages):
    try:
        lignes = open(fichier, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return
    for ligne in lignes:
        cle, egal, valeur = ligne.strip().partition("=")
        if egal and cle.strip() in ("WorkingDirectory", "Restart"):
            reglages[cle.strip()] = valeur.strip()


def servis():
    """Les `WorkingDirectory` des units qui redémarrent seules, lus une fois par appel."""
    if ETAT["servis"] is not None:
        return ETAT["servis"]
    brut = os.environ.get("GARDE_DEPOT_DEPLOYE_DOSSIERS")
    if brut is not None:
        ETAT["servis"] = {os.path.realpath(d) for d in brut.split(":") if d}
        return ETAT["servis"]
    portees = os.environ.get("GARDE_DEPOT_DEPLOYE_UNITS")
    portees = [portees.split(":")] if portees is not None else DOSSIERS_UNITS
    ETAT["servis"] = set()
    maisons = {os.path.realpath(os.path.expanduser(m)) for m in ("~", "~root")}
    for rang, portee in enumerate(portees):
        # `%h` vaut le dossier personnel du gestionnaire : root pour une unit système.
        systeme = rang == 0 and len(portees) > 1
        maison = os.path.realpath(os.path.expanduser("~root" if systeme else "~"))
        units, dossiers = {}, [os.path.expanduser(d) for d in reversed(portee)]
        for dossier in dossiers:
            for f in glob.glob(dossier + "/*.service"):
                units[os.path.basename(f)] = {}
                lire_unit(f, units[os.path.basename(f)])
        for dossier in dossiers:
            for f in sorted(glob.glob(dossier + "/*.service.d/*.conf")):
                lire_unit(f, units.setdefault(os.path.basename(os.path.dirname(f))[:-2], {}))
        for reglages in units.values():
            # systemd préfixe d'un `-` ou d'un `!` les dossiers optionnels ou privilégiés, et
            # `%h` est le dossier personnel, forme courante d'une unit utilisateur.
            dossier = reglages.get("WorkingDirectory", "").lstrip("-!+").replace("%h", maison)
            if reglages.get("Restart", "no") in ("", "no") or not dossier.startswith("/") \
                    or "%" in dossier:
                continue
            # Un dossier personnel lui-même n'est pas un dépôt servi : il ferait de tout dépôt
            # de fichiers de configuration un répertoire déployé. Une unit système qui tourne
            # dans le dossier de l'utilisateur compte aussi.
            if os.path.realpath(dossier) not in maisons:
                ETAT["servis"].add(os.path.realpath(dossier))
    return ETAT["servis"]


def git(racine, *args):
    return subprocess.run(["git", "-C", racine, *args], capture_output=True, text=True, timeout=5)


def contexte(dossier):
    """(racine du worktree courant, {worktree servi du même dépôt: sa branche}), ou None."""
    if dossier is None or not os.path.isdir(dossier):
        return None
    r = git(dossier, "rev-parse", "--show-toplevel")
    if r.returncode != 0 or not servis():
        return None
    racine = os.path.realpath(r.stdout.strip())
    deployes, courant = {}, None
    for ligne in git(dossier, "worktree", "list", "--porcelain").stdout.splitlines() + [""]:
        if ligne.startswith("worktree "):
            courant = [os.path.realpath(ligne[9:]), "main"]
        elif ligne.startswith("branch refs/heads/") and courant:
            courant[1] = ligne[18:]
        elif not ligne and courant:
            if any(d == courant[0] or d.startswith(courant[0] + os.sep) for d in servis()):
                deployes[courant[0]] = courant[1]
            courant = None
    return (racine, deployes) if deployes else None


def commit_de(racine, nom):
    cle = (racine, nom)
    if cle not in ETAT["commits"]:
        r = git(racine, "rev-parse", "--verify", "-q", nom + "^{commit}")
        ETAT["commits"][cle] = r.stdout.strip() if r.returncode == 0 else None
    return ETAT["commits"][cle]


def est_reference(racine, nom):
    return commit_de(racine, nom) is not None


def volatile(nom):
    return re.split(r"[\^~@]", nom)[0] in ("FETCH_HEAD", "ORIG_HEAD", "MERGE_HEAD")


def en_place(racine, nom, branche):
    """`nom` désigne HEAD ou l'amont de la branche, sous quelque nom qu'on l'écrive."""
    if nom in (branche, "HEAD", "@", "origin/" + branche):
        return True
    # Ces références bougent au fil de la ligne, par un fetch ou un reset qui précède : leur
    # valeur d'avant ne dit rien de celle qu'elles auront au moment du geste.
    if volatile(nom):
        return False
    commit = commit_de(racine, nom)
    return commit is not None and commit in {commit_de(racine, n)
                                             for n in ("HEAD", "@{u}", "origin/" + branche)}


def est_fichier(dossier, nom):
    """Un fichier sur le disque, ou suivi par git même effacé depuis."""
    if os.path.exists(os.path.join(dossier, nom)):
        return True
    return git(dossier, "ls-files", "--error-unmatch", "--", nom).returncode == 0


def chemin(base, mot):
    """Un chemin tapé, développé comme le shell le ferait. None si on ne sait pas le résoudre."""
    # Seuls `$HOME` et `$PWD` se développent sûrement. Toute autre variable vit dans le shell de
    # la session, que l'environnement de ce hook ne reflète pas.
    maison = os.path.expanduser("~")
    mot = re.sub(r"\$(\{HOME\}|HOME\b)", lambda _: maison, os.path.expanduser(mot))
    if base is not None:
        mot = re.sub(r"\$(\{PWD\}|PWD\b)", lambda _: base, mot)
    if "$" in mot:
        return None
    # Un chemin absolu se résout même quand on a perdu la trace du dossier courant.
    return mot if os.path.isabs(mot) else None if base is None else os.path.join(base, mot)


def depot_de(git_dir, base):
    """Le worktree d'un `GIT_DIR` ou d'un `--git-dir` : le dossier qui porte ce `.git`."""
    p = chemin(base, git_dir)
    if p is None:
        return None
    p = os.path.normpath(p)
    return os.path.dirname(p) if os.path.basename(p) == ".git" else p


def heredocs_de_shell_en_sous_shell(texte):
    """Le corps d'un `bash <<EOF` tourne dans un shell fils : on l'entoure de parenthèses."""
    sortie, fin = [], None
    for ligne in texte.split("\n"):
        if fin is not None and ligne.strip() == fin:
            sortie.append(")")
            fin = None
        sortie.append(ligne)
        m = re.search(r"(^|[\s;&|(])(%s)(\s[^<]*)?<<-?\s*['\"]?([^\s'\"<>;&|()]+)" % "|".join(SHELLS),
                      ligne)
        if fin is None and m:
            fin = m.group(4)
            sortie.append("(")
    return "\n".join(sortie)


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


def fin_ansi(texte, i):
    """L'indice qui suit une chaîne `$'…'`, où `\\'` n'est qu'une apostrophe échappée."""
    j = i + 2
    while j < len(texte) and texte[j] != "'":
        j += 2 if texte[j] == "\\" else 1
    return j + 1


def capturer(texte, i):
    """Le contenu de `$(…)` qui ouvre en i, et l'indice qui suit sa parenthèse fermante."""
    niveau, j, apostrophe, guillemet = 1, i + 2, False, False
    while j < len(texte) and niveau:
        c = texte[j]
        if c == "\\" and not apostrophe:
            j += 2
            continue
        if not apostrophe and not guillemet and texte.startswith("$'", j):
            j = fin_ansi(texte, j)
            continue
        if c == "#" and not apostrophe and not guillemet and texte[j - 1] in " \t\n;&|(":
            # Un commentaire : son apostrophe n'ouvre rien.
            fin = texte.find("\n", j)
            j = len(texte) if fin < 0 else fin
            continue
        if c == "'" and not guillemet:
            apostrophe = not apostrophe
        elif c == '"' and not apostrophe:
            guillemet = not guillemet
        elif not apostrophe and not guillemet:
            niveau += {"(": 1, ")": -1}.get(c, 0)
        j += 1
    return texte[i + 2:j - 1], j


def decouper(texte):
    """Rend ("sep", s) pour un séparateur, ("cmd", commande, substitutions) pour une commande.

    Le texte brut garde ses guillemets : `'$(x)'` n'est que du texte, `"$(x)"` tourne. Une
    substitution est retirée de sa commande, remplacée par un mot neutre, et rendue à part.
    """
    courant, subs, i = [], [], 0
    apostrophe = guillemet = False
    texte = texte.replace("\\\n", " ")

    def rendre():
        commande = "".join(courant).strip()
        courant.clear()
        trouvees = subs[:]
        subs.clear()
        return [("cmd", commande, trouvees)] if commande or trouvees else []

    while i < len(texte):
        c = texte[i]
        if apostrophe:
            apostrophe = c != "'"
        elif c == "\\":
            courant.append(texte[i:i + 2])
            i += 2
            continue
        elif c == "'" and not guillemet:
            apostrophe = True
        elif c == '"':
            guillemet = not guillemet
        elif not guillemet and texte.startswith("$'", i):
            fin = fin_ansi(texte, i)
            courant.append(texte[i:fin])
            i = fin
            continue
        elif texte.startswith("$((", i):
            fin = texte.find("))", i + 3)
            fin = fin + 2 if fin >= 0 else len(texte)
            courant.append(texte[i:fin])
            i = fin
            continue
        elif texte.startswith("$(", i):
            contenu, i = capturer(texte, i)
            subs.append(contenu)
            # Un mot porteur de `$` : une cible inconnue, comme une variable.
            courant.append("$SUBSTITUTION")
            continue
        elif c == "`":
            fin = texte.find("`", i + 1)
            fin = fin if fin > i else len(texte)
            subs.append(texte[i + 1:fin])
            courant.append("$SUBSTITUTION")
            i = fin + 1
            continue
        elif not guillemet and c == "#" and (i == 0 or texte[i - 1] in " \t\n;&|("):
            fin = texte.find("\n", i)
            i = len(texte) if fin < 0 else fin
            continue
        elif not guillemet and c in ";&|\n()":
            # `2>&1`, `&>` et `>&` sont des redirections, pas des séparateurs.
            if c == "&" and (texte[i - 1:i] in (">", "<") or texte[i + 1:i + 2] == ">"):
                courant.append(c)
                i += 1
                continue
            yield from rendre()
            double = texte[i:i + 2]
            if double == "|&":
                yield ("sep", "|")  # un pipe qui emporte aussi la sortie d'erreur
                i += 2
            elif double in ("&&", "||", ";;"):
                yield ("sep", double)
                i += 2
            else:
                yield ("sep", c)
                i += 1
            continue
        courant.append(c)
        i += 1
    yield from rendre()


def juger_texte(texte, profondeur=0):
    # Le corps d'un heredoc est du texte : ses accents graves ne lancent rien (rejeu du 2026-09-25).
    texte = sans_heredocs(heredocs_de_shell_en_sous_shell(texte))
    avant, en_pipe = ETAT["dossier"], False
    for element in decouper(texte):
        if element[0] == "sep":
            if element[1] == "(":
                ETAT["pile"].append(ETAT["dossier"])
            elif element[1] == ")" and ETAT["pile"]:
                # Le groupe entier est le membre de pipe qui suit peut-être : il repart d'ici.
                ETAT["dossier"] = avant = ETAT["pile"].pop()
            elif element[1] == "|":
                # Chaque membre d'un pipe tourne dans son propre sous-shell.
                ETAT["dossier"], en_pipe = avant, True
            else:
                en_pipe = False
            continue
        _, commande, subs = element
        avant = ETAT["dossier"]
        premier = commande.split(None, 1)[0] if commande.split() else ""
        if premier == "{":
            ETAT["accolades"].append(avant)
        elif premier.startswith("}") and ETAT["accolades"]:
            # Un groupe `{ …; }` suivi d'un pipe tourne dans un sous-shell : il repart d'ici.
            avant = ETAT["accolades"].pop()
        # Une substitution tourne là où en est la ligne, dans un sous-shell dont le `cd` ne sort pas.
        for sous in subs if profondeur < 3 else ():
            juger_texte(sous, profondeur + 1)
            ETAT["dossier"] = avant
        try:
            mots = shlex.split(commande)
        except ValueError:
            continue
        if mots:
            juger(mots, profondeur)
        if en_pipe:
            ETAT["dossier"] = avant


def lire_args(geste, args):
    """Sépare options, valeurs d'options et cibles. `-qb x` vaut `-q -b x`, `-bx` vaut `-b x`."""
    options, valeurs, cibles, i = [], {}, [], 0
    courtes_a_valeur = COURTES_A_VALEUR.get(geste, "")
    while i < len(args):
        a = args[i]
        if a == "-":
            cibles.append(a)  # `checkout -` : la branche précédente
        elif a.startswith("--"):
            nom, _, valeur = a.partition("=")
            nom = LONGUES_ALIAS.get(nom, nom)
            options.append(nom)
            if nom in LONGUES_A_VALEUR:
                if not valeur and i + 1 < len(args):
                    i += 1
                    valeur = args[i]
                valeurs[nom] = valeur
            elif valeur and nom in CREENT:
                cibles.append(valeur)
        elif a.startswith("-"):
            for j, c in enumerate(a[1:]):
                options.append("-" + c)
                reste = a[2 + j:]
                if "-" + c in CREENT and geste in ("checkout", "switch"):
                    if reste:
                        cibles.append(reste)
                    break
                if c in courtes_a_valeur:
                    if not reste and i + 1 < len(args):
                        i += 1
                        reste = args[i]
                    valeurs["-" + c] = reste
                    break
        else:
            cibles.append(a)
        i += 1
    return options, valeurs, cibles


def deplace(geste, args, racine, dossier, branche, reglages):
    """Vrai si ce geste git déplace HEAD hors de la branche, cette branche, ou son contenu."""
    amont = "origin/" + branche
    reste = {branche, "HEAD", "@"}

    def en_place_(nom):
        return en_place(racine, nom, branche)

    if "--" in args:
        avant, apres = args[:args.index("--")], args[args.index("--") + 1:]
    else:
        avant, apres = args, []
    options, valeurs, cibles = lire_args(geste, avant)
    if geste in ("checkout", "switch"):
        cree = [o for o in options if o in CREENT]
        if cree:
            # `checkout -B main` vers HEAD ou l'amont remet la branche sans la quitter. Vers un
            # autre point, c'est un reset déguisé.
            return not (cree[0] in ("-B", "-C") and cibles[:1] == [branche]
                        and (len(cibles) < 2 or en_place_(cibles[1])))
        if not cibles:
            return False  # restaurer depuis l'index : garde-perte-seche.sh en juge
        premiere = cibles[0]
        if premiere in reste:
            return False
        if geste == "checkout" and (apres or len(cibles) > 1 or "-p" in options):
            # Une référence suivie de fichiers pose le contenu de ce commit dans l'arbre servi.
            if en_place_(premiere):
                return False
            return est_reference(racine, premiere) or not est_fichier(dossier, premiere)
        if geste == "checkout" and not est_reference(racine, premiere) \
                and est_fichier(dossier, premiere):
            return False
        # Une branche seulement distante, une variable, un `$(…)` : git peut y basculer.
        return True
    if geste == "restore":
        source = valeurs.get("-s")
        return source is not None and not en_place_(source)
    if geste == "reset":
        if apres or len(cibles) != 1 or en_place_(cibles[0]):
            return False
        return "$" in cibles[0] or volatile(cibles[0]) or est_reference(racine, cibles[0])
    if geste == "rebase":
        return not any(o in ("--abort", "--continue", "--skip", "--show-current-patch",
                             "--edit-todo") for o in options)
    if geste == "pull":
        faux = ("false", "no", "0", "off")
        if "--no-rebase" in options:
            return False
        valeur = next((a.partition("=")[2] for a in avant if a.startswith("--rebase=")), None)
        if valeur is not None:
            return valeur.lower() not in faux
        config = reglages.get("pull.rebase", reglages.get("branch.%s.rebase" % branche, "false"))
        return "--rebase" in options or "-r" in options or config not in faux
    if geste == "bisect":
        if cibles[:1] == ["start"]:
            return True
        return cibles[:1] == ["reset"] and len(cibles) > 1 and cibles[1] not in reste
    if geste == "symbolic-ref":
        return cibles[:1] == ["HEAD"] and (len(cibles) > 1 or "-d" in options)
    return False


def touche_branche_servie(args, racine, deployes):
    """`update-ref` vise une branche servie, commune à tous les worktrees du dépôt."""
    options, _, cibles = lire_args("update-ref", args)
    if "--stdin" in options:
        return True  # ses ordres ne se lisent pas ici
    if not cibles:
        return False
    ref = cibles[0]
    if ref == "HEAD":
        return racine in deployes and "--no-deref" not in options
    return any(ref in (b, "refs/heads/" + b) for b in deployes.values())


def juger(mots, profondeur=0):
    # Une redirection n'est pas un argument. Le cas fondateur finissait par `-- 2>/dev/null`.
    propres, k = [], 0
    while k < len(mots):
        # `&>`, `&>>` et `>&` aussi : `reset --hard HEAD~1 &>/dev/null` garde sa seule cible.
        if re.match(r"^(\d*(>>?|<)|&>)", mots[k]):
            k += 2 if re.fullmatch(r"\d*(>>?|<|>&)|&>>?", mots[k]) else 1
            continue
        propres.append(mots[k])
        k += 1
    mots = propres
    dossier = ETAT["dossier"]
    while mots and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", mots[0]) or mots[0] in PREFIXES):
        mot = mots.pop(0)
        # `GIT_DIR=x` désigne le dépôt aussi sûrement qu'un `cd`. `GIT_WORK_TREE` non : HEAD vit
        # dans le dépôt, que git trouve alors depuis le dossier courant.
        if mot.startswith("GIT_DIR="):
            dossier = depot_de(mot[8:], dossier)
        prefixe = mot in PREFIXES
        while prefixe and mots and (mots[0].startswith("-") or re.fullmatch(r"[\d.]+[smhd]?", mots[0])):
            option = mots.pop(0)
            if option in PREFIXE_OPTIONS_A_VALEUR and mots:
                valeur = mots.pop(0)
                if mot == "env" and option in ("-C", "--chdir"):
                    dossier = chemin(dossier, valeur)
            elif mot == "env" and option.startswith("--chdir="):
                dossier = chemin(dossier, option.split("=", 1)[1])
    if not mots:
        return
    nom = os.path.basename(mots[0])
    if nom in ("cd", "pushd", "popd"):
        args = [a for a in mots[1:] if a not in ("--", "-L", "-P", "-n")]
        if nom == "popd":
            nouveau = ETAT["empiles"].pop() if ETAT["empiles"] else None
        elif nom == "pushd" and not args:
            nouveau = None  # échange les deux sommets de la pile : on ne suit pas
        elif args[:1] == ["-"]:
            nouveau = ETAT["precedent"]
        else:
            nouveau = chemin(ETAT["dossier"], args[0] if args else "~")
        if nom == "pushd":
            ETAT["empiles"].append(ETAT["dossier"])
        ETAT["precedent"], ETAT["dossier"] = ETAT["dossier"], nouveau
        return
    if profondeur < 3 and nom == "eval":
        juger_texte(" ".join(mots[1:]), profondeur + 1)
        return
    if profondeur < 3 and nom in SHELLS:
        if any(a.startswith("-") and not a.startswith("--") and "c" in a for a in mots[1:]):
            garde = ETAT["dossier"]
            juger_texte(next((a for a in mots[1:] if not a.startswith("-")), ""), profondeur + 1)
            ETAT["dossier"] = garde
        return
    if nom != "git":
        return
    i, alias, reglages = 1, {}, {}
    while i < len(mots) and mots[i].startswith("-"):
        o = mots[i]
        suivant = mots[i + 1] if i + 1 < len(mots) else ""
        if o == "-C":
            dossier = chemin(dossier, suivant)
        if o == "-c":
            cle, _, valeur = suivant.partition("=")
            reglages[cle.lower()] = valeur.lower() or "true"
            m = re.match(r"^alias\.([^=]+)=!?\s*(?:git\s+)?(.*)$", suivant, re.I)
            if m:
                alias[m.group(1)] = m.group(2).split()
        if o == "--git-dir":
            dossier = depot_de(suivant, dossier)
        elif o.startswith("--git-dir="):
            dossier = depot_de(o[10:], dossier)
        i += 2 if o in GLOBALES_A_VALEUR else 1
    if i >= len(mots):
        return
    geste, args = mots[i], mots[i + 1:]
    if geste in alias and alias[geste]:
        geste, args = alias[geste][0], alias[geste][1:] + args
    if geste not in GESTES:
        return
    ctx = contexte(dossier)
    if ctx is None:
        return
    racine, deployes = ctx
    if geste == "update-ref":
        if touche_branche_servie(args, racine, deployes):
            refuser(" ".join(mots), next(iter(deployes)))
        return
    if racine in deployes and deplace(geste, args, racine, dossier, deployes[racine], reglages):
        refuser(" ".join(mots), racine)


charge = json.load(open(os.environ["CHARGE_FICHIER"]))
cmd = charge.get("tool_input", {}).get("command", "")
if isinstance(charge.get("cwd"), str):
    ETAT["dossier"] = charge["cwd"]
if not isinstance(cmd, str) or not re.search(MOTS_SUSPECTS, cmd):
    raise SystemExit(0)
try:
    juger_texte(cmd)
except ValueError:
    pass
PY
exit 0
