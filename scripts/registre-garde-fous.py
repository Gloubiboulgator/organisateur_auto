#!/usr/bin/env python3
"""registre-garde-fous.py — confronte docs/garde-fous.md à la réalité du dépôt. NOYAU PARTAGÉ.

CE FICHIER EXISTE PARCE QUE DEUX ENDROITS CONNAISSAIENT LA MÊME RÈGLE. Le contrôle 15 vivait
dans un heredoc de scripts/doc-lint.sh, et installer.sh recopiait sa liste de fichiers pour
dicter aux projets les lignes qui leur manquent. Les deux copies ont divergé deux fois en une
matinée. Un projet ajoutait ce qu'on lui dictait, committait, et se faisait refuser pour des
clés que personne ne lui avait données.

L'étalon de code l'interdit, dans docs/etalons-de-redaction.md, section « Écrire du code
lisible » : une règle ne s'écrit qu'à un seul endroit. Les deux appelants passent donc ici.

NE PAS RENOMMER CE FICHIER EN garde-*.sh, dette-*.txt NI verifier-*.sh. Le volet 4 réclame une
ligne de registre pour chacun de ces motifs. Le script se réclamerait alors sa propre ligne.

Deux usages.
    --lint      imprime les manquements, un par ligne.
    --dicter    imprime les lignes de tableau à coller.
"""
import json
import pathlib
import re
import sys

REG = pathlib.Path('docs/garde-fous.md')


def cles_du_registre(registre: str) -> set[str]:
    """Les clés du registre, et rien d'autre.

    Une clé est la PREMIÈRE COLONNE d'un tableau. Une mention en prose ne vaut pas inscription.
    C'est exactement ce que lit le contrôle 16, qui refuse qu'une clé disparaisse. Un garde-fou
    « inscrit » par une phrase en sortait donc en silence, et pouvait être retiré sans un mot.
    """
    return set(re.findall(r'^\| `([^`]+)` \|', registre, re.M))


def fichiers_de_garde() -> list[str]:
    """Les fichiers de garde-fou que le registre doit décrire, dans l'ordre du volet 4."""
    trouves = [f"githooks/{p.name}"
               for p in sorted(pathlib.Path('scripts/githooks').glob('*')) if p.is_file()]
    for motif in ('garde-*.sh', 'dette-*.txt', 'verifier-*.sh'):
        trouves += [f"scripts/{p.name}" for p in sorted(pathlib.Path('scripts').glob(motif))]
    return trouves


