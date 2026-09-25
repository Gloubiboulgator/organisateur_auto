#!/usr/bin/env bash
# garde-perte-seche.sh — refuse un geste de l'agent qui efface ce qu'aucune copie ne rend.
#
# POURQUOI CE GARDE EXISTE (2026-09-09)
# -------------------------------------
# Le 2026-09-09, dans un projet équipé, l'agent a purgé 1 392 fichiers d'un `find -delete`,
# après un inventaire par suffixe et par date. Onze d'entre eux étaient les preuves qu'un
# détecteur avait posées, nommées la veille dans un relevé qu'il n'avait pas relu. Elles ont été
# retrouvées après coup dans une sauvegarde de nuit, par chance et non par méthode : une copie
# qui existe ailleurs n'est pas une copie que l'agent peut invoquer. La règle « aucune
# suppression ne repose sur un @suppose » existait, et n'a rien retenu. La question n'est pas le
# dossier. C'est : ce qui part, quelque chose le rend ?
#
# CE QU'IL JUGE
# -------------
# Chaque chemin visé par un verbe d'effacement, et chaque geste git qui jette du travail.
#   - jetable : sous un dossier temporaire, ou un artefact que la machine régénère. Passe.
#   - suivi par git, sans modification : git le rend. Passe.
#   - tout le reste est une PERTE SÈCHE. Refusé, avec l'inventaire de ce qui partait.
#   - un chemin qu'on ne sait pas résoudre, ni développer : refusé, et dit.
# Une perte sèche se fait de la main de l'admin, jamais de celle de l'agent.
#
# CE QU'IL VOYAIT MAL, ET QUI EST CORRIGÉ LE 2026-09-10
# ------------------------------------------------------
# Une revue a joué des charges au garde plutôt que de lire son code. Six contournements sont
# sortis, tous mesurés, tous rejoués sur les deux copies. Ils tenaient à trois causes.
#
#   1. LE DÉCOUPAGE. `shlex` noie le retour à la ligne dans ses blancs, donc le jeton "\n"
#      que cherchait la boucle n'était jamais émis. Une commande écrite sur deux lignes
#      n'était jugée que sur son premier mot. Et `punctuation_chars` COLLE les ponctuations
#      voisines : « ); » sortait en un seul jeton, que la liste fermée ne reconnaissait pas.
#      Un sous-shell suffisait donc à éteindre le garde. Même chose pour la redirection :
#      son motif avalait « /dev/null; » en entier, séparateur compris.
#   2. LE VERBE. Il n'était cherché qu'en mot-commande. `xargs rm`, `bash -c`, `eval`, une
#      boucle `for`, `nohup` passaient tous. Le premier est le jumeau du `find -delete`
#      fondateur : c'est la forme la plus courante d'une purge.
#   3. LE LIEU. Les cibles étaient résolues contre le dossier de la charge, jamais mis à
#      jour. `cd data && rm -rf captures` jugeait donc `./captures`, qui n'existe pas, et
#      passait. Pire, un homonyme pouvait être jugé à la place de la vraie cible.
#
# S'y ajoutait `git clean`, simulé en dur par `git clean -nd` : ni les options tapées, ni le
# pathspec. Sans `-x`, la simulation est aveugle sur tout ce que `.gitignore` couvre. Dans le
# projet où l'incident a eu lieu, c'est exactement `.env` et `data/`.
#
# CE QU'IL VOYAIT MAL, ET QUI EST CORRIGÉ LE 2026-09-15
# -----------------------------------------------------
# Une deuxième revue a rejoué la même méthode, des charges plutôt qu'une lecture. Sept défauts
# sont sortis, tous mesurés. Six laissaient passer une destruction. Le septième refusait un
# geste qui ne perd rien.
#
#   1. LE GUILLEMETAGE. Le retrait des redirections travaillait sur le texte entier, guillemets
#      compris. Un « < » écrit DANS une chaîne partait avec ce qui suivait. Le guillemetage
#      devenait impair, `shlex` renonçait, et toutes les commandes suivantes cessaient d'être
#      jugées. Un message de commit suffisait.
#   2. LA MORT DU GARDE. Une jointure avec un `cd` non résolu levait TypeError. Le processus
#      mourait, donc la charge entière passait.
#   3. LES OPTIONS DE `git clean`. Le motif de `-e` était pris pour un chemin, donc la
#      simulation ne portait plus que sur lui. Et une valeur collée entrait lettre par lettre
#      dans les options courtes, où son « n » se lisait comme un essai à blanc.
#   4. LE LIEN SOUS /tmp. Un raccourci sur le TEXTE du chemin rendait la main avant la
#      résolution des liens, qui existait pourtant juste pour ce cas.
#   5. CE QUE LE SHELL DÉVELOPPE. Accolades, substitution de commande et marque de xargs
#      étaient jugées telles quelles. Introuvables sur le disque, elles passaient pour « rien
#      à perdre ».
#   6. LE HEREDOC. Son corps devenait des commandes indépendantes, donc l'effacement qu'il
#      portait n'appartenait plus à aucun verbe. Le commentaire du volet Python affirmait
#      pourtant ce cas couvert depuis le 2026-09-10.
#   7. LE FAUX POSITIF. Un `git checkout <branche>` ordinaire était refusé dès que l'arbre
#      était sale. Git refuse lui-même d'écraser une modification locale, et ne perd rien.
#
# UNE SECONDE REVUE A REJOUÉ LA MÊME MÉTHODE, LE MÊME JOUR
# --------------------------------------------------------
# Sept autres défauts en sont sortis, tous mesurés. Cinq tenaient aux correctifs ci-dessus.
#
#   1. LE DÉLIMITEUR DU HEREDOC n'était reconnu qu'en mot nu. Trois formes courantes lui
#      échappaient, l'échappé, celui à tiret et celui à point.
#   2. LE MOTIF DU HEREDOC coûtait le carré de la taille de la charge, et sa boucle
#      s'arrêtait au quatrième bloc. Une lecture ligne à ligne remplace les deux.
#   3. LE CORPS RECOLLÉ devenait un jeton unique, que `shlex` relit caractère par
#      caractère. Seules les lignes qui portent un effacement y entrent désormais.
#   4. LE COMPTEUR DE PARENTHÈSES d'une substitution ignorait les guillemets. Une
#      parenthèse écrite dans une chaîne faisait sauter le curseur au-delà du texte.
#   5. LE TEST DU NON DÉVELOPPÉ ne servait qu'à la boucle des cibles. Les pathspecs de
#      `git clean` et de `git checkout` recevaient la marque sans être jugés.
#   6. LE RACCOURCI TEMPORAIRE, retiré la veille, refusait « rm -rf /tmp/build-* » à vide.
#      Il revient, mais liens résolus des deux côtés.
#   7. `-B` ET `-C` recréent une branche existante sans porter de drapeau de forçage.
#
# UNE QUATRIÈME RONDE, ET LA CAUSE RACINE ENFIN NOMMÉE
# ----------------------------------------------------
# Trois rondes de suite ont trouvé un trou dans le MÊME volet, celui de checkout. La cause
# n'était aucune des options prises une à une. C'était l'absence d'analyseur.
#
# Le volet cherchait des jetons entiers dans une liste, donc un groupe court lui échappait.
# « -fB » n'était ni « -f » ni « -B ». Il prenait aussi pour un chemin tout argument libre qui
# n'était pas une référence. Or le mot qui suit un `-b` est un nom de branche.
#
# options_git_arbre lit désormais les options lettre par lettre, comme options_git_clean. Le
# volet ne devine plus rien. Trois autres défauts du même jour tenaient au temps de calcul.
# La leçon s'est répétée trois fois : toute recherche non bornée finit par tuer le garde.
#
# CE QUE LA CORRECTION TRANCHE, ET QUI N'ALLAIT PAS DE SOI
# -------------------------------------------------------
# Le cinquième défaut demandait de choisir un régime, pas d'écrire un correctif. Une cible que
# le garde a su LIRE et qui n'existe pas reste un laissez-passer. Une cible qu'il n'a pas su
# DÉVELOPPER est refusée.
#
# La frontière est là parce que les deux ignorances ne se valent pas. Un `rm -f` sur un fichier
# déjà parti ne perd rien, et le refuser gênerait sans protéger. Une accolade non développée,
# elle, peut désigner tout l'arbre, et le garde n'a rien à montrer à l'admin.
#
# COMMENT IL EST POSÉ
# -------------------
# Dans le gabarit des réglages du noyau, chemin en `${CLAUDE_PROJECT_DIR}`. Il suit donc le clone
# d'un projet équipé, et ne demande aucun geste d'installation. Un projet DÉJÀ équipé possède son
# fichier de réglages : l'installateur lui dicte la ligne à ajouter sous le matcher `Bash`.
# Une NOUVELLE session Claude Code doit s'ouvrir pour qu'un settings modifié soit relu.
#
# IL ÉCHOUE OUVERT. Python de la bibliothèque standard, sortie en zéro sur toute exception.
#
# ON LE REJOUE, ON NE LE RELIT PAS. Les quarante-cinq contournements des deux rondes vivent en
# cas dans modeles/essai-garde-perte-seche.txt, avec le dépôt d'essai qui va avec.
#
#     bash modeles/essai-garde-perte-seche.sh
#
# Rien ne le lance tout seul, c'est un outil de la main. Toute retouche de ce fichier se joue
# contre lui AVANT d'être poussée, et y verse les formes qu'elle a trouvées.
set -uo pipefail
charge=$(cat 2>/dev/null) || exit 0
[ -n "$charge" ] || exit 0
# La charge passe par un FICHIER, pas par l'environnement. Une variable d'environnement est
# bornée à 128 Kio : au-delà, l'exec échouait et le garde devenait un no-op muet. Une purge
# écrite en boucle déroulée dépasse cette taille. Mesuré le 2026-09-10.
fichier=$(mktemp 2>/dev/null) || exit 0
trap 'rm -f "$fichier"' EXIT
printf '%s' "$charge" > "$fichier" 2>/dev/null || exit 0
CHARGE_FICHIER="$fichier" python3 - 2>/dev/null <<'PY' || exit 0
import bisect, glob, json, os, re, shlex, subprocess, sys
from collections import Counter
from pathlib import Path

