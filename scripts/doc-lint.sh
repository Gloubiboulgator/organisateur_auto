#!/usr/bin/env bash
# doc-lint — garde-fou anti-dérive de la documentation. NOYAU PARTAGÉ.
#
# Rejoue une batterie de contrôles. CHAQUE contrôle DOIT revenir vide. Sort en erreur dès qu'un
# contrôle remonte quelque chose, pour servir de hook pre-commit ou de vérification manuelle.
#
# CE FICHIER APPARTIENT AU NOYAU. Un projet ne le modifie jamais. Ses contrôles à lui vivent
# dans scripts/doc-lint-local.sh, exécuté à la fin, avec des numéros préfixés par L. Une
# collision de numéros devient ainsi impossible, et la mise à jour du noyau ne touche à rien.
#
# Référence des règles : docs/systeme-documentaire.md, section Référence canonique.
#
# Usage :  bash scripts/doc-lint.sh
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
# Le corpus vient de scripts/corpus.py, qui porte le pourquoi du séparateur zéro et des octets.
# Un chemin À ESPACE resterait mal découpé ici, limite connue.
# UN CORPUS INCONNU N'EST PAS UN CORPUS VIDE. Le repli sur un glob a été retiré. Quand git
# échoue, la liste devenait vide ou partielle, les boucles ne tournaient sur rien, et les
# contrôles imprimaient ✅ sans avoir rien lu. Seize verts sur dix-sept dans un dossier sans
# dépôt git, mesuré. Le lint refuse maintenant de rendre un verdict qu'il ne peut pas fonder.
# LA SORTIE D'ERREUR SE CAPTURE À PART. Fondue dans la liste, le moindre avertissement de git
# — un dossier illisible, un attribut mal formé — devenait un faux nom de fichier que les
# contrôles suivants passaient à grep, qui l'avalait en silence et rendait vert.
_err=$(mktemp)
if ! DOCS=$(python3 scripts/corpus.py '*.md' 2>"$_err" | tr '\0' '\n'); then
  printf '\n\033[1;31m❌ doc-lint : le corpus est inconnu, scripts/corpus.py a échoué.\033[0m\n' >&2
  sed 's/^/   /' "$_err" >&2
  rm -f "$_err"
  printf '   Aucun verdict ne peut être rendu sans la liste des fichiers suivis.\n' >&2
  exit 1
fi
rm -f "$_err"
REGLES=docs/systeme-documentaire.md   # les règles de rédaction, propriétaire
GARDES=docs/garde-fous.md             # le registre des garde-fous
TERRAIN=docs/observations-terrain.md  # le registre des croyances sur le monde extérieur
ROAD=specs/roadmap-developpement.md   # le plan, s'il existe

# LES DEUX DETTES, et pourquoi il en faut deux. Celle du noyau porte les dispenses du noyau,
# et elle est figée. Celle du projet porte les fichiers qu'il avait écrits AVANT d'adopter le
# noyau. Sans la seconde, un dépôt existant serait bloqué dès l'installation, puisqu'il ne peut
# pas modifier la première.
export DETTES_DOC="scripts/dette-doc.txt:scripts/dette-doc-local.txt"
export DETTES_CODE="scripts/dette-code.txt:scripts/dette-code-local.txt"
BACK=specs/roadmap-backlog.md         # le registre des items, s'il existe

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
# check <libellé> <sortie> : appelé SANS pipe, pour que `fail` se propage.
check() {
  if [ -n "$2" ]; then printf '  ❌ %s\n' "$1"; printf '%s\n' "$2" | sed 's/^/      /'; fail=1
  else printf '  ✅ %s\n' "$1"; fi
}
# garde_plante <code> <sortie> : un contrôle qui PLANTE doit crier, pas se taire. Sans lui, un
# heredoc python qui lève écrit sa trace sur la sortie d'erreur, la capture reste vide, et
# check() compte vert pour toujours.
garde_plante() {
  if [ "$1" -ne 0 ]; then printf 'CONTRÔLE PLANTÉ (code %s) : %s' "$1" "${2:-aucune sortie}"
  else printf '%s' "$2"; fi
}



# 1) Liens internes : deux formes, toutes deux vérifiées (élargi).
#    (a) chemin depuis la racine cité en clair — specs/x.md, docs/pile/x.md. L'ancienne regex
#        s'arrêtait à UN segment : un lien cassé vers docs/comprendre/x.md passait inaperçu.
#    (b) lien markdown RELATIF — [texte](../glossaire.md) — résolu depuis le dossier du fichier.
#        Sans lui, tout le maillage glossaire ↔ fiches techniques n'était couvert par rien.
#    CHANGELOG et archives sont EXCLUS : instantanés datés, append-only, ils citent des fichiers
#    d'alors (même exclusion aux contrôles 5 et 7, et au 6 pour le seul CHANGELOG).
#    Les BLOCS DE CODE sont retirés avant la lecture. Un lien qui y vit ne pointe nulle part, il
#    montre une forme. Sans ce retrait, un fichier ne pouvait pas documenter un format de lien
#    sans se faire refuser par ce contrôle. La découpe vit dans scripts/blocs_markdown.py, qui
#    la possède, pour que trois contrôles ne répondent pas trois choses au même fichier.
section "1. Liens internes (cibles existantes)"
out=$(python3 - 2>&1 <<'PY'
import importlib.util, os, re, subprocess
spec = importlib.util.spec_from_file_location("bm", "scripts/blocs_markdown.py")
bm = importlib.util.module_from_spec(spec); spec.loader.exec_module(bm)
import importlib.util as _iu
_s = _iu.spec_from_file_location('corpus', 'scripts/corpus.py')
_c = _iu.module_from_spec(_s); _s.loader.exec_module(_c)
docs = [f for f in _c.fichiers('*.md')
        if f != 'CHANGELOG.md' and not f.startswith('docs/archives/')]
RACINE = re.compile(r'\b(?:specs|docs)/(?:[a-z0-9-]+/)*[a-z0-9-]+\.md')
RELATIF = re.compile(r'\]\(([^)#\s]+\.md)(?:#[^)\s]*)?\)')
illisibles = []
for f in docs:
    # NOMMER LE FICHIER, PAS MOURIR DESSUS. Un .md enregistré dans un autre encodage faisait
    # remonter une trace Python, où le nom du fautif se cherche à la main. La garde du
    # contrôle 3 existait déjà, elle manquait ici.
    try:
        brut = open(f, encoding='utf-8').read()
    except (UnicodeDecodeError, OSError) as e:
        illisibles.append(f"{f} : illisible en UTF-8 ({type(e).__name__})")
        continue
    txt = bm.hors_code(brut)
    cibles = {t: t for t in RACINE.findall(txt)}
    for lien in RELATIF.findall(txt):
        if lien.startswith(('http://', 'https://', '/')):
            continue
        cibles[lien] = os.path.normpath(os.path.join(os.path.dirname(f), lien))
    for cite, chemin in sorted(cibles.items()):
        if not os.path.isfile(chemin):
            print(f"{f} -> {cite} (INEXISTANT)")
for ligne in illisibles:
    print(ligne)
PY
)
out=$(garde_plante $? "$out")
check "aucun lien interne cassé" "$out"