def gardes_branches() -> str | None:
    """Les commandes réellement branchées dans .claude/settings.json, ou None si illisible.

    ON LIT L'ARBRE, PAS LE TEXTE. Chercher le nom du garde dans le fichier entier acceptait
    n'importe quelle mention : un commentaire, une clé inutilisée, un tableau de notes. Il a
    suffi de recopier les quatre noms dans un champ libre et de vider le bloc « hooks ». Le
    contrôle repassait au vert, alors que plus rien n'était câblé.

    ÉCHEC OUVERT. Un settings absent ou illisible n'est pas un défaut de ce contrôle. Un JSON
    valide qui n'est pas un objet, comme un tableau, faisait mourir le contrôle entier sur un
    AttributeError. Ses cinq volets mouraient avec lui.
    """
    try:
        arbre = json.loads(pathlib.Path('.claude/settings.json').read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return None
    if not isinstance(arbre, dict):
        return None
    branchees = []
    hooks = arbre.get('hooks')
    if isinstance(hooks, dict):
        for groupes in hooks.values():
            for groupe in groupes if isinstance(groupes, list) else []:
                for h in (groupe or {}).get('hooks', []) if isinstance(groupe, dict) else []:
                    if isinstance(h, dict) and isinstance(h.get('command'), str):
                        branchees.append(h['command'])
    return ' '.join(branchees)


# Le ⛔ ouvre deux interdits, et un titre peut le porter comme une clé peut ne pas le porter.
# Sans lui la comparaison échouait des DEUX côtés, et décrivait un seul écart comme deux défauts
# sans rapport. C'est la faute que le dépôt source a déjà vécue (revue de code du 2026-09-07).
DECOR = r'[`*⛔]'


def normaliser(titre: str) -> str:
    """Un titre ou une clé, réduits à ce qui se compare : sans mise en forme, ni casse."""
    return re.sub(r'\s+', ' ', re.sub(DECOR, '', titre)).strip().casefold()


def ouvre(titre: str, cle: str) -> bool:
    """Ce titre et cette clé se rapprochent-ils ? LA relation, écrite une fois.

    Le registre cite un DÉBUT de titre : renommer la fin d'une section reste permis. Le sens
    inverse est toléré aussi, pour une clé plus longue que le titre qu'elle vise.
    """
    t, c = normaliser(titre), normaliser(cle)
    return t.startswith(c) or c.startswith(t[:24])


def titres_de_claude(niveaux: str = '{2}') -> list[str] | None:
    """Les titres de CLAUDE.md, hors ceux qui se déclarent pas-un-garde-fou. None s'il manque.

    LES DEUX SENS NE POSENT PAS LA MÊME QUESTION, et ne lisent donc pas les mêmes titres.

    Le sens direct exige une entrée par SECTION, `##` seulement. C'est le contrat que le
    gabarit du registre applique : il ne porte aucune ligne pour les sous-sections du fichier
    d'instructions. L'élargir rendrait rouge tout projet équipé, du jour au lendemain.

    Le sens inverse lit AUSSI les `###`. Une clé peut légitimement nommer une sous-section, et
    six clés d'un projet réel le font. Ne lire que les `##` les accusait toutes de n'ouvrir
    plus rien, ce qui gelait tous ses commits (revue de code du 2026-09-07).

    Un CLAUDE.md absent rend None, jamais une liste vide. Sans cette distinction, le sens
    inverse accusait d'un coup TOUTES les clés de règle. Il envoyait retirer des lignes justes
    au lieu de restaurer le fichier manquant.
    """
    claude = pathlib.Path('CLAUDE.md')
    if not claude.exists():
        return None
    lignes = claude.read_text(encoding='utf-8').splitlines()
    titres = []
    for i, ligne in enumerate(lignes):
        m = re.match(rf'^#{niveaux} (.+)$', ligne)
        if not m:
            continue
        if i + 1 < len(lignes) and 'pas-un-garde-fou' in lignes[i + 1]:
            continue
        titres.append(m.group(1).strip())
    return titres


def cles_de_regle(cles: set[str]) -> set[str]:
    """Les clés qui nomment une RÈGLE de CLAUDE.md, et non un contrôle ou un fichier.

    Les autres volets possèdent déjà les contrôles locaux, ceux du code-lint et les fichiers de
    garde. Leur demander d'ouvrir une section les accuserait à tort, et le registre ne peut pas
    les retirer : le contrôle 16 refuse tout retrait.
    """
    return {c for c in cles
            if not re.fullmatch(r'L\d+|code-lint:\d+', c)
            and not c.startswith(('githooks/', 'scripts/'))}


def coupe(titre: str, n: int = 40) -> str:
    """Un titre raccourci le DIT. Sans les points de suite, il se lit comme un titre entier."""
    return titre if len(titre) <= n else titre[:n] + '…'


def volet_table_des_controles() -> list[str]:
    """Volet 1. Les contrôles du doc-lint du noyau ↔ la table du système documentaire.

    Le registre ne les liste pas un par un. Leur propriétaire est le système documentaire, et
    recopier la liste ici créerait une deuxième vérité. Rien ne se dicte donc dans ce volet.
    """
    errs = []
    lint = pathlib.Path('scripts/doc-lint.sh').read_text(encoding='utf-8')
    reels = set(re.findall(r'^section "(\d+)\.', lint, re.M))
    table = pathlib.Path('docs/systeme-documentaire.md')
    if table.exists():
        poses = set(re.findall(r'^\| (\d+) \|', table.read_text(encoding='utf-8'), re.M))
        for n in sorted(reels - poses, key=int):
            errs.append(f"contrôle {n} du doc-lint absent de la table de"
                        f" docs/systeme-documentaire.md")
        for n in sorted(poses - reels, key=int):
            errs.append(f"la table de docs/systeme-documentaire.md décrit un contrôle {n}"
                        f" qui n'existe plus")
    return errs


def volet_controles_locaux(cles: set[str]) -> tuple[list[str], list[str]]:
    """Volet 2. Les contrôles propres au projet ↔ le registre."""
    errs, dictables = [], []
    local = pathlib.Path('scripts/doc-lint-local.sh')
    if local.exists():
        locaux = re.findall(r'^section "(L\d+)\.', local.read_text(encoding='utf-8'), re.M)
        for n in sorted(set(locaux)):
            if n not in cles:
                errs.append(f"contrôle local {n} sans sa ligne de tableau dans"
                            f" docs/garde-fous.md")
                dictables.append(n)
    return errs, dictables


def volet_code_lint(registre: str) -> tuple[list[str], list[str]]:
    """Volet 3. Les contrôles du code-lint ↔ le registre, dans les deux sens."""
    errs, dictables = [], []
    cl = pathlib.Path('scripts/code-lint.sh')
    if not cl.exists():
        return errs, dictables
    reels = {f"code-lint:{n}"
             for n in re.findall(r'^section "(\d+)\.', cl.read_text(encoding='utf-8'), re.M)}
    poses = set(re.findall(r'`(code-lint:\d+)`', registre))
    for c in sorted(reels - poses):
        errs.append(f"{c} existe mais n'a pas sa clé dans docs/garde-fous.md")
        dictables.append(c)
    for c in sorted(poses - reels):
        errs.append(f"docs/garde-fous.md cite {c}, qui n'existe plus dans scripts/code-lint.sh")
    return errs, dictables


def volet_fichiers(cles: set[str]) -> tuple[list[str], list[str]]:
    """Volet 4. Les hooks git et les gardes de scripts/ ↔ le registre, dans les deux sens.

    Le sens inverse, que la doc promet, ne se faisait pas. Une clé qui désigne un fichier de
    garde-fou disparu laisserait le registre décrire une protection absente. « githooks/ »
    suivi de la fin de chaîne ne reconnaissait AUCUN hook, car les clés réelles portent un nom
    après la barre. Retirer un hook en laissant sa ligne au registre passait donc au vert.
    """
    errs, dictables = [], []
    fichiers = fichiers_de_garde()
    for f in fichiers:
        if f not in cles:
            errs.append(f"{f} existe mais n'a pas sa ligne de tableau dans docs/garde-fous.md")
            dictables.append(f)
    forme = re.compile(
        r'^(githooks/[^/]+|scripts/(garde-.*\.sh|dette-.*\.txt|verifier-.*\.sh))$')
    for cle in sorted(cles):
        if forme.match(cle) and cle not in fichiers:
            errs.append(f"docs/garde-fous.md décrit « {cle} », qui n'existe plus dans le dépôt")
    return errs, dictables


def volet_regles_ecrites(cles: set[str]) -> tuple[list[str], list[str]]:
    """Volet 5. Les règles écrites de CLAUDE.md ↔ le registre, DANS LES DEUX SENS.

    Une machine ne sait pas reconnaître ce qu'est une règle. On exige donc une entrée PAR
    TITRE, ce qui est plus grossier que la vérité. Une section qui n'est pas un garde-fou
    s'exempte par une ligne « pas-un-garde-fou » juste sous son titre.

    Le sens inverse manquait, alors que le libellé du contrôle le promettait. Une clé qui
    n'ouvre aucun titre décrit une protection disparue, et son vert ment. Une clé qui en ouvre
    DEUX veut dire qu'une section neuve s'est glissée sous une clé existante, en commençant par
    les mêmes mots. Elle n'a alors jamais réclamé sa propre ligne.
    """
    errs, dictables = [], []
    sections = titres_de_claude()
    if sections is None:
        return errs, dictables
    for titre in sections:
        if not any(ouvre(titre, c) for c in cles):
            errs.append(f"CLAUDE.md § « {coupe(titre, 55)} » sans clé dans docs/garde-fous.md")
            dictables.append(titre)
    avec_sous_sections = titres_de_claude('{2,3}') or []
    for cle in sorted(cles_de_regle(cles)):
        ouverts = [t for t in avec_sous_sections if ouvre(t, cle)]
        if not ouverts:
            errs.append(f"docs/garde-fous.md : « {coupe(cle)} » n'ouvre plus aucune section de "
                        f"CLAUDE.md — la protection a disparu, ou la clé a vieilli. Retirer la "
                        f"ligne demande RETRAIT_GARDE=1, que le contrôle 16 exige.")
        elif len(ouverts) > 1:
            noms = ', '.join(f'« {coupe(t)} »' for t in ouverts)
            errs.append(f"docs/garde-fous.md : « {coupe(cle)} » ouvre {len(ouverts)} sections de "
                        f"CLAUDE.md ({noms}) — une section neuve s'est glissée sous une clé "
                        f"existante. Allonger la clé passe par RETRAIT_GARDE=1, cf. contrôle 16.")
    return errs, dictables


def volet_gardes_dagent() -> list[str]:
    """Un garde d'agent qui n'est déclaré nulle part ne garde rien.

    Le registre dit qu'ils vivent dans le settings.json VERSIONNÉ. On le vérifie, plutôt que de
    le croire. Rien ne se dicte ici : cela se répare dans le JSON, pas dans le tableau.
    """
    declare = gardes_branches()
    if declare is None:
        return []
    return [f"scripts/{p.name} existe mais n'est déclaré dans aucun hook de"
            f" .claude/settings.json — il ne garde rien"
            for p in sorted(pathlib.Path('scripts').glob('garde-*.sh'))
            if p.name not in declare]


def examiner() -> tuple[list[str], list[str]]:
    """Rend les manquements à dire, puis les seules clés qu'on peut dicter.

    LES DEUX SORTIES VIENNENT DU MÊME PARCOURS, et c'est tout l'objet de ce fichier. Le lint
    imprime la première, l'installateur colle la seconde.

    Tout manquement ne se dicte pas. Une clé orpheline se RETIRE du registre, elle ne s'y
    ajoute pas. Un garde non branché se répare dans .claude/settings.json, pas dans le tableau.
    Et le volet 1 confronte le lint à docs/systeme-documentaire.md, une autre table.

    L'ORDRE DES VOLETS EST CELUI DE LA SORTIE, et il ne se change pas à la légère. Un projet
    lit ces lignes pour réparer son registre, du premier volet au dernier.
    """
    if not REG.exists():
        return ["docs/garde-fous.md est absent — le registre des garde-fous doit exister"], []
    registre = REG.read_text(encoding='utf-8')
    cles = cles_du_registre(registre)

    errs = volet_table_des_controles()
    dictables: list[str] = []
    for volet in (volet_controles_locaux(cles), volet_code_lint(registre),
                  volet_fichiers(cles)):
        errs += volet[0]
        dictables += volet[1]
    errs += volet_gardes_dagent()

    volet = volet_regles_ecrites(cles)
    errs += volet[0]
    dictables += volet[1]
    return errs, dictables


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else '--lint'
    errs, dictables = examiner()
    if mode == '--lint':
        print('\n'.join(errs))
        return
    if mode != '--dicter':
        print(f"usage : {sys.argv[0]} [--lint|--dicter]", file=sys.stderr)
        raise SystemExit(2)
    # LA DICTÉE NE REMPLIT PAS LES CASES. Le registre est le fichier du projet : on lui donne
    # la ligne et sa clé, jamais ce qu'il doit y écrire.
    for cle in dictables:
        print(f"  | `{cle}` | … | … |")


if __name__ == '__main__':
    main()