JETABLE_DOSSIERS = {"venv", ".venv", "node_modules", "__pycache__", ".pytest_cache", ".mypy_cache",
                    ".ruff_cache", ".cache", "build", "dist", ".gradle", "web-ext-artifacts", "site-packages"}
JETABLE_SUFFIXES = (".pyc", ".pyo", ".tmp", ".swp", ".bak~")
TEMP_RACINES = ("/tmp/", "/var/tmp/", "/dev/shm/")
# Les mêmes racines, liens résolus. Voir sous_racine_temporaire pour le motif.
TEMP_RACINES_RESOLUES = tuple(os.path.realpath(r.rstrip("/")).rstrip("/") + "/" for r in TEMP_RACINES)
VERBES_EFFACEMENT = ("rm", "shred", "unlink", "rmdir")
SHELLS = ("sh", "bash", "zsh", "dash", "ksh")
# Ce qui précède le vrai mot-commande sans rien effacer : préfixes, et ouvertures de bloc.
PREFIXES = ("sudo", "env", "nice", "timeout", "nohup", "time", "command", "exec", "stdbuf", "ionice")
OUVRE_BLOC = ("do", "then", "else", "{", "!")
# Un jeton fait de ces seuls caractères est une frontière, quelle que soit sa longueur.
SEPARATEURS = set(";&|()<>")

# CE QUE LE GARDE SAIT DU DISQUE ET DE GIT
# ----------------------------------------
def sous_racine_temporaire(chemin: str) -> bool:
    """Ce chemin mène-t-il sous une racine temporaire, liens suivis ?

    LES DEUX BOUTS SE RÉSOLVENT, et il en manquait un. Seule la cible passait par realpath, pas
    les racines. Sur un système où /tmp est lui-même un lien, un chemin temporaire résolu ne
    commence donc plus par /tmp, et aucune cible n'était reconnue comme jetable.
    """
    s = os.path.realpath(chemin)
    return any(s.startswith(r) for r in TEMP_RACINES + TEMP_RACINES_RESOLUES)


def non_developpe(mot: str) -> bool:
    """Ce mot porte-t-il ce que le shell aurait développé, et que le garde ne développe pas ?

    Accolades, substitution de commande, marque de remplacement de xargs. Le test vivait dans la
    seule boucle des cibles, donc les pathspecs de git y échappaient. Mesuré le 2026-09-15.
    """
    return SUBSTITUTION in mot or bool(re.search(r"[{}]|\$\(|`", mot))


def git(cwd, *args):
    r = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True)
    return r.returncode, r.stdout

_racines = {}
def racine_git(p: Path):
    """La racine du dépôt qui contient ce chemin, ou None. Mémoïsée par dossier : le coût du
    garde croît avec le nombre de cibles, et c'est ici que git était appelé le plus souvent."""
    dossier = str(p if p.is_dir() else p.parent)
    if dossier not in _racines:
        rc, sortie = git(dossier, "rev-parse", "--show-toplevel")
        _racines[dossier] = None if rc else sortie.strip()
    return _racines[dossier]

def fichiers_sous(p: Path):
    """Les fichiers d'un dossier, sans descendre dans `.git`.

    L'inventaire remis à l'admin comptait les objets de `.git`, et annonçait des milliers de
    fichiers là où trois partaient. Mesuré le 2026-09-10."""
    return [f for f in p.rglob("*") if f.is_file() and ".git" not in f.parts]

def est_jetable(p: Path, temp_vars):
    """Sous une racine temporaire, ou un artefact que la machine régénère.

    Les dossiers jetables ne sont cherchés QUE sous la racine du dépôt. Ils l'étaient sur le
    chemin absolu entier : un dépôt rangé sous un dossier nommé `.cache`, `build` ou `dist`
    n'était plus gardé du tout, sur tout son arbre. Mesuré le 2026-09-10."""
    # Le chemin est RÉSOLU avant le test des racines temporaires. Il était comparé en texte, donc
    # un lien sous /tmp faisait passer la destruction de ce qu'il visait ailleurs. 2026-09-10.
    if sous_racine_temporaire(str(p)) or any(os.path.realpath(str(p)).startswith(t) for t in temp_vars):
        return True
    s = str(p)
    if s.endswith(JETABLE_SUFFIXES):
        return True
    racine = racine_git(p)
    parts = p.parts
    if racine:
        try:
            parts = p.relative_to(racine).parts
        except ValueError:
            pass
    return any(part in JETABLE_DOSSIERS for part in parts)

def est_rendu_par_git(p: Path):
    """Suivi par git et sans modification : git le rend. Un dossier l'est si tout ce qu'il
    contient l'est, et qu'aucun fichier non suivi n'y dort.

    Deux verdicts faux sont partis le 2026-09-10. Les fichiers suivis étaient COMPTÉS en
    jetons, donc un nom avec une espace en valait deux, dans les deux sens. Et un artefact
    régénérable posé dans un dossier suivi faisait refuser le dossier entier, alors que rien
    ne se perd à le jeter. Un fichier ignoré qui n'est PAS régénérable, lui, reste une perte."""
    racine = racine_git(p)
    if not racine:
        return False
    rc, statut = git(racine, "status", "--porcelain", "--untracked-files=all", "--", str(p))
    if rc or statut.strip():
        return False
    if p.is_dir():
        rc, suivis = git(racine, "ls-files", "-z", "--", str(p))
        n_suivis = len([x for x in suivis.split("\0") if x])
        sur_disque = [f for f in fichiers_sous(p) if not est_jetable(f, set())]
        return n_suivis == len(sur_disque) and n_suivis > 0
    rc, _ = git(racine, "ls-files", "--error-unmatch", "--", str(p))
    return rc == 0

def ne_perd_rien(p: Path):
    """Un dossier sans aucun fichier ne fait perdre personne.

    `rmdir` d'un dossier vide était refusé, avec un motif qui disait lui-même « 0 fichier(s) ».
    Un refus dont le texte se contredit apprend à passer outre. Mesuré le 2026-09-10."""
    return p.is_dir() and not fichiers_sous(p)