# 2) Anonymat : aucun prénom, dans AUCUN fichier suivi.
#    La règle vise la doc, les specs, les commentaires ET les données de test. Le contrôle ne
#    lisait que les .md, donc il ne couvrait ni le code ni les jeux d'essai, alors que la table
#    du système documentaire promet « nulle part ». Il lit maintenant tout ce que git suit, en
#    sautant les binaires.
#    Les prénoms vivent dans scripts/prenoms-interdits.txt, seul fichier exclu du balayage. La
#    liste du noyau est figée. Un projet AJOUTE les siens dans le fichier -local.
section "2. Anonymat (aucun prénom)"
LISTE=scripts/prenoms-interdits.txt
if [ ! -f "$LISTE" ]; then
  printf '  \342\204\271\357\270\217  %s absent — le contrôle est sans objet\n' "$LISTE"
else
  motif=$(cat "$LISTE" scripts/prenoms-interdits-local.txt 2>/dev/null \
          | grep -vE '^\s*(#|$)' | tr -d ' \t' | paste -sd'|' -)
  # UN MOTIF VIDE N'EST PAS UN MOTIF. Une liste réduite à ses commentaires donnait « \b()\b »,
  # qui selon la variante de grep attrape TOUTES les lignes du dépôt, ou sort en erreur avec un
  # message avalé — et le contrôle imprimait alors ✅ sans avoir rien cherché.
  if [ -z "$motif" ]; then
    # On INFORME, on ne bloque pas. Passer ce texte à check() rendait le contrôle rouge tout en
    # annonçant qu'il était sans objet, et bloquait donc tout commit. La branche voisine, un
    # fichier absent, informe sans bloquer : les deux états équivalents se traitent pareil.
    printf '  \342\204\271\357\270\217  %s ne contient aucun prénom — contrôle sans objet\n' "$LISTE"
  else
  # -H : sans lui, un dernier lot d'un seul fichier fait tomber le préfixe, et la ligne fautive
  # s'imprime sans dire dans quel fichier elle vit.
  # LE SEUL CONTRÔLE DU FICHIER QUI N'AVAIT PAS SON GARDE. Sans lui, un grep sans « -z », un
  # xargs qui sort en 123 ou 127, et la sortie reste vide : le contrôle imprimait ✅ sans avoir
  # rien lu. C'est exactement le défaut que le reste de ce fichier vient de perdre.
  # -d skip : le corpus liste aussi les GITLINKS, un par sous-module. grep reçoit alors
  # un DOSSIER, et écrit « grep: vendor: Is a directory » sur sa sortie d'erreur.
  # ET LA SORTIE D'ERREUR NE SE MÊLE PLUS AU RÉSULTAT. Le « 2>&1 » versait ce message dans la
  # valeur que check() juge : le contrôle passait au rouge en annonçant « aucun prénom » et en
  # citant une ligne qui n'en porte aucun. Un dépôt avec un seul sous-module voyait TOUS ses
  # commits refusés. Même chemin pour un fichier suivi mais effacé du disque.
  # Le garde de la ligne suivante ne disparaît pas pour autant : une sortie d'erreur non vide
  # reste une panne, et se dit comme telle plutôt que de passer pour un prénom.
  err=$(mktemp)
  out=$(python3 scripts/corpus.py \
        | grep -zvE "^scripts/prenoms-interdits(-local)?\.txt$" \
        | xargs -0r grep -d skip -nHiIE "\b($motif)\b" 2>"$err")
  etat=$?
  bruit=$(cat "$err"); rm -f "$err"
  # LES TROIS ÉTATS NOMINAUX. grep rend 1 quand il ne trouve rien, ce qui est le cas normal ici,
  # et xargs traduit ce 1 en 123 quand il découpe la liste en plusieurs lots. Tout le reste est
  # une panne : 126 et 127 pour un binaire absent ou non exécutable, 124 pour un enfant tué.
  #
  # LIMITE ASSUMÉE : un grep qui échoue VRAIMENT rend aussi 123 à travers xargs, et se confond
  # donc avec le cas normal. Distinguer les deux demanderait de sortir de xargs.
  case "$etat" in 0|1|123) etat=0 ;; esac
  if [ "$etat" -eq 0 ] && [ -n "$bruit" ]; then
    etat=1; out="la recherche a écrit sur sa sortie d'erreur : $bruit"
  fi
  out=$(garde_plante "$etat" "$out")
  check "aucun prénom, dans aucun fichier suivi" "$out"
  fi
fi


# 3) Blocs synchronisés — le blindage contre la dérive de contenu DUPLIQUÉ.
#    Tout contenu présent à l'identique dans plusieurs docs s'entoure de
#      <!-- sync:clé -->  …  <!-- /sync:clé -->
#    Le lint extrait, pour chaque clé, le contenu dans CHAQUE fichier SUIVI et échoue
#    s'ils diffèrent (ou si une balise est orpheline). → impossible de committer
#    deux copies divergentes. (Les balises sont des commentaires HTML, invisibles
#    au rendu Markdown.)
section "3. Blocs synchronisés (contenu dupliqué identique)"
out=$(python3 - 2>&1 <<'PY'
import re, glob, collections
op = re.compile(r'<!--\s*sync:([a-z0-9-]+)\s*-->')
cl = re.compile(r'<!--\s*/sync:([a-z0-9-]+)\s*-->')
blocks = collections.defaultdict(list)   # clé -> [(fichier, contenu normalisé)]
errs = []
# Élargi : TOUT fichier suivi, pas seulement les .md. L'étalon de rédaction est
# partagé avec un prompt en .txt, et une copie invisible du contrôle est une copie libre.
import subprocess
import importlib.util as _iu
_s = _iu.spec_from_file_location('corpus', 'scripts/corpus.py')
_c = _iu.module_from_spec(_s); _s.loader.exec_module(_c)
suivis = _c.fichiers()
for f in sorted(suivis):
    try:
        open(f, encoding='utf-8').read()
    except (UnicodeDecodeError, OSError, IsADirectoryError):
        continue          # binaire ou illisible : aucun bloc sync n'y vit
    cur, buf, fence = None, [], False
    for ln in open(f, encoding='utf-8'):
        if ln.lstrip().startswith('```'):   # bloc de code : marqueurs = exemples de syntaxe, ignorés
            fence = not fence
            if cur is not None: buf.append(ln)
            continue
        if fence:
            if cur is not None: buf.append(ln)
            continue
        mo, mc = op.search(ln), cl.search(ln)
        if mo:
            if cur: errs.append(f"{f}: sync:{cur} non fermé avant sync:{mo.group(1)}")
            cur, buf = mo.group(1), []
        elif mc:
            if cur is None: errs.append(f"{f}: </sync:{mc.group(1)}> sans ouverture")
            elif mc.group(1) != cur: errs.append(f"{f}: </sync:{mc.group(1)}> ferme sync:{cur}")
            else: blocks[cur].append((f, "".join(buf).strip()))
            cur, buf = None, []
        elif cur is not None:
            buf.append(ln)
    if cur: errs.append(f"{f}: sync:{cur} non fermé (fin de fichier)")
for key, lst in blocks.items():
    if len({c for _, c in lst}) > 1:
        errs.append(f"sync:{key} DIFFÈRE entre : " + ", ".join(f for f, _ in lst))
    # Une balise sync n'a de sens qu'à PARTIR de deux copies : elle dit « ce texte est dupliqué
    # ailleurs, gardez-les identiques ». Réduite à une seule, elle ne compare plus rien et le
    # contrôle passait au vert — c'est exactement ce qu'on voit quand une copie sœur a été
    # supprimée sans retirer la balise (audit).
    elif len(lst) == 1:
        errs.append(f"sync:{key} n'a plus qu'UNE copie ({lst[0][0]}) — copie sœur supprimée sans "
                    "retirer la balise, ou balise posée sans sa jumelle")
for e in errs: print(e)
PY
)
out=$(garde_plante $? "$out")
check "tout bloc sync:<clé> est identique dans tous les docs" "$out"