def inventaire(chemins):
    fichiers = []
    for p in chemins:
        fichiers += fichiers_sous(p) if p.is_dir() else [p]
    familles = Counter(re.sub(r"^[0-9][0-9-]*-?", "", f.name) or f.suffix for f in fichiers)
    tete = ", ".join(f"{n} x {fam}" for fam, n in familles.most_common(6))
    return f"{len(fichiers)} fichier(s), familles : {tete}"

_brut = ""
_f = os.environ.get("CHARGE_FICHIER")
if _f:
    try:
        with open(_f, encoding="utf-8", errors="replace") as _fh:
            _brut = _fh.read()
    except OSError:
        _brut = ""
charge = json.loads(_brut or os.environ.get("CHARGE", "") or "{}")
if charge.get("tool_name") not in (None, "Bash"):
    sys.exit(0)
commande = (charge.get("tool_input") or {}).get("command") or ""
cwd = charge.get("cwd") or os.getcwd()
if not commande.strip():
    sys.exit(0)

# Les variables posées dans la commande elle-même : X=$(mktemp -d) est temporaire, X=/chemin se remplace.
temp_vars, vars_ = set(), {}
# La valeur s'arrête au séparateur. Elle était prise en `\S+`, donc `CIBLE=chemin; rm "$CIBLE"`
# donnait une cible finissant par « ; ». Elle n'existe pas, donc « rien à perdre ». 2026-09-10.
for nom, val in re.findall(r"(?:^|[;&|\s])([A-Za-z_][A-Za-z0-9_]*)=(\$\(mktemp[^)]*\)|[^\s;&|)]+)", commande):
    if val.startswith("$(mktemp"):
        temp_vars.add("$" + nom); vars_[nom] = "/tmp/__mktemp__/" + nom
    else:
        vars_[nom] = val.strip("\"'")
def resoudre(tok):
    def rempl(m):
        nom = m.group(1) or m.group(2)
        if nom in vars_: return vars_[nom]
        # PWD ET OLDPWD NE SE LISENT PAS DANS L'ENVIRONNEMENT. Ils valent le dossier du
        # processus du garde, pas celui que la charge suit.
        #
        # « rm -rf $PWD/precieux » visait donc ailleurs, et passait. Ils sortent désormais en
        # « chemin non résolu ». Mesuré le 2026-09-15.
        if nom in ("PWD", "OLDPWD"): raise KeyError(nom)
        if nom in os.environ: return os.environ[nom]
        raise KeyError(nom)
    tok = re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)", rempl, tok)
    return os.path.expanduser(tok)

refus = []

# COMMENT LA LIGNE DE COMMANDE SE LIT
# -----------------------------------
def normaliser_lignes(cmd):
    """Un retour à la ligne hors guillemets sépare deux commandes, comme « ; ».

    `shlex` le range dans ses blancs, donc le jeton "\\n" n'est jamais émis. Une commande
    écrite sur deux lignes n'était jugée que sur la première. Mesuré le 2026-09-10. Un
    retour à la ligne échappé par « \\ » prolonge la commande : celui-là reste un blanc.
    """
    sortie, quote, echappe = [], "", False
    for ch in cmd:
        if echappe:
            sortie.append(ch); echappe = False; continue
        if ch == "\\" and quote != "'":
            sortie.append(ch); echappe = True; continue
        if quote:
            if ch == quote: quote = ""
            sortie.append(ch); continue
        if ch in "\"'":
            quote = ch; sortie.append(ch); continue
        sortie.append(";" if ch == "\n" else ch)
    return "".join(sortie)

def segments_de(cmd):
    """Les commandes simples, séparées sur ; && || | & et les parenthèses.

    `punctuation_chars` colle les ponctuations voisines : « ); » sort en UN jeton. La liste
    fermée d'avant ne le reconnaissait pas, et un sous-shell éteignait le garde. Tout jeton
    fait de ces seuls caractères est donc une frontière. Rend chaque segment avec le
    séparateur qui le précède, car un `|` dit d'où viennent les chemins.
    """
    lx = shlex.shlex(normaliser_lignes(cmd), posix=True, punctuation_chars=True)
    lx.whitespace_split = True
    seg, out, sep = [], [], ""
    try:
        for tok in lx:
            if tok and all(c in SEPARATEURS for c in tok):
                if seg: out.append((seg, sep))
                seg, sep = [], tok
            else:
                seg.append(tok)
    except ValueError:
        pass
    if seg: out.append((seg, sep))
    return out

# Le descripteur en tête, « 2> », est mangé par l'appelant, PAS par ce motif. Un « \d* » de
# tête revient sur ses pas à chaque chiffre d'une longue suite, et le coût devient le carré de
# sa longueur. Mesuré, 30 s pour 80 Kio de chiffres. C'est la faute que ce fichier a corrigée
# deux fois ailleurs le 2026-09-15, et elle vivait ici depuis le 2026-09-10.
REDIRECTION = re.compile(r"(?:>>|>|<)&?\s*[^\s;&|()<>]+")

def sans_redirections(cmd):
    """Les redirections ne sont pas des cibles : « 2>/dev/null » ne perd pas /dev/null.

    Le motif d'avant prenait la cible pour tout ce qui n'est pas un blanc. Il avalait donc
    « /dev/null; » avec son point-virgule, et les deux commandes fusionnaient en une.
    Il s'arrête maintenant sur un séparateur, et reconnaît une cible relative.

    IL NE REGARDE PLUS DANS LES GUILLEMETS, et c'est le trou le plus grave du lot du
    2026-09-15. Un « < » écrit DANS une chaîne y était pris pour une redirection, donc
    retiré avec ce qui suivait. Le guillemetage devenait impair, `shlex` levait ValueError,
    et TOUTES les commandes suivantes cessaient d'être jugées. Mesuré :
    « git commit -m "fix <thing>" ; rm -rf important » passait entier. La lecture est donc
    la même que celle de normaliser_lignes, caractère par caractère, état de guillemet tenu.
    """
    sortie, quote, echappe, i = [], "", False, 0
    while i < len(cmd):
        ch = cmd[i]
        if echappe:
            sortie.append(ch); echappe = False; i += 1; continue
        if ch == "\\" and quote != "'":
            sortie.append(ch); echappe = True; i += 1; continue
        if quote:
            if ch == quote: quote = ""
            sortie.append(ch); i += 1; continue
        if ch in "\"'":
            quote = ch; sortie.append(ch); i += 1; continue
        if ch.isdigit():
            # La suite de chiffres se franchit d'un coup. Ce qui la suit décide. Un « > » ou un
            # « < » en fait un descripteur de redirection. Tout le reste en fait du texte.
            #
            # ENCORE FAUT-IL QUE LE MOT COMMENCE LÀ. Un chiffre collé à la fin d'un nom était
            # pris pour un descripteur. « rm -rf important2>log » était donc jugé sur
            # « important », qui n'existe pas. Bash, lui, efface bien « important2 ».
            k = i
            while k < len(cmd) and cmd[k].isdigit():
                k += 1
            debut_de_mot = not sortie or sortie[-1][-1:] in ("", " ", "\t", ";", "&", "|", "(", ")")
            m = (REDIRECTION.match(cmd, k)
                 if debut_de_mot and k < len(cmd) and cmd[k] in "<>" else None)
            if m:
                sortie.append(" "); i = m.end(); continue
            sortie.append(cmd[i:k]); i = k; continue
        if ch in "<>":
            # LA CIBLE PEUT ÊTRE ENTRE GUILLEMETS, et le motif s'arrêtait au premier. Il mangeait
            # le guillemet ouvrant de « > 'mon fichier' », le guillemetage devenait impair, et
            # `shlex` renonçait sur tout ce qui suivait. C'est exactement la panne que la lecture
            # par caractère a fermée pour le « < » dans une chaîne, laissée ouverte en miroir.
            # Mesuré le 2026-09-15.
            k = i + (2 if cmd[i:i + 2] in (">>", "<<") else 1)
            if cmd[k:k + 1] == "&":
                k += 1
            while k < len(cmd) and cmd[k] in " \t":
                k += 1
            if cmd[k:k + 1] in ("'", '"'):
                q, k = cmd[k], k + 1
                while k < len(cmd) and cmd[k] != q:
                    k += 1
                sortie.append(" "); i = min(k + 1, len(cmd)); continue
            m = REDIRECTION.match(cmd, i)
            if m:
                sortie.append(" "); i = m.end(); continue
        sortie.append(ch); i += 1
    return "".join(sortie)


# LA MARQUE PORTE SES ESPACES, et sans elles le coût revenait par la porte de derrière. Deux
# marques voisines formaient un seul jeton sans blanc, que `shlex` recopie caractère par
# caractère. Mesuré, 51 s pour 100 Kio d'accents inversés, contre 0,23 s sur la version d'avant.
# Le butoir posé plus haut borne la RECHERCHE, pas la taille de ce qui sort.
SUBSTITUTION = "@substitution-non-developpee@"
# La marque, entourée de ses blancs, telle qu'elle s'écrit dans le texte.
MARQUE = " " + SUBSTITUTION + " "
# Au-delà, le garde renonce à trouver la fermeture. Voir le motif dans substitutions_marquees.
LIMITE_SUBSTITUTION = 4096

def substitutions_marquees(cmd):
    """Une substitution de commande devient UN jeton, et son corps repart dans la file.

    LE CORPS ÉTAIT EFFACÉ, ET LE MARQUAGE AVAIT PRIS UNE PROTECTION AU PASSAGE. Avant lui,
    `shlex` déchirait « $(rm -rf x) » en jetons, et la parenthèse servant de frontière, le
    « rm -rf x » devenait un segment que le garde jugeait. Le marquage l'a remplacé par une
    marque muette. Mesuré le 2026-09-15, « echo $(rm -rf important) » passait alors qu'il
    était refusé la veille.

    Rend le texte marqué, et les corps trouvés.

    Une substitution, c'est le « $(…) » ou les accents inversés qui remplacent une commande par
    ce qu'elle imprime. Le garde ne l'exécute pas, et il ne le doit pas : il jugerait en lançant
    ce qu'il est censé retenir.

    SANS CE MARQUAGE, ELLE NE SURVIVAIT PAS AU DÉCOUPAGE. `shlex` traite la parenthèse en
    ponctuation, donc « rm $(find …) » sortait en jetons « rm », « $ », « ( », « find »… La
    cible du `rm` devenait le seul caractère « $ », qui n'existe sur aucun disque, donc le garde
    y lisait « rien à perdre ». Mesuré le 2026-09-15.

    Le cas du mktemp garde le traitement qu'il a déjà pour une affectation : un dossier
    temporaire fraîchement créé n'est pas une perte. Le marquage ne descend pas dans les
    guillemets simples, qui empêchent la substitution, et descend dans les doubles, qui ne
    l'empêchent pas.
    """
    sortie, corps_tous, quote, echappe, i, echecs = [], [], "", False, 0, 0
    while i < len(cmd):
        ch = cmd[i]
        if echappe:
            sortie.append(ch); echappe = False; i += 1; continue
        if ch == "\\" and quote != "'":
            sortie.append(ch); echappe = True; i += 1; continue
        if quote == "'":
            if ch == "'": quote = ""
            sortie.append(ch); i += 1; continue
        if ch in "\"'" and not quote:
            quote = ch; sortie.append(ch); i += 1; continue
        if quote == '"' and ch == '"':
            quote = ""; sortie.append(ch); i += 1; continue
        if ch == "$" and cmd[i + 1:i + 2] == "(":
            # LE COMPTEUR DE PARENTHÈSES TIENT LES GUILLEMETS. Sans ça, une parenthèse écrite
            # dans une chaîne ne se refermait jamais. Le curseur sautait au-delà du texte, et
            # tout ce qui suivait la substitution sortait du jugement. Mesuré le 2026-09-15.
            #
            # LE SCAN EST BORNÉ, et c'est la même leçon que le motif de heredoc. Une ouverture
            # jamais refermée faisait lire le texte jusqu'au bout, puis recommencer à la
            # suivante. Mesuré, 49 s pour 60 Kio, donc le harnais tuait le garde avant la fin.
            #
            # Une substitution plus longue que la borne n'est de toute façon pas lisible par le
            # garde. Elle porte la marque, comme une substitution non refermée.
            #
            # APRÈS QUELQUES ÉCHECS, ON NE CHERCHE MÊME PLUS. Le butoir borne UNE recherche,
            # pas leur nombre : sur un texte plein de « $( » jamais refermés, chacune repayait
            # ses quatre mille caractères. Mesuré, 17,7 s pour 527 Kio. Renoncer marque la
            # substitution, ce qui refuse la cible plutôt que de la laisser passer.
            if echecs > 8:
                sortie.append(MARQUE); i += 2; continue
            j, prof, q, butoir = i + 2, 1, "", min(len(cmd), i + 2 + LIMITE_SUBSTITUTION)
            while j < butoir and prof:
                c = cmd[j]
                if q:
                    if c == "\\" and q == '"': j += 1
                    elif c == q: q = ""
                elif c in "\"'": q = c
                elif c == "(": prof += 1
                elif c == ")": prof -= 1
                j += 1
            if prof:
                # Jamais refermée. On marque, et on reprend juste après le « $( ». Avaler la
                # suite reviendrait à effacer les commandes d'après, ce qu'on vient de corriger.
                echecs += 1
                sortie.append(MARQUE); i += 2; continue
            dedans = cmd[i + 2:j - 1]
            # LE MKTEMP DOIT ÊTRE TOUTE LA SUBSTITUTION. Un simple début suffisait, donc un
            # mktemp suivi d'une seconde commande prenait le laissez-passer du temporaire. Cette
            # seconde commande pouvait nommer n'importe quel chemin. Aucun séparateur de commande
            # n'est donc toléré, et la mesure date du 2026-09-15.
            corps_tous.append(dedans)
            temporaire = re.fullmatch(r"\s*mktemp[^;&|`$()]*", dedans)
            sortie.append(" /tmp/__mktemp__/direct " if temporaire else MARQUE)
            i = j; continue
        if ch == "`":
            j, butoir = i + 1, min(len(cmd), i + 1 + LIMITE_SUBSTITUTION)
            while j < butoir and cmd[j] != "`":
                if cmd[j] == "\\": j += 1
                j += 1
            if j >= butoir:
                sortie.append(MARQUE); i += 1; continue
            corps_tous.append(cmd[i + 1:j])
            sortie.append(MARQUE); i = j + 1; continue
        sortie.append(ch); i += 1
    return "".join(sortie), corps_tous

# Ce qui, dans le corps d'un heredoc, mérite de rejoindre la commande qui le porte.
EFFACEMENT_EN_CORPS = re.compile(r"rmtree\(|\bunlink\(|os\.remove\(")
# Un `cd` en tête de commande, qui déplace ce qui suit, heredocs compris.
CD_EN_TETE = re.compile(r"(?:^|[;&|])\s*cd\s")
# LE DÉLIMITEUR PEUT COMMENCER PAR UN CHIFFRE, comme n'importe quel mot chez bash. Il était
# exigé de commencer par une lettre, donc « <<9E » n'ouvrait rien et son corps passait.
# Mesuré le 2026-09-15.
#
# Le « <<< » passe une CHAÎNE en entrée, il n'ouvre aucun corps. Sans les deux gardes autour du
# « << », le motif s'accrochait à son deuxième chevron. Tout le reste de la charge devenait
# alors un corps de heredoc jamais refermé. Mesuré le 2026-09-15.
OUVRE_HEREDOC = re.compile(r"(?<!<)<<(?!<)(?P<tiret>-?)[ \t]*\\?(?P<q>['\"]?)(?P<mot>[A-Za-z0-9_][A-Za-z0-9_.-]*)(?P=q)")