# 4) Hygiène du CHANGELOG : sections datées AAAA-MM-JJ, du plus récent au plus ancien.
#     Ne vérifie QUE le format (le lint ne peut pas deviner une entrée oubliée — ça, c'est la
#     discipline ; cf. $REGLES § Alimenter le CHANGELOG).
section "4. Format du CHANGELOG (dates valides, ordre décroissant)"
if [ ! -f CHANGELOG.md ]; then
  printf '  ℹ️  pas de CHANGELOG.md dans ce projet — contrôle sans objet\n'
else
out=$(python3 - 2>&1 <<'PY'
import re, datetime
f = 'CHANGELOG.md'
errs, dated, headers = [], [], []
for i, ln in enumerate(open(f, encoding='utf-8'), 1):
    m = re.match(r'^##\s+(.*?)\s*$', ln)
    if not m:
        continue
    dm = re.match(r'(\d{4}-\d{2}-\d{2})\b', m.group(1))   # date EN TÊTE (plage « → … » tolérée)
    if dm:
        try:
            dated.append((i, datetime.date.fromisoformat(dm.group(1)))); headers.append((i, True))
        except ValueError:
            errs.append(f"{f}:{i} date invalide : {dm.group(1)}"); headers.append((i, False))
    else:
        headers.append((i, False))   # section spéciale tolérée si EN BAS (ex. « Fondations »)
# UN CHANGELOG SANS AUCUNE SECTION DATÉE N'EST PAS UN CHANGELOG VALIDE. Sans cette ligne, la
# liste des datées restait vide, aucune comparaison d'ordre n'avait lieu, et le contrôle
# imprimait ✅ sans avoir rien vérifié.
# « headers and » est délibéré, et une revue a proposé de le retirer. REFUSÉ, mesuré : un journal
# SANS AUCUNE section est l'état normal d'un projet neuf, et le rendre rouge refuserait son tout
# premier commit. Le défaut visé est un journal qui a des sections dont aucune n'est datée.
if headers and not dated:
    errs.append(f"{f} : aucune section datée, en-tête attendu « ## AAAA-MM-JJ … »")
last_dated = max((i for i, d in headers if d), default=0)
for i, is_d in headers:
    if not is_d and i < last_dated:
        errs.append(f"{f}:{i} section non datée AVANT une section datée (dates AAAA-MM-JJ d'abord)")
for (i1, d1), (i2, d2) in zip(dated, dated[1:]):
    if d2 > d1:
        errs.append(f"{f}:{i2} {d2} listé après {d1} (le plus récent doit être en haut)")
for e in errs: print(e)
PY
)
out=$(garde_plante $? "$out")
check "CHANGELOG : sections datées, du plus récent au plus ancien" "$out"
fi


# 5) Branches citées : toute branche mentionnée doit EXISTER (locale ou distante), sauf mention
#     explicitement marquée comme passée (parquée, supprimée, historique…). Depuis la règle Git du
#     dépôt, les branches de travail sont JETABLES (supprimées au merge) : la doc ne doit donc
#     PAS les nommer, et ce contrôle est ce qui le rend visible — d'où `claude/…` en plus de
#     `feature/…` (l'ancien préfixe, encore cité dans des docs antérieurs).
#     Exclus : CHANGELOG et docs/archives/ — instantanés datés, ils reflètent ce qu'on savait ce
#     jour-là ; l'archive cite en outre des CHEMINS (`~/.claude/projects`) que ce grep prendrait
#     pour des noms de branches.
#     L'extraction se fait en PYTHON, pas en grep, depuis le 2026-08-29. Un CHEMIN n'est pas une
#     branche : `.claude/settings.json` porte `claude/settings`, et un grep ne sait pas les
#     distinguer. Le commentaire ci-dessus notait déjà le cas pour `~/.claude/projects`, réglé
#     alors en excluant les archives ; le dépôt documente désormais `.claude/settings.json` en
#     prose vivante, et l'exclusion ne suffit plus. C'est le caractère qui PRÉCÈDE qui tranche,
#     par un lookbehind — donc au niveau de l'OCCURRENCE. Une exemption testée sur la ligne
#     entière aurait couvert plus large que le cas qu'elle cite, ce que `/code-review` a relevé
#     le jour même, et ce que l'angle `global-gardes-affaiblis` traque.
section "5. Branches citées (existantes ou marquées)"
out=$(python3 - 2>&1 <<'PY13'
import pathlib, re, subprocess

sortie = subprocess.run(["git", "branch", "-a", "--format=%(refname:short)"],
                        capture_output=True, text=True).stdout
connues = {b.strip().removeprefix("origin/") for b in sortie.splitlines() if b.strip()}

# (?<![.\w]) : ni un point (donc un chemin), ni un mot collé devant.
MOTIF = re.compile(r"(?<![.\w])(?:feature|claude)/[a-z0-9][a-z0-9-]*")
PASSEE = re.compile(r"parqu|supprim|superseded|historique|ancienne|ex-branche|jamais|archiv",
                    re.I)
# Instantanés datés : ils reflètent ce qu'on savait ce jour-là.
EXCLUS = ("CHANGELOG.md", "docs/archives/")

import importlib.util as _iu
_s = _iu.spec_from_file_location('corpus', 'scripts/corpus.py')
_c = _iu.module_from_spec(_s); _s.loader.exec_module(_c)
for rel in _c.fichiers("*.md"):
    if rel.startswith(EXCLUS):
        continue
    # UN SEUL HANDLER. L'ancien sautait le fichier EN SILENCE, le neuf le NOMME et rougit. Les
    # garder tous les deux rendait l'ancien inatteignable et cachait ce changement de régime.
    try:
        lignes = pathlib.Path(rel).read_text(encoding="utf-8").splitlines()
    except (UnicodeDecodeError, OSError) as e:
        print(f"{rel} : illisible, les branches citées n'ont pas pu être lues"
              f" ({type(e).__name__})")
        continue
    for n, ligne in enumerate(lignes, 1):
        for m in MOTIF.finditer(ligne):
            if m.group(0) in connues or PASSEE.search(ligne):
                continue
            print("%s:%d → %s (branche inexistante, non marquée parquée/supprimée/archivée)"
                  % (rel, n, m.group(0)))
PY13
)
out=$(garde_plante $? "$out")
check "toute branche citée existe (ou est marquée passée)" "$out"


# 6) Compteurs vivants figés : « N tests » en prose périme à chaque commit — interdit hors
#     CHANGELOG (où c'est un instantané daté, append-only, donc légitime).
section "6. Pas de compteur de tests figé hors CHANGELOG"
# LE DERNIER CONTRÔLE RESTÉ SUR « grep -r ». Le repli sur un glob a été retiré plus haut, mais
# celui-ci passait encore $DOCS en opérandes. Une liste LÉGITIMEMENT vide — un dépôt sans .md,
# un lancement à la main avant la pose des gabarits — laissait grep sans opérande : le « -r »
# le lançait alors sur le dossier courant TOUT ENTIER, et un « 12 tests » dans du code rendait
# le contrôle rouge. Sur un grep non GNU, il lisait l'entrée standard à la place.
out=$(python3 scripts/corpus.py '*.md' \
      | xargs -0r grep -nHE '\b[0-9]+ tests\b' 2>/dev/null | grep -v '^CHANGELOG.md:')
check "aucun décompte de tests figé en prose" "$out"


# 7) Étalon « Écrire lisible » respecté, puis INVERSÉ.
#     Le contrôle marchait sur une liste d'AUTORISÉS, qui ne grandissait qu'aux réécritures :
#     un fichier NEUF n'y était jamais, donc naissait hors de toute vérification (constat admin,
#     deux fichiers créés le jour même à 38 et 14 de score). La logique est retournée : TOUT
#     fichier est contrôlé, SAUF ceux inscrits à la dette de scripts/dette-doc.txt, liste qui ne
#     fait que rétrécir (contrôle 8). Un fichier neuf naît donc conforme, sans geste à penser.
#     Le critère est le score 0 de scripts/doc-mesure.py : ponctuation à rôle unique, phrases de
#     moins de 25 mots, paragraphes de quatre phrases au plus, longueur sous la cible.
section "7. Étalon « Écrire lisible » (tout sauf la dette)"
out=$(python3 - 2>&1 <<'PY19'
import importlib.util, os, subprocess
spec = importlib.util.spec_from_file_location("dm", "scripts/doc-mesure.py")
dm = importlib.util.module_from_spec(spec); spec.loader.exec_module(dm)
dette = set()
for _f in os.environ['DETTES_DOC'].split(':'):
    if os.path.exists(_f):
        dette |= {l.strip() for l in open(_f, encoding='utf-8')
                  if l.strip() and not l.startswith('#')}
import importlib.util as _iu
_s = _iu.spec_from_file_location('corpus', 'scripts/corpus.py')
_c = _iu.module_from_spec(_s); _s.loader.exec_module(_c)
for f in _c.fichiers('*.md'):
    if f == 'CHANGELOG.md' or f.startswith('docs/archives/') or f in dette:
        continue
    try:
        d = dm.mesurer(f)
    except (UnicodeDecodeError, OSError) as e:
        print(f"{f} : illisible, la mesure n'a pas pu se faire ({type(e).__name__})")
        continue
    if d['score']:
        detail = []
        if d['pv']: detail.append(f"{d['pv']} « ; »")
        if d['fleche']: detail.append(f"{d['fleche']} flèche(s)")
        if d['et']: detail.append(f"{d['et']} « & »")
        if d['tirets']: detail.append(f"{d['tirets']} ligne(s) à plusieurs « — »")
        if d['longues']: detail.append(f"{d['longues']} phrase(s) de plus de 25 mots")
        if d['denses']: detail.append(f"{d['denses']} paragraphe(s) de plus de 4 phrases")
        if d['n'] > d['cible']: detail.append(f"{d['n']} lignes pour une cible de {d['cible']}")
        print(f"{f} (score {d['score']}) : " + ", ".join(detail))
PY19
)
out=$(garde_plante $? "$out")
check "l'étalon lisible est respecté hors dette (score 0)" "$out"


# 8) La dette de format NE GRANDIT JAMAIS. Sans ce verrou, la liste
#     inversée du contrôle 7 se contourne d'un geste : inscrire son fichier plutôt que l'écrire
#     au format. On compare donc la liste à sa version committée — toute ligne AJOUTÉE refuse le
#     commit. Retirer une ligne est libre, c'est le sens de la vie de cette liste.
#     LE VERROU VAUT AUSSI POUR LA LISTE LOCALE, et c'est ce qui coûte à la mise à jour. Élargir
#     l'étalon rend fautifs des fichiers qui étaient conformes la veille, et aucune inscription
#     ne les met à l'abri.
#     C'est voulu, et c'est le prix de chaque élargissement. Le projet réécrit sa prose, il ne
#     l'inscrit pas. Un noyau qui élargit l'étalon annonce donc cette étape dans son journal.
#     LIMITE, mesurée plutôt que supposée. Le verrou compare la liste à sa version committée,
#     donc une liste LOCALE non suivie par git n'a pas de version d'avant, et le contrôle la
#     saute. Un projet qui veut le verrou sur sa liste locale doit la versionner.
section "8. La dette de format ne fait que rétrécir"
out=$(python3 - 2>&1 <<'PY24'
import os, subprocess
def lire(txt):
    return {l.strip() for l in txt.splitlines() if l.strip() and not l.startswith('#')}
ajouts = set()
for DETTE in os.environ['DETTES_DOC'].split(':'):
    if not os.path.exists(DETTE):
        continue
    avant = subprocess.run(['git', 'show', f'HEAD:{DETTE}'], capture_output=True, text=True)
    if avant.returncode:      # première introduction du fichier : rien à comparer
        continue
    ajouts |= lire(open(DETTE, encoding='utf-8').read()) - lire(avant.stdout)
for a in sorted(ajouts):
    print(f"{a} : AJOUTÉ à la dette — écris-le au format, la liste ne grandit pas")
PY24
)
out=$(garde_plante $? "$out")
check "aucun fichier ajouté à la dette de format" "$out"