def heredocs_recolles(cmd):
    """Le corps d'un heredoc rejoint la commande qui le porte, en un seul jeton cité.

    Un heredoc, c'est le « <<MOT » qui donne à une commande un bloc de texte écrit sur les
    lignes suivantes, jusqu'à une ligne qui ne porte que MOT.

    Sans ce recollage, normaliser_lignes changeait chaque retour à la ligne du corps en « ; »,
    donc le corps devenait des commandes indépendantes. L'effacement qu'il portait n'appartenait
    plus à aucun verbe. Mesuré le 2026-09-15 : un « python3 - <<PY » suivi d'un shutil.rmtree
    passait entier.

    LA LECTURE SE FAIT LIGNE À LIGNE, ET TROIS FAUTES D'UN MOTIF L'IMPOSENT. Un motif paresseux
    sous re.DOTALL, refermé sur une référence arrière, coûte le carré de la taille. Vingt-deux
    secondes pour 235 Kio, quand le harnais tue le garde bien avant. Il échouait donc ouvert sur
    exactement les grosses charges que la lecture par fichier visait.

    Le motif ne reconnaissait qu'un mot nu. Trois formes courantes lui échappaient, le
    délimiteur échappé, celui à tiret et celui à point. Et sa boucle s'arrêtait au quatrième
    heredoc, donc quatre blocs anodins devant un « python3 - <<E » suffisaient à le cacher.

    SEULES LES LIGNES QUI PORTENT UN EFFACEMENT SONT RECOLLÉES, et c'est une question de temps.
    `shlex` lit caractère par caractère, en recopiant le jeton en cours. Un corps entier recollé
    devient UN jeton, donc son coût est le carré de sa taille. Mesuré : 5,9 s pour 500 Kio, quand
    le même texte non recollé coûte 0,37 s.

    Le corps entier n'est pas perdu pour autant. Il repart dans la file, jugé comme un texte
    ordinaire, ce qui rend au heredoc de shell le traitement qu'il avait avant ce recollage.

    Rend la commande, et les corps trouvés.

    LIMITE ASSUMÉE. Deux heredocs ouverts sur la MÊME ligne ne sont recollés que pour le
    premier. Un délimiteur jamais refermé ne l'est pas du tout, et la ligne part telle quelle.
    """
    if "<<" not in cmd:
        return cmd, []
    lignes = cmd.split("\n")
    # L'INDEX DES TERMINATEURS SE CONSTRUIT UNE FOIS, et c'est encore une histoire de temps. La
    # recherche partait de la ligne d'ouverture et descendait jusqu'au bout quand le mot n'était
    # jamais refermé. Or un « << » est aussi un opérateur, en C++ ou dans une doc, et il s'en
    # sème des dizaines. Mesuré, 10,7 s pour 286 Kio.
    exact, sans_tab = {}, {}
    for k, l in enumerate(lignes):
        exact.setdefault(l, []).append(k)
        sans_tab.setdefault(l.lstrip("\t"), []).append(k)
    sortie, corps_tous, cds, i = [], [], [], 0
    while i < len(lignes):
        ligne = lignes[i]
        m = OUVRE_HEREDOC.search(ligne)
        if not m:
            if CD_EN_TETE.search(ligne):
                cds.append(ligne)
            sortie.append(ligne); i += 1; continue
        # LE TERMINATEUR EST EXACT, comme dans le shell. Il était comparé après un strip, donc
        # une ligne INDENTÉE égale au délimiteur fermait le corps trop tôt, et ce qui suivait
        # échappait au recollage. Le « <<- » est la seule forme qui mange les tabulations de
        # tête, et lui seul les pèle. Mesuré le 2026-09-15.
        mot = m.group("mot")
        table = sans_tab if m.group("tiret") else exact
        ou = table.get(mot, ())
        k = bisect.bisect_right(ou, i)
        # UN HEREDOC SANS TERMINATEUR N'EST PAS UN NON-HEREDOC. Bash se contente d'avertir,
        # puis lit jusqu'à la fin du texte.
        #
        # Le laisser tel quel rendait le trou du heredoc entier, puisqu'il suffisait d'omettre
        # la ligne de fin. Le corps est donc tout ce qui suit, comme chez bash. Mesuré le
        # 2026-09-15.
        j = ou[k] if k < len(ou) else len(lignes)
        # LE CORPS EMPORTE LES `cd` QUI LE PRÉCÈDENT. Il repartait dans la file avec le dossier
        # de DÉPART. Un « cd sous » devant un heredoc qui efface visait le mauvais endroit.
        # Le garde y lisait « rien à perdre », mesuré le 2026-09-15.
        corps = "\n".join(lignes[i + 1:j])
        # TOUT CORPS REPART DANS LA FILE, et le tri par verbe d'effacement était une erreur.
        # Il ne connaissait que rm et ses cousins. Un « git clean -fdx » ou un
        # « find src -delete » écrit dans un heredoc disparaissait donc du jugement. C'était un
        # recul sur ce que le garde savait déjà faire, mesuré le 2026-09-15.
        #
        # LE COÛT SE BORNE AILLEURS, sur les `cd` recopiés en tête. Chaque corps les emportait
        # tous, donc le texte rejugé croissait avec leur nombre, 49 s pour 51 Kio. Seuls les
        # vingt derniers sont repris, ce qui suffit à retrouver le bon dossier.
        #
        # Le `cd` peut vivre sur la ligne d'ouverture elle-même, avant le « bash <<EOF ».
        #
        # LES `cd` NE SE TRONQUENT PLUS. Garder les vingt derniers jetait celui qui avait
        # réellement déplacé, quand des `cd .` sans effet le suivaient. Mesuré le 2026-09-15 :
        # « cd important », vingt et un « cd . », puis un heredoc qui efface, passait. Le coût
        # se borne sur le NOMBRE de corps remis en file, plus bas.
        tete = cds + ([ligne[:m.start()]] if CD_EN_TETE.search(ligne[:m.start()]) else [])
        if len(corps_tous) < 50:
            corps_tous.append("\n".join(tete + [corps]) if tete else corps)
        else:
            corps_tous.append("echo trop de heredocs pour etre juges")
        utile = [l for l in lignes[i + 1:j] if EFFACEMENT_EN_CORPS.search(l)]
        sortie.append(ligne[:m.start()] + " " + shlex.quote("\n".join(utile)) + " " + ligne[m.end():])
        i = j + 1
    return "\n".join(sortie), corps_tous


def mot_commande(toks):
    """Le verbe, en sautant affectations, préfixes et ouvertures de bloc. Rend (verbe, args)."""
    i = 0
    while i < len(toks) and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", toks[i]) or toks[i] in PREFIXES
                             or toks[i] in OUVRE_BLOC or re.match(r"^\d+[smh]?$", toks[i])):
        i += 1
    if i >= len(toks):
        return "", []
    return toks[i], toks[i + 1:]

def apres_xargs(args):
    """Le vrai verbe derrière `xargs`, ses options sautées. Rend (verbe, args) ou ("", [])."""
    j = 0
    while j < len(args) and args[j].startswith("-"):
        j += 1 + (1 if args[j] in ("-n", "-P", "-I", "-L", "-s", "-d", "--max-args") else 0)
    return (args[j], args[j + 1:]) if j < len(args) else ("", [])

def sous_commande_git(args):
    """La sous-commande, ses options globales sautées. Rend (sous, reste, dossier du `-C`).

    Le volet lisait `args[0]`. Une option globale prenait donc la place de la sous-commande, et
    `git -C . clean -fdx` sortait sans être jugé. Toutes les options globales le faisaient, et
    `-C` déplace en plus le dépôt visé. Mesuré le 2026-09-10."""
    porte_valeur = ("-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path")
    i, dossier = 0, ""
    while i < len(args) and args[i].startswith("-"):
        if args[i] == "-C" and i + 1 < len(args):
            dossier = args[i + 1]
        i += 2 if args[i] in porte_valeur else 1
    return (args[i], args[i + 1:], dossier) if i < len(args) else ("", [], dossier)