# 9) La dette de format ne grossit PAS PAR LE BAS. Le contrôle 8
#     promet que « la dette ne fait que rétrécir » — c'est vrai de la LISTE, à laquelle aucun
#     fichier ne s'ajoute. Ce n'était pas vrai de la DETTE : un fichier déjà inscrit pouvait
#     empirer autant qu'il voulait, personne ne le voyait. Constaté sur un dépôt antérieur. Une
#     seule session a ajouté 46 phrases de plus de 25 mots à un fichier de spec, sans qu'aucun
#     contrôle bronche, pendant que le contrôle jumeau du code faisait réécrire six commentaires
#     pour la même faute.
#     Ce contrôle compare les écarts de PROSE d'un fichier de la dette à ceux de HEAD, et refuse
#     toute hausse. Il ignore volontairement le dépassement de LONGUEUR qu'agrège le score de
#     doc-mesure.py : allonger un fichier déjà trop long est le prix d'une décision qu'on écrit,
#     et le remède est de le scinder (chantier de refonte), pas d'interdire d'écrire.
section "9. La dette de format ne grossit pas par le bas"
out=$(python3 - 2>&1 <<'PY29'
import importlib.util, os, subprocess, sys, tempfile
spec = importlib.util.spec_from_file_location("dm", "scripts/doc-mesure.py")
dm = importlib.util.module_from_spec(spec); spec.loader.exec_module(dm)
# « denses » a d'abord manqué ici, et c'était l'incident fondateur de ce contrôle rouvert.
# Un fichier de la dette passait de zéro à un paragraphe dense sans que rien ne bronche.
CRITERES = ("longues", "denses", "pv", "et", "tirets", "fleche")
dette = [l.strip() for _f in os.environ['DETTES_DOC'].split(':') if os.path.exists(_f)
         for l in open(_f, encoding='utf-8')
         if l.strip() and not l.startswith('#')]
suivis = subprocess.run(['git', 'diff', '--cached', '--name-only'],
                        capture_output=True, text=True).stdout.split()
if not suivis:                      # hors commit (appel manuel) : on regarde tout le suivi
    suivis = subprocess.run(['git', 'diff', 'HEAD', '--name-only'],
                            capture_output=True, text=True).stdout.split()
if not suivis:
    # Arbre propre : il n'y a RIEN à comparer, et le contrôle sortait alors muet — donc vert,
    # indistinguable d'une vraie vérification. Il le dit maintenant (audit). Ce
    # n'est PAS un échec : ce contrôle ne juge qu'un changement en cours, par construction —
    # d'où le préfixe INFO:, que le shell affiche à part au lieu de le compter comme une erreur.
    print("INFO: rien à comparer (arbre propre) — ce contrôle ne mesure qu'un changement en cours")
# Une FUSION a deux parents, et ce contrôle n'en voyait qu'un (corrigé). Comparé au
# seul HEAD, tout fichier de la dette que la branche fusionnée a touché paraît empiré, alors que
# la fusion n'y a rien ajouté. Le premier merge venu butait dessus, et la seule issue était de
# sauter le hook — donc de désarmer TOUS les contrôles pour contourner celui-là.
# La question honnête est « CE changement a-t-il empiré le fichier ». En fusion, la réponse est
# non dès qu'il n'est pire qu'AUCUN des deux parents.
# Le dossier git se DEMANDE, il ne se devine pas (corrigé). Dans un worktree, `.git`
# est un FICHIER qui pointe ailleurs, donc `.git/MERGE_HEAD` n'existe jamais. La branche fusion
# ci-dessus ne s'activait donc pas là où elle sert le plus. La ligne v2 ne vit QUE dans un
# worktree, par la règle du projet, et son report a buté dessus au premier essai.
parents = ['HEAD']
_gitdir = subprocess.run(['git', 'rev-parse', '--git-dir'],
                         capture_output=True, text=True).stdout.strip()
_merge_head = os.path.join(_gitdir, 'MERGE_HEAD') if _gitdir else ''
if _merge_head and os.path.exists(_merge_head):
    parents.append(open(_merge_head, encoding='utf-8').read().split()[0])


def mesures(ref, rel):
    """Les écarts de prose de `rel` tel qu'il est dans `ref`, ou None si absent de `ref`."""
    montre = subprocess.run(['git', 'show', f'{ref}:{rel}'], capture_output=True, text=True)
    if montre.returncode:
        return None
    with tempfile.NamedTemporaryFile('w', suffix='.md', delete=False, encoding='utf-8') as f:
        f.write(montre.stdout); tmp = f.name
    try:
        return dm.mesurer(tmp)
    finally:
        os.unlink(tmp)


for rel in dette:
    if rel not in suivis or not os.path.exists(rel):
        continue
    ap = dm.mesurer(rel)
    verdicts = []
    for parent in parents:
        av = mesures(parent, rel)
        if av is None:
            continue
        verdicts.append([f"{c} {av[c]}→{ap[c]}" for c in CRITERES if ap.get(c, 0) > av.get(c, 0)])
    if verdicts and all(verdicts):        # pire que TOUS les parents : c'est bien nous
        print(f"{rel} : la prose empire ({', '.join(verdicts[0])}) — corrige avant de committer")
PY29
)
out=$(garde_plante $? "$out")
# Les lignes INFO: ne sont pas des écarts : on les montre, puis on les retire avant le verdict.
printf '%s\n' "$out" | grep '^INFO: ' | sed 's/^INFO: /  ℹ️  /'
out=$(printf '%s\n' "$out" | grep -v '^INFO: ')
check "aucun fichier de la dette n'a vu sa prose empirer" "$out"


# 10) Le TEXTE de l'étalon et le CODE qui le mesure disent la même chose. Décision admin :
#     « l'ensemble des règles de rédaction stocké à un seul endroit et linté ».
#     Le bloc sync:etalon-redaction fait foi, doc-mesure.py l'implémente. Une constante changée
#     d'un côté et pas de l'autre laisserait la doc promettre autre chose que ce qui est mesuré,
#     sans un bruit. Ce contrôle referme le dernier chemin de dérive de l'étalon.
section "10. L'étalon écrit et l'étalon mesuré concordent"
out=$(python3 - 2>&1 <<'PY25'
import importlib.util, re
spec = importlib.util.spec_from_file_location("dm", "scripts/doc-mesure.py")
dm = importlib.util.module_from_spec(spec); spec.loader.exec_module(dm)
txt = open('docs/etalons-de-redaction.md', encoding='utf-8').read()
m = re.search(r'sync:etalon-redaction -->(.*?)<!--', txt, re.S)
if not m:
    print("bloc sync:etalon-redaction introuvable dans docs/etalons-de-redaction.md")
    raise SystemExit
bloc = m.group(1)
# On cherche le COUPLE mot-valeur, jamais le chiffre nu, pour la raison du contrôle 11.
# Sur « X au maximum » seul, les deux constantes se couvraient : échanger 25 et 4 laissait
# les deux phrases de l'étalon en place, et ce contrôle au vert.
if f"mots, {dm.MOTS_MAX} au maximum" not in bloc:
    print(f"MOTS_MAX = {dm.MOTS_MAX} dans doc-mesure.py, mais l'étalon écrit ne le dit pas")
if f"phrases, {dm.PHRASES_PAR_PARAGRAPHE_MAX} au maximum" not in bloc:
    print(f"PHRASES_PAR_PARAGRAPHE_MAX = {dm.PHRASES_PAR_PARAGRAPHE_MAX} dans doc-mesure.py,"
          " mais l'étalon écrit ne le dit pas")
for signe in dm.SIGNES_INTERDITS:
    if signe not in bloc:
        print(f"« {signe} » est interdit par doc-mesure.py, mais absent de l'étalon écrit")
# Même raison qu'au contrôle 11 : deux cibles peuvent valoir le même nombre, et la valeur nue
# ne dit alors pas laquelle est écrite. On cherche le couple, pas le chiffre.
for phrase, valeur, quoi in (
        (f"note de décision {dm.CIBLE_DECISION}", dm.CIBLE_DECISION, "note de décision"),
        (f"spec {dm.CIBLE_SPEC}", dm.CIBLE_SPEC, "spec")):
    if phrase not in bloc:
        print(f"cible {quoi} = {valeur} dans doc-mesure.py, or l'étalon écrit ne porte pas"
              f" la phrase « {phrase} »")
PY25
)
out=$(garde_plante $? "$out")
check "le texte de l'étalon et les constantes de doc-mesure.py concordent" "$out"


# 11) Même question, côté CODE : le bloc sync:etalon-code de docs/etalons-de-redaction.md
#     contre les constantes de scripts/code-mesure.py. On ÉTEND le contrôle 10 au lieu d'en
#     écrire un neuf : il pose déjà exactement cette question, et un second qui la poserait
#     autrement serait la duplication que l'étalon de code interdit lui-même (sa règle C1).
section "11. L'étalon de CODE écrit et l'étalon mesuré concordent"
out=$(python3 - 2>&1 <<'PY25B'
import importlib.util, re
spec = importlib.util.spec_from_file_location("cm", "scripts/code-mesure.py")
cm = importlib.util.module_from_spec(spec); spec.loader.exec_module(cm)
txt = open('docs/etalons-de-redaction.md', encoding='utf-8').read()
m = re.search(r'sync:etalon-code -->(.*?)<!--', txt, re.S)
if not m:
    print("bloc sync:etalon-code introuvable dans docs/etalons-de-redaction.md")
    raise SystemExit
bloc = m.group(1)
# ON CHERCHE LA PHRASE QUI PORTE LA VALEUR, PAS LA VALEUR SEULE. Un bloc qui contient déjà
# « 500 lignes » pour la limite de FICHIER validait n'importe quelle constante valant 500, la
# limite par fonction comprise. Le contrôle restait vert sur un décuplement de la règle.
for phrase, valeur, quoi in (
        (f"tient dans un écran, {cm.LIGNES_MAX_FONCTION} lignes", cm.LIGNES_MAX_FONCTION,
         "lignes par fonction"),
        (f"plus de {cm.LIGNES_MAX_FICHIER} lignes", cm.LIGNES_MAX_FICHIER,
         "lignes par fichier")):
    if phrase not in bloc:
        print(f"{quoi} = {valeur} dans code-mesure.py, or l'étalon écrit ne porte pas"
              f" la phrase « {phrase} »")
PY25B
)
out=$(garde_plante $? "$out")
check "le texte de l'étalon de code et les constantes de code-mesure.py concordent" "$out"


# 12) Étalon de PROSE DU CODE respecté. Copie du contrôle 7, côté
#     code : TOUT fichier Python suivi est contrôlé, SAUF ceux inscrits à scripts/dette-code.txt,
#     liste qui ne fait que rétrécir (contrôle 13). Un fichier neuf naît donc conforme, sans
#     geste à penser. Le critère est le score de prose 0 de scripts/code-mesure.py.
section "12. Étalon de prose du code (tout sauf la dette)"
out=$(python3 - 2>&1 <<'PY27'
import importlib.util, os, subprocess
spec = importlib.util.spec_from_file_location("cm", "scripts/code-mesure.py")
cm = importlib.util.module_from_spec(spec); spec.loader.exec_module(cm)
dette = set()
for _f in os.environ['DETTES_CODE'].split(':'):
    if os.path.exists(_f):
        dette |= {l.strip() for l in open(_f, encoding='utf-8')
                  if l.strip() and not l.startswith('#')}
import importlib.util as _iu
_s = _iu.spec_from_file_location('corpus', 'scripts/corpus.py')
_c = _iu.module_from_spec(_s); _s.loader.exec_module(_c)
for f in _c.fichiers('*.py'):
    if f.startswith(cm.EXCLUS) or f in dette:
        continue
    try:
        d = cm.mesurer(f)
    except (UnicodeDecodeError, OSError) as e:
        print(f"{f} : illisible, la mesure n'a pas pu se faire ({type(e).__name__})")
        continue
    if d['score']:
        detail = []
        if d['point_virgule']: detail.append(f"{d['point_virgule']} « ; »")
        if d['fleche']: detail.append(f"{d['fleche']} flèche(s)")
        if d['esperluette']: detail.append(f"{d['esperluette']} « & »")
        if d['tirets']: detail.append(f"{d['tirets']} ligne(s) à plusieurs « — »")
        if d['phrases_longues']: detail.append(f"{d['phrases_longues']} phrase(s) de plus de 25 mots")
        if d['paragraphes_denses']: detail.append(f"{d['paragraphes_denses']} paragraphe(s) de plus de 4 phrases")
        print(f"{f} (score {d['score']}) : " + ", ".join(detail))
PY27
)
out=$(garde_plante $? "$out")
check "la prose du code est au format hors dette (score 0)" "$out"


# 13) La dette de prose du code NE GRANDIT JAMAIS. Copie du contrôle 8, même motif : sans ce
#     verrou, le contrôle 12 se contourne d'un geste, en inscrivant son fichier plutôt qu'en
#     l'écrivant au format. Retirer une ligne reste libre.
section "13. La dette de prose du code ne fait que rétrécir"
out=$(python3 - 2>&1 <<'PY28'
import os, subprocess
def lire(txt):
    return {l.strip() for l in txt.splitlines() if l.strip() and not l.startswith('#')}
ajouts = set()
for DETTE in os.environ['DETTES_CODE'].split(':'):
    if not os.path.exists(DETTE):
        continue
    avant = subprocess.run(['git', 'show', f'HEAD:{DETTE}'], capture_output=True, text=True)
    if avant.returncode:      # première introduction du fichier : rien à comparer
        continue
    ajouts |= lire(open(DETTE, encoding='utf-8').read()) - lire(avant.stdout)
for a in sorted(ajouts):
    print(f"{a} : AJOUTÉ à la dette — écris sa prose au format, la liste ne grandit pas")
PY28
)
out=$(garde_plante $? "$out")
check "aucun fichier ajouté à la dette de prose du code" "$out"