def options_git_clean(args):
    """Les options de `git clean`, séparées de ses pathspecs. Rend (lettres, longues, exclus, chemins).

    DEUX FAUTES SYMÉTRIQUES VIVAIENT DANS LA LECTURE D'AVANT, mesurées le 2026-09-15.

    « -e » porte une VALEUR, le motif à épargner. Elle était rangée dans les chemins, donc la
    simulation ne portait plus que sur elle : `git clean -fdx -e garde.txt` ne regardait que
    garde.txt, quand la vraie commande vidait tout le reste.

    Et les lettres courtes étaient prises en aplatissant le jeton entier. Une valeur collée y
    entrait lettre par lettre : `-enode_modules` apportait un « n », donc le garde y lisait un
    essai à blanc et rendait la main sans rien regarder.

    La lecture se fait donc lettre par lettre, et « e » s'arrête pour prendre sa valeur, collée
    ou dans le jeton suivant. Un « -- » clôt les options, comme pour git.
    """
    lettres, longues, exclus, chemins = "", [], [], []
    i, fin = 0, False
    while i < len(args):
        a = args[i]
        if fin or not a.startswith("-") or a == "-":
            chemins.append(a); i += 1; continue
        if a == "--":
            fin = True; i += 1; continue
        if a.startswith("--"):
            if a.startswith("--exclude="):
                exclus.append(a.split("=", 1)[1])
            elif a == "--exclude" and i + 1 < len(args):
                exclus.append(args[i + 1]); i += 1
            else:
                longues.append(a)
            i += 1; continue
        j = 1
        while j < len(a):
            if a[j] == "e":
                if a[j + 1:]:
                    exclus.append(a[j + 1:])
                elif i + 1 < len(args):
                    exclus.append(args[i + 1]); i += 1
                break
            lettres += a[j]; j += 1
        i += 1
    return lettres, longues, exclus, chemins

# Les options de checkout, switch et restore qui portent une valeur, et ce que vaut cette valeur.
COURTES_A_VALEUR = "bBcCst"
LONGUES_A_VALEUR = ("--orphan", "--start-point", "--source", "--pathspec-from-file", "--track",
                    "--create", "--force-create")

def options_git_arbre(args):
    """Les options d'un checkout, switch, restore ou reset. Rend (lettres, longues, valeurs, libres, apres).

    CE VOLET A DEMANDÉ TROIS RONDES DE REVUE, PARCE QU'IL LISAIT SES OPTIONS AU JUGÉ. Il cherchait
    des jetons entiers dans une liste, donc un groupe court lui échappait entièrement. « -fB »
    n'était ni « -f » ni « -B », donc ni un forçage ni une branche recréée.

    Et il prenait pour un chemin tout argument libre qui n'était pas une référence. Or le mot qui
    suit un `-b` est un nom de branche, et celui d'après un point de départ. Ni l'un ni l'autre
    n'est un chemin, et les interroger en pathspec rendait un statut vide, donc un laissez-passer.

    La lecture se fait donc lettre par lettre, comme pour `git clean`. Un « -- » clôt les options,
    et ce qui suit est un chemin quoi qu'il arrive.
    """
    lettres, longues, valeurs, libres, apres = "", [], {}, [], []
    i, fin = 0, False
    while i < len(args):
        a = args[i]
        if fin:
            apres.append(a); i += 1; continue
        if a == "--":
            fin = True; i += 1; continue
        if a.startswith("--"):
            nom, _, val = a.partition("=")
            if val:
                valeurs[nom] = val
            elif nom in LONGUES_A_VALEUR and i + 1 < len(args):
                valeurs[nom] = args[i + 1]; i += 1
            longues.append(nom)
            i += 1; continue
        if a.startswith("-") and len(a) > 1:
            j = 1
            while j < len(a):
                c = a[j]
                lettres += c
                if c in COURTES_A_VALEUR:
                    if a[j + 1:]:
                        valeurs[c] = a[j + 1:]
                    elif i + 1 < len(args):
                        valeurs[c] = args[i + 1]; i += 1
                    break
                j += 1
            i += 1; continue
        libres.append(a); i += 1
    return lettres, longues, valeurs, libres, apres

def est_une_reference(racine, mot):
    """Ce mot désigne-t-il une branche, une étiquette ou un commit dans ce dépôt ?

    LE TIRET SEUL EST LA BRANCHE PRÉCÉDENTE, et git l'écrit « @{-1} ». Il n'était reconnu ni
    comme une option, faute d'avoir une lettre, ni comme une référence. Il passait donc pour un
    chemin, et « git switch -f - » sortait sans être jugé. Mesuré le 2026-09-15.
    """
    mot = "@{-1}" if mot == "-" else mot
    rc, _ = git(racine, "rev-parse", "--verify", "--quiet", mot + "^{commit}")
    return rc == 0

def efface_par_exec(args):
    """Un `-exec` qui efface. Le verbe est le mot QUI SUIT `-exec`, pas un mot quelconque.

    Le test d'avant demandait « rm » n'importe où dans les arguments. Un `find -exec grep -l rm`,
    lecture pure, faisait refuser son point de départ. Un `-exec /bin/rm` lui échappait au
    contraire, faute d'être écrit court. Mesuré le 2026-09-10."""
    for i, a in enumerate(args[:-1]):
        if a not in ("-exec", "-execdir", "-ok", "-okdir"):
            continue
        verbe = os.path.basename(args[i + 1])
        if verbe in VERBES_EFFACEMENT:
            return True
        if verbe in SHELLS and any(re.search(r"\b(rm|shred|unlink|rmdir)\b", x) for x in args[i + 2:]):
            return True
    return False