# (Un contrôle d'alignement ligne à ligne entre le plan et le registre a vécu un jour sur un
#  dépôt antérieur, puis a été retiré. Le plan est devenu un RÉCIT, dont la prose ne se lint
#  pas, ce qui est assumé. Les items ne vivent plus qu'au registre. Garde-fou humain : relire
#  le récit à chaque item terminé.)

# 14) Faits du monde extérieur : observés ou supposés, jamais confondus.
#     Constat vécu : « l'aperçu de la liste est préfixé Vous : … » est entré dans le code sans
#     qu'on l'ait jamais observé, s'est fait verrouiller par un test écrit sur
#     la croyance elle-même (vert pour toujours), a fait payer un mois de classements inutiles,
#     puis a mis un ● sur chaque conversation le jour où il est devenu visible. Le code ne
#     distinguait pas le fait de la supposition — ce contrôle l'y force.
#     Toute croyance sur le DOM ou sur un site externe porte « @terrain <clé> » (observé)
#     ou « @suppose <clé> » (pas observé) ; la clé DOIT être une fiche de
#     $TERRAIN, et la fiche DOIT porter ses trois lignes.
section "14. Faits du monde extérieur étiquetés et fichés"
out=$(python3 - 2>&1 <<'PY22'
import re, pathlib, subprocess
REG = 'docs/observations-terrain.md'
texte = pathlib.Path(REG).read_text(encoding='utf-8')
# Une fiche = « ### <clé> » (le titre peut porter un suffixe « — RÉFUTÉ le … »).
fiches = {}
for bloc in re.split(r'^### ', texte, flags=re.M)[1:]:
    cle = bloc.splitlines()[0].split('—')[0].strip()
    fiches[cle] = bloc
errs = []
for cle, bloc in sorted(fiches.items()):
    if not re.match(r'^[a-z0-9-]+$', cle):
        errs.append(f"{REG} fiche « {cle} » : clé en minuscules et tirets uniquement")
    # ON EXIGE UNE VALEUR, PAS UNE ÉTIQUETTE. Tester la seule présence du libellé laissait
    # passer une fiche réduite à trois étiquettes vides : l'agent faisait taire le contrôle en
    # collant les libellés, sans jamais dire ce qui avait été observé.
    def renseigne(libelle):
        # [^\S\n] et non \s : \s traverse les retours à la ligne, et « **Observé :** » suivi
        # d'une ligne vide se serait validé sur le libellé SUIVANT. Mesuré.
        return re.search(rf'^\*\*{re.escape(libelle)} :\*\*[^\S\n]*\S', bloc, re.M)
    manquants = [c for c in ('Observé', 'Preuve') if not renseigne(c)]
    if not renseigne("Si c'est faux") and not renseigne("Conséquence"):
        manquants.append("Si c'est faux / Conséquence")
    if manquants:
        errs.append(f"{REG} fiche « {cle} » : ligne(s) manquante(s) — {', '.join(manquants)}")
# Étiquettes posées dans le code → la fiche doit exister.
# Clé d'au moins 3 caractères : la prose « l'étiquette @terrain a disparu » n'est pas
# une étiquette (faux positif vu à l'élargissement du périmètre).
etiq = re.compile(r'@(terrain|suppose)\s+([a-z0-9][a-z0-9-]{2,})')
# PÉRIMÈTRE : TOUT CE QUE GIT SUIT, moins une liste d'exclus. Le motif précédent était une
# liste d'AUTORISÉS, trois globs Python, alors que le dépôt a tranché l'inverse deux fois : une
# liste d'exclus qui ne fait que rétrécir, et un fichier neuf qui naît conforme. Une étiquette
# posée dans un fichier Kotlin, dans un shell ou dans un gabarit n'était confrontée à rien.
EXCLUS = (REG, 'CLAUDE.md', 'CHANGELOG.md', 'docs/archives/')
import importlib.util as _iu
_s = _iu.spec_from_file_location('corpus', 'scripts/corpus.py')
_c = _iu.module_from_spec(_s); _s.loader.exec_module(_c)
suivis = [f for f in _c.fichiers() if not f.startswith(EXCLUS)]
for src in [pathlib.Path(f) for f in sorted(suivis)]:
    try:
        lignes = src.read_text(encoding='utf-8').splitlines()
    except (UnicodeDecodeError, OSError):
        continue                      # binaire ou illisible : le contrôle 1 le nomme déjà
    for i, ligne in enumerate(lignes):
        for genre, cle in etiq.findall(ligne):
            if cle not in fiches:
                errs.append(f"{src}:{i+1} « @{genre} {cle} » sans fiche dans {REG}")
print('\n'.join(errs))
PY22
)
out=$(garde_plante $? "$out")
check "chaque @terrain/@suppose a sa fiche, chaque fiche a ses lignes" "$out"

# 15) LE POURQUOI. Les garde-fous étaient le seul mécanisme du projet source sans registre ni
#     contrôle. Sa table des contrôles avait fini avec cinq entrées de retard sur le script,
#     parce que rien ne la confrontait à lui. Ce contrôle compare le registre au dépôt DANS LES
#     DEUX SENS, et refuse le commit à la moindre divergence.
section "15. Registre des garde-fous (docs/garde-fous.md ↔ réalité)"
# CE CONTRÔLE NE FAIT QUE PASSER LE RELAIS. Ses cinq volets vivent dans
# scripts/registre-garde-fous.py, que l'installateur appelle LUI AUSSI pour dicter aux projets
# les lignes qui leur manquent. Les deux listes ont divergé deux fois avant d'être réunies, et
# l'étalon de code interdit qu'une règle s'écrive à deux endroits.
out=$(python3 scripts/registre-garde-fous.py --lint 2>&1)
out=$(garde_plante $? "$out")
check "le registre des garde-fous colle au dépôt, dans les deux sens" "$out"


# 16) LE POURQUOI. Le contrôle 15 attrape le retrait d'un garde-fou sans sa ligne au registre.
#     Le retrait des DEUX d'un coup, lui, passe sans bruit : le registre et le dépôt restent
#     cohérents, simplement plus pauvres. Ce contrôle refuse qu'une clé disparaisse. En ajouter
#     reste libre. La porte de sortie sert le jour où l'on retire un garde-fou pour de bon.
section "16. Le registre des garde-fous ne rétrécit jamais"
out=$(python3 - 2>&1 <<'PY16'
import os, re, subprocess, sys

if os.environ.get('RETRAIT_GARDE') == '1':
    sys.exit(0)
REG = 'docs/garde-fous.md'
avant = subprocess.run(['git', 'show', f'HEAD:{REG}'], capture_output=True, text=True)
if avant.returncode:          # première introduction du registre : rien à comparer
    sys.exit(0)

def cles(txt):
    """Les clés du registre, celles que le contrôle 15 lit en première colonne."""
    return set(re.findall(r'^\| `([^`]+)` \|', txt, re.M))

try:
    maintenant = cles(open(REG, encoding='utf-8').read())
except FileNotFoundError:
    print(f"{REG} a disparu — le registre des garde-fous ne se supprime pas")
    sys.exit(0)
for perdue in sorted(cles(avant.stdout) - maintenant):
    print(f"« {perdue} » RETIRÉE du registre — un garde-fou ne se retire pas en silence.")
    print("    Si le retrait est voulu : RETRAIT_GARDE=1 git commit …")
PY16
)
out=$(garde_plante $? "$out")
check "aucun garde-fou retiré du registre" "$out"