# LE JUGEMENT, SEGMENT PAR SEGMENT
# --------------------------------
# La commande, puis ce que `bash -c` et `eval` portent en argument. Deux niveaux, pas plus.
a_juger = [(commande, cwd, 0)]
while a_juger:
    texte, cwd_base, profondeur = a_juger.pop(0)
    cwd_courant = cwd_base
    texte, corps_heredocs = heredocs_recolles(texte)
    for corps in corps_heredocs:
        # Le corps repart dans la file comme un texte à part entière. Un heredoc de shell porte
        # de vraies commandes, et le recollage seul les aurait enfermées dans un jeton muet.
        #
        # AU FOND DE LA PILE, IL SE REFUSE AU LIEU DE DISPARAÎTRE. Le recollage l'avait déjà
        # retiré du texte, donc plus personne ne le jugeait. Mesuré le 2026-09-15.
        if profondeur < 2:
            a_juger.append((corps, cwd_base, profondeur + 1))
        elif corps.strip():
            # AUCUN TRI PAR VERBE ICI NON PLUS. Le motif ne connaissait que rm et ses cousins.
            # Un git clean ou un find -delete écrit au fond de la pile disparaissait donc, alors
            # que le recollage l'avait déjà retiré du texte. C'est la règle du shell imbriqué
            # trop profond appliquée au heredoc, mesurée le 2026-09-15.
            refus.append(f"corps de heredoc trop profond pour être jugé : « {corps[:80]} »")
    texte, corps_subs = substitutions_marquees(texte)
    for corps in corps_subs:
        # Le corps d'une substitution est une vraie commande. Le marquage le retire du texte,
        # donc sans ce renvoi personne ne le juge plus.
        if profondeur < 2:
            a_juger.append((corps, cwd_courant, profondeur + 1))
        elif corps.strip():
            refus.append(f"corps de substitution trop profond pour être jugé : « {corps[:80]} »")
    for toks, sep in segments_de(sans_redirections(texte)):
        seg = " ".join(toks)
        verbe, args = mot_commande(toks)
        if not verbe:
            continue

        # Le lieu. `cd` déplace tout ce qui suit ; sans lui, un homonyme était jugé.
        if verbe == "cd":
            dest = next((a for a in args if not a.startswith("-")), None)
            if dest is None:
                cwd_courant = os.path.expanduser("~")
            else:
                try:
                    cwd_courant = os.path.normpath(os.path.join(cwd_courant or "/", resoudre(dest)))
                except KeyError:
                    cwd_courant = None
            continue

        # Un shell imbriqué porte sa commande en argument. On la juge, elle aussi.
        interne = ""
        if verbe in SHELLS and "-c" in args:
            k = args.index("-c")
            interne = args[k + 1] if k + 1 < len(args) else ""
        elif verbe == "eval":
            interne = " ".join(args)
        if interne:
            if profondeur < 2:
                a_juger.append((interne, cwd_courant, profondeur + 1))
            else:
                refus.append(f"shell imbriqué trop profond pour être jugé : « {seg[:80]} »")
            continue

        # Le verbe. Il pouvait se cacher derrière `xargs`, qui reçoit ses chemins par un tube.
        par_tube = False
        if verbe == "xargs":
            verbe, args = apres_xargs(args)
            par_tube = True
            if not verbe:
                continue

        cibles = []
        if verbe in VERBES_EFFACEMENT:
            cibles = [a for a in args if not a.startswith("-")]
            if par_tube and not cibles:
                refus.append(f"« {seg} » efface des chemins lus sur l'entrée standard, que le garde "
                             f"ne peut pas voir. Une perte sèche ne se décide pas à l'aveugle")
                continue
        elif verbe == "find" and ("-delete" in args or efface_par_exec(args)):
            # Les points de départ sont les arguments AVANT la première option.
            cibles = []
            for a in args:
                if a.startswith("-") or a in ("(", "!"): break
                cibles.append(a)
            cibles = cibles or ["."]
            filtres = [args[i + 1] for i, a in enumerate(args[:-1]) if a in ("-name", "-iname", "-path")]
            if filtres and all(f.strip("*/") in JETABLE_DOSSIERS or f.endswith(JETABLE_SUFFIXES) for f in filtres):
                cibles = []
        elif verbe in ("python", "python3") and re.search(r"rmtree\(|\bunlink\(|os\.remove\(", seg):
            cibles = re.findall(r"(?:rmtree|unlink|remove)\(\s*['\"]([^'\"]+)['\"]", seg)
            # Le danger était reconnu, puis abandonné en silence dès que la cible n'était pas une
            # chaîne littérale collée à l'appel. Une variable ou un Path() passaient.
            #
            # LE HEREDOC, LUI, N'ARRIVAIT MÊME PAS JUSQU'ICI. Cette ligne l'a pourtant affirmé
            # couvert du 2026-09-10 au 2026-09-15. Son corps était découpé en commandes
            # indépendantes par le retour à la ligne, donc aucun verbe ne le portait plus.
            # C'est heredocs_recolles qui le rend à sa commande, et cette ligne est vraie depuis.
            if not cibles:
                refus.append(f"« {seg[:80]} » efface par Python une cible que le garde ne sait pas "
                             f"lire. Elle n'est pas écrite en clair dans la commande")
                continue
        elif verbe == "git":
            sous, args, dossier = sous_commande_git(args)
            racine = os.path.normpath(os.path.join(cwd_courant or cwd, dossier)) if dossier else (cwd_courant or cwd)
            args = [sous] + args  # le reste du volet lit args[0] comme la sous-commande
            if sous == "clean":
                lettres, longues, exclus, chemins = options_git_clean(args[1:])
                # Une simulation n'efface rien, et la refuser était un faux positif. Le test du
                # non développé passait AVANT celui-ci. Un essai à blanc sur une accolade était
                # donc refusé, alors qu'il ne touche à rien. Mesuré le 2026-09-15.
                if "n" in lettres or "--dry-run" in longues:
                    continue
                opaques = [c for c in chemins if non_developpe(c)]
                if opaques:
                    refus.append(f"git clean vise « {opaques[0]} », que le garde ne développe pas. "
                                 f"Il ne peut pas dire ce qui partirait"); continue
                # Les options tapées décident de la portée. En dur, `-nd` ignorait `-x`, donc
                # tout ce que .gitignore couvre : dans le projet de l'incident, .env et data/.
                portee = []
                if "d" in lettres or "--directory" in longues: portee.append("-d")
                if "x" in lettres or "-x" in longues: portee.append("-x")
                if "X" in lettres or "-X" in longues: portee.append("-X")
                for ex in exclus:
                    portee += ["-e", ex]
                rc, sortie = git(racine, "clean", "-n", *portee, "--", *chemins)
                perdus = [l[len("Would remove "):] for l in sortie.splitlines() if l.startswith("Would remove ")]
                perdus = [p for p in perdus if not est_jetable(Path(racine, p), temp_vars)]
                if perdus: refus.append(f"git clean jetterait {len(perdus)} chemin(s) non suivi(s) : {', '.join(perdus[:5])}")
                continue
            if sous in ("checkout", "restore", "switch") or (sous == "reset" and "--hard" in args):
                # `git restore --staged` ne touche pas l'arbre de travail. Le refuser était un faux positif.
                if sous == "restore" and "--staged" in args and "--worktree" not in args and "-W" not in args:
                    continue
                lettres, longues, valeurs, libres, apres_tirets = options_git_arbre(args[1:])
                force = "f" in lettres or "--force" in longues or "--discard-changes" in longues
                recree = valeurs.get("B") or valeurs.get("C") or valeurs.get("--force-create")
                cree = (valeurs.get("b") or valeurs.get("c") or valeurs.get("--create")
                        or valeurs.get("--orphan"))

                # UNE BRANCHE RECRÉÉE PERD CE QU'ELLE PORTAIT SEULE. `-B` et `-C` la refont sur un
                # autre point de départ, sans porter aucun drapeau de forçage, et l'arbre de
                # travail peut être propre. Les commits partent alors sans bruit.
                if recree and est_une_reference(racine, recree):
                    # LE TIRET SE NORMALISE ICI AUSSI, et le code de retour se lit. « rev-list
                    # -..HEAD » sort en erreur avec une sortie vide, que le compte lisait comme
                    # « zéro commit perdu ». Mesuré le 2026-09-15.
                    depart = libres[0] if libres else "HEAD"
                    depart = "@{-1}" if depart == "-" else depart
                    rc, perdus = git(racine, "rev-list", f"{depart}..{recree}", "--not", "--remotes")
                    n = len([x for x in perdus.split() if x])
                    if rc:
                        refus.append(f"git {sous} sur la branche {recree} : le garde n'a pas su "
                                     f"compter ce qui partirait depuis « {depart} »")
                    elif n:
                        refus.append(f"git {sous} sur la branche {recree} : {n} commit(s) qu'aucun "
                                     f"distant ne porte seraient abandonnés")

                # CE QUI EST UN CHEMIN, ET CE QUI N'EN EST PAS. Un argument libre qui suit un
                # `-b`, `-B`, `-c` ou `-C` est le point de DÉPART de la branche, jamais un chemin.
                #
                # Une référence n'en est pas un non plus. Ce qui suit un « -- » en est toujours un.
                # Le tiret seul est TOUJOURS la branche précédente, jamais un chemin, même
                # quand le dépôt n'en a pas encore et que `@{-1}` ne résout rien.
                ref = next((a for a in libres if a == "-" or est_une_reference(racine, a)), None)
                if apres_tirets:
                    chemins = apres_tirets
                elif cree or recree or sous == "reset":
                    # UN `reset --hard` N'A PAS DE CHEMIN, son argument est un point de départ.
                    # Le prendre pour un pathspec rendait un statut vide, donc un laissez-passer,
                    # sur toute forme que `rev-parse --verify` refuse, comme « :/init ». Tout
                    # l'arbre est donc jugé. Mesuré le 2026-09-15.
                    chemins = []
                else:
                    chemins = [a for a in libres if a != ref]
                # LES CHEMINS PEUVENT VENIR D'UN FICHIER, que le garde ne lit pas. La liste
                # restait vide, donc le laissez-passer du changement de branche s'appliquait, et
                # git écrasait bel et bien les chemins nommés. Mesuré le 2026-09-15. On juge
                # alors tout l'arbre, faute de savoir ce qui est visé.
                depuis_fichier = "--pathspec-from-file" in valeurs or "--pathspec-from-file" in longues

                # UN CHANGEMENT DE BRANCHE ORDINAIRE NE PERD RIEN. Git refuse lui-même d'écraser
                # une modification locale, et rend la main sans rien toucher. Le refuser faisait
                # partir au refus tout `git checkout <branche>` sur un arbre sale.
                #
                # TROIS CONDITIONS, ET IL A FALLU TROIS RONDES POUR LES TENIR TOUTES. Pas de
                # forçage, qui lui écrase. Pas de chemin, qui lui est écrasé sans que git ne
                # s'y oppose. Et `git restore`, qui jette une modification sans drapeau, n'y a
                # jamais droit.
                if sous in ("checkout", "switch") and not force and not chemins and not depuis_fichier:
                    continue

                opaques = [c for c in chemins if non_developpe(c)]
                if opaques:
                    refus.append(f"git {sous} vise « {opaques[0]} », que le garde ne développe pas. "
                                 f"Il ne peut pas dire ce qui partirait"); continue
                rc, sortie = git(racine, "status", "--porcelain", "--", *chemins)
                modifies = [l for l in sortie.splitlines() if not l.startswith("??")]
                if modifies: refus.append(f"git {sous} effacerait {len(modifies)} modification(s) non commitée(s) : {', '.join(m.strip() for m in modifies[:5])}")
                # Un arbre propre ne suffit pas. Reculer HEAD jette les commits qui le suivent, et
                # un `reset --hard` sur un arbre propre passait donc pour inoffensif.
                if sous == "reset" and ref:
                    depart = "@{-1}" if ref == "-" else ref
                    rc, perdus = git(racine, "rev-list", f"{depart}..HEAD", "--not", "--remotes")
                    n = len([x for x in perdus.split() if x])
                    if rc:
                        refus.append(f"git reset --hard : le garde n'a pas su compter ce qui "
                                     f"partirait depuis « {ref} »")
                    elif n:
                        refus.append(f"git reset --hard jetterait {n} commit(s) qu'aucun distant ne porte")
                continue
            if sous == "rm" and "--cached" not in args:
                cibles = [a for a in args[1:] if not a.startswith("-")]
            elif sous == "stash" and args[1:2] and args[1] in ("drop", "clear"):
                refus.append("git stash " + args[1] + " jette du travail mis de côté, que rien ne rend"); continue
            elif sous == "branch" and ("-D" in args or ("--delete" in args and "--force" in args)):
                noms = [a for a in args[1:] if not a.startswith("-")]
                rc, nm = git(racine, "branch", "--no-merged")
                non_fusionnees = {b.strip("* ").strip() for b in nm.splitlines()}
                for n in noms:
                    if n in non_fusionnees: refus.append(f"git branch -D {n} : branche non fusionnée, ses commits seraient perdus")
                continue
            elif sous == "push" and any(a in ("--force", "-f", "--force-with-lease") for a in args):
                refus.append("git push forcé : réécrit l'historique distant, ce que rien ne rend"); continue
            # Le forçage n'était reconnu qu'au drapeau. Un refspec en « + » force autant, et
            # `--delete` retire une branche du distant. Les deux passaient. 2026-09-10.
            elif sous == "push" and any(a.startswith("+") for a in args[1:]):
                refus.append("git push d'un refspec en « + » : forçage écrit autrement, même perte"); continue
            elif sous == "push" and any(a in ("--delete", "-d") for a in args):
                refus.append("git push --delete retire une branche du distant, que rien ne rend"); continue
            elif sous == "worktree" and args[1:2] == ["remove"] and "--force" in args:
                refus.append("git worktree remove --force : jette un arbre de travail modifié"); continue
            else:
                continue
        else:
            continue

        for c in cibles:
            # LE GARDE NE MEURT PLUS SUR UNE CIBLE, IL LA REFUSE. Une exception imprévue tuait
            # le processus entier, donc la charge PASSAIT. Ses autres commandes avec elle, et un
            # `os.path.join(None, …)` suffisait.
            #
            # Sortir en zéro reste la règle quand le garde plante. Sinon il bloquerait l'outil
            # qu'il surveille, donc toute la session.
            #
            # Mais une cible que le garde n'a pas su juger n'est pas sans danger. Son régime est
            # celui que l'en-tête annonce déjà : ce qu'on ne sait pas résoudre est refusé, et
            # dit. Le filet est posé PAR CIBLE, jamais sur tout le tour. Mesuré le 2026-09-15.
            try:
                try:
                    brut = resoudre(c)
                except KeyError as e:
                    refus.append(f"chemin non résolu, variable inconnue ${e.args[0]} dans « {c} »"); continue
                # CE QUE LE SHELL AURAIT DÉVELOPPÉ, ET QUE LE GARDE NE DÉVELOPPE PAS. Accolades,
                # substitution de commande, marque de remplacement de xargs. Ces cibles étaient
                # jugées TELLES QUELLES, donc introuvables sur le disque. Elles tombaient alors
                # dans « rien à perdre », et passaient.
                #
                # Mesuré le 2026-09-15 sur trois formes. « rm -rf {important,data} », « rm
                # $(find …) » et « xargs -I{} rm -rf {} ». La substitution arrive ici sous la
                # marque que substitutions_marquees lui a posée.
                #
                # LE PARTAGE SE FAIT ICI, ET IL EST VOULU DANS CE SENS. Une cible que le garde a
                # su LIRE et qui n'existe pas reste un laissez-passer. Effacer ce qui n'est plus
                # là ne perd rien, et refuser un `rm -f` de nettoyage gênerait sans protéger.
                #
                # Une cible qu'il n'a pas su DÉVELOPPER est l'inverse. Elle peut désigner tout
                # l'arbre, et le garde n'a rien à montrer à l'admin. Elle est donc refusée.
                if SUBSTITUTION in brut or re.search(r"[{}]|\$\(|`", brut):
                    refus.append(f"« {c} » n'est pas développé par le garde, accolades, substitution "
                                 f"de commande ou marque de xargs. Il ne peut pas dire ce qui partirait"); continue
                if os.path.isabs(brut):
                    # Une cible absolue se passe du dossier courant, et c'est ce qui manquait.
                    # La jointure avec un `cd` non résolu levait TypeError, et tuait le garde.
                    abs_ = os.path.normpath(brut)
                elif cwd_courant is None:
                    refus.append(f"« {c} » est relatif, et un `cd` a mené dans un dossier que le garde "
                                 f"ne sait pas nommer. Il ne peut pas dire ce qui partirait"); continue
                else:
                    abs_ = os.path.normpath(os.path.join(cwd_courant, brut))
                if any(abs_.startswith(t.rstrip("/")) for t in temp_vars) or "/tmp/__mktemp__/" in abs_:
                    continue
                # LE RACCOURCI SUR LE PRÉFIXE « /tmp/ » SUIT MAINTENANT LES LIENS. Il comparait
                # le TEXTE du chemin, donc un lien posé sous /tmp faisait passer la destruction
                # de ce qu'il visait ailleurs. Mesuré le 2026-09-15.
                #
                # IL RESTE EN AMONT DU GLOB, ET C'EST VOULU. est_jetable ne juge qu'un chemin qui
                # existe, or un motif temporaire qui ne correspond à rien est une cible ordinaire
                # d'un nettoyage. Le retirer faisait refuser « rm -rf /tmp/build-* » à vide.
                if sous_racine_temporaire(abs_):
                    continue
                cand = glob.glob(abs_) if any(ch in abs_ for ch in "*?[") else [abs_]
                if not cand:
                    refus.append(f"chemin non résolu, aucun fichier ne correspond à « {c} »"); continue
                for ch in cand:
                    p = Path(ch)
                    if not p.exists():
                        continue  # rien à perdre
                    if ne_perd_rien(p):
                        continue
                    if est_jetable(p, temp_vars) or est_rendu_par_git(p):
                        continue
                    refus.append(f"« {c} » serait une perte sèche, {inventaire([p])}")
            except Exception:
                refus.append(f"« {c} » n'a pas pu être jugé par le garde. Une cible qu'il ne sait "
                             f"pas lire ne se distingue pas d'une cible dangereuse")

# LE VERDICT RENDU AU HARNAIS
# ---------------------------
if refus:
    vus, uniques = set(), []
    for r in refus:
        if r not in vus:
            vus.add(r); uniques.append(r)
    motif = " | ".join(uniques)[:900]
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
        "permissionDecisionReason": "Effacement refuse, le garde ne voit rien qui rende ce qui part : " + motif
        + ". Ni jetable (temporaire ou regenerable), ni suivi par git sans modification. "
          "Une perte seche se fait de la main de l admin, pas de celle de l agent. Voir scripts/garde-perte-seche.sh."}}))
PY
exit 0