# 17) Liens vers le glossaire : un terme du glossaire employé dans un fichier y est lié AU
#     MOINS UNE FOIS. La règle écrite, elle, vise le PREMIER emploi. Elle vit dans
#     docs/etalons-de-redaction.md, section « Écrire une fiche technique ».
#     LA COUVERTURE EST PARTIELLE, ET C'EST ÉCRIT PLUTÔT QUE CACHÉ. Viser le premier emploi
#     demanderait de comparer des positions, ce que ce contrôle ne fait pas. Un terme de
#     plusieurs mots coupé par un retour à la ligne lui échappe aussi. Le détail des deux trous
#     vit en tête de scripts/liens-glossaire.py, qui en est le propriétaire.
#     TOUT TERME DU GLOSSAIRE COMPTE, à fiche ou non. Le périmètre s'est d'abord limité aux
#     termes à fiche, au motif qu'un lien doit mener à une explication.
#     Une roadmap employant « spike » sans un mot a montré le trou : le glossaire le
#     définissait, et rien ne rougissait. Une entrée brève est déjà une explication.
#     Seules comptent les puces de la section « Les entrées », qui est le marqueur d'entrée.
#     Un glossaire VIDE n'a donc aucun terme, et ce contrôle est vert sans rien avoir à lire.
#     C'est l'état normal d'un dépôt neuf. Le FICHIER, lui, est exigé : le contrôle 18 s'en
#     charge, et dit comment le reposer.
section "17. Liens vers le glossaire, au moins un par fichier"
out=$(python3 scripts/liens-glossaire.py --lint 2>&1)
out=$(garde_plante $? "$out")
check "aucun terme du glossaire n'est employé sans jamais être lié" "$out"


# 18) Le glossaire EXISTE. Le noyau en dépend, et il ne le disait nulle part.
#     Trois pièces du noyau tiennent ce chemin pour acquis : le contrôle 17 et
#     scripts/liens-glossaire.py, qui le porte en constante, et docs/etalons-de-redaction.md,
#     un fichier FIGÉ qui le cite en lien.
#     D'où l'impasse, mesurée : un projet qui retirait son glossaire voyait le contrôle 1
#     rougir sur ce fichier figé, donc tous ses commits refusés — et l'éditer pour retirer le
#     lien est dénoncé comme BRICOLAGE par verifier-noyau.sh. Aucune sortie depuis le projet.
#     Le fichier lui-même reste un GABARIT, la propriété du projet : le noyau exige qu'il
#     existe, jamais ce qu'on y écrit. L'installateur le repose s'il manque, et c'est le
#     remède que ce contrôle nomme, plutôt que de laisser le contrôle 1 accuser un fichier
#     que personne n'a le droit de toucher.
section "18. Le glossaire, exigé par le noyau, existe"
if [ -f docs/comprendre/glossaire.md ]; then
  out=""
else
  out="docs/comprendre/glossaire.md est absent — le noyau l'exige :
      le contrôle 17 et scripts/liens-glossaire.py en dépendent, et le fichier figé
      docs/etalons-de-redaction.md le cite en lien.
      C'est un gabarit : « bash installer.sh <ce projet> » le repose sans rien écraser."
fi
check "le glossaire exigé par le noyau est en place" "$out"

# ── Les contrôles LOCAUX du projet ────────────────────────────────────────────────────────────
# Ils vivent hors du noyau, portent le préfixe L, et sont sourcés ici pour partager section(),
# check() et garde_plante(). Un projet sans contrôle local n'a pas ce fichier, et c'est normal.
# LE FICHIER LOCAL TOURNE DANS UN SOUS-SHELL, ET CE N'EST PAS UN DÉTAIL. Sourcé dans la portée
# du parent, il partageait la variable du verdict : une ligne « fail=0 », posée exprès ou par une
# banale collision de nom, rendait « tout est vert » alors que des contrôles du noyau venaient de
# rougir. Le hook ne lit que le code de sortie, donc le commit fautif passait. Le sous-shell rend
# ce fichier incapable de toucher au verdict du noyau, et son propre verdict remonte par la
# sortie. Une redéfinition de check() ou de section() y est enfermée de la même façon.
#
# LE FICHIER LOCAL DOIT AVOIR TOURNÉ POUR QUE SON VERT COMPTE. Une faute de syntaxe, ou des
# droits qui empêchent la lecture, interrompaient le sourçage sans un mot : les contrôles
# suivants ne s'exécutaient pas, la sortie restait vide, et le lint annonçait « tout est vert ».
# On l'analyse donc avant de le sourcer, et on distingue un contrôle qui refuse, code 1, d'une
# interruption, code supérieur.
#
# LIMITE ASSUMÉE, et elle est réelle. Une commande qui échoue DANS une condition `if` du fichier
# local n'est rattrapée ni par `bash -n` ni par ce code de sortie. Son message part sur la
# sortie d'erreur, et le contrôle qu'elle devait rendre n'existe tout simplement pas.
if [ -f scripts/doc-lint-local.sh ]; then
  fail_noyau=$fail
  if ! erreur=$(bash -n scripts/doc-lint-local.sh 2>&1); then
    printf '  ❌ %s\n' "scripts/doc-lint-local.sh ne s'analyse pas, ses contrôles n'ont pas tourné"
    printf '%s\n' "$erreur" | sed 's/^/      /'
    fail=1
  else
    # shellcheck source=/dev/null
    ( fail=0; . scripts/doc-lint-local.sh; exit "$fail" )
    fail_local=$?
    if [ "$fail_local" -gt 1 ]; then
      printf '  ❌ %s\n' "scripts/doc-lint-local.sh s'est interrompu (code $fail_local)"
      printf '      %s\n' "ses contrôles n'ont pas tous tourné, le vert ne prouve rien"
    fi
    [ "$fail_local" -eq 0 ] || fail=1
  fi
  [ "$fail_noyau" -eq 0 ] || fail=1
fi

if [ "$fail" -ne 0 ]; then
  printf '\n\033[1;31m❌ doc-lint : au moins un contrôle a échoué (voir ci-dessus).\033[0m\n'
  exit 1
fi
printf '\n\033[1;32m✅ doc-lint : tout est vert.\033[0m\n'
