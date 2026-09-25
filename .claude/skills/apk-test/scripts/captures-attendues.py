#!/usr/bin/env python3
"""Les captures qu'un parcours DOIT produire, dérivées du parcours lui-même.

POURQUOI CE FICHIER EXISTE
--------------------------
Le plancher valait ZÉRO image. Une seule capture sur la douzaine attendue passait donc pour un
succès. Le run 32254733286 est parti vert sans que rien ne compte ce qu'il rapportait.

Un nombre écrit à la main ne corrige pas ça, il le déplace. Il se périme au premier écran ajouté,
en silence. On dérive donc l'attendu du fichier Kotlin du parcours lui-même.

CE FICHIER EST HORS DU BASH EXPRÈS. Ce qui vit dans `parcours-emulateur.sh` ne se vérifie qu'en
louant un émulateur, soit une douzaine de minutes. Ici, pytest juge l'extraction en une fraction
de seconde, avant que la chaîne ne soit lancée.

LA RÈGLE QUI TIENT TOUT : une forme non comprise est un REFUS, jamais une devinette. Le contraire
reconstituerait le trou qu'on vient de boucher, et il serait invisible.

LE DSL N'EST PAS RÉGLABLE, et c'est voulu. `photographier("littéral")`, une boucle `repeat(n)`
dépliée, des interpolations `${i}` ou `${i + k}`. Le gabarit Kotlin du skill impose cette forme,
et rendre la forme configurable rouvrirait par la configuration le trou que le refus ferme. La
seule chose qui varie d'un projet à l'autre est le nom de l'argument du jeton, `--arg-jeton`.
"""
import argparse
import itertools
import re
import sys
from pathlib import Path

# `repeat(3) { tour ->` : le seul tour de boucle du parcours, et le seul qu'on accepte de déplier.
REPETITION = re.compile(r"repeat\((\d+)\)\s*\{\s*(\w+)\s*->")
# Un appel dont l'argument est un littéral, interpolations comprises.
CAPTURE_LITTERALE = re.compile(r'photographier\("([^"]*)"\)')
# Un appel, quelle que soit sa forme. Sert UNIQUEMENT à refuser ce que la ligne du dessus ne sait
# pas lire : sans lui, un `photographier(nom)` disparaîtrait de l'attendu sans un mot.
CAPTURE_QUELCONQUE = re.compile(r"photographier\(")
INTERPOLATION = re.compile(r"\$\{([^}]*)\}")
# `tour + 1` ou `tour`. Toute autre expression est un refus.
EXPRESSION = re.compile(r"^\s*(\w+)\s*(?:\+\s*(\d+)\s*)?$")

DEBUT_DE_CORPS = re.compile(r"\bfun\s+(\w+)\s*\(")

# Ce qui compte comme une capture. Le dossier rapatrié porte aussi le film et les journaux.
# Sans cette liste, un écran est « photographié » par un fichier qui ne montre rien.
EXTENSIONS_IMAGE = {".png", ".jpg", ".jpeg", ".webp"}


class RefusDExtraction(Exception):
    """L'extraction n'a pas compris ce qu'elle lisait, et refuse de deviner."""


def code_seul(source: str) -> str:
    """Le source sans ses commentaires, les chaînes respectées, les lignes conservées.

    Lire du commentaire, c'est ne rien tester (revue du 2026-08-10), et ici c'est pire. Un
    `photographier(` cité dans un commentaire du corps devenait un nom exigé, ou un refus. Un
    commentaire glissé entre `@Test` et `fun` faisait disparaître le test de l'attendu en silence
    (revue 2026-09-02).

    Les chaînes sont respectées, sans quoi `"https://…"` serait un commentaire.
    Un bloc jamais refermé est un REFUS. Les sauts de ligne survivent, pour garder les positions.
    """
    sortie, i, n, dans_chaine = [], 0, len(source), False
    while i < n:
        c = source[i]
        if dans_chaine:
            sortie.append(c)
            if c == "\\" and i + 1 < n:
                sortie.append(source[i + 1])
                i += 1
            elif c == '"':
                dans_chaine = False
        elif c == '"':
            dans_chaine = True
            sortie.append(c)
        elif source.startswith("//", i):
            fin = source.find("\n", i)
            if fin == -1:
                break
            i = fin - 1                           # le saut de ligne est gardé par le tour suivant
        elif source.startswith("/*", i):
            fin = source.find("*/", i + 2)
            if fin == -1:
                raise RefusDExtraction("commentaire de bloc jamais refermé")
            sortie.append("\n" * source.count("\n", i, fin))
            i = fin + 1
        else:
            sortie.append(c)
        i += 1
    return "".join(sortie)


def _corps(source: str, ouvrante: int) -> str:
    """Le corps délimité par l'accolade à `ouvrante`, accolades imbriquées comprises."""
    profondeur = 0
    for i in range(ouvrante, len(source)):
        if source[i] == "{":
            profondeur += 1
        elif source[i] == "}":
            profondeur -= 1
            if profondeur == 0:
                return source[ouvrante + 1:i]
    raise RefusDExtraction("accolade jamais refermée dans le parcours")


def _tests(source: str) -> list[dict]:
    """Les fonctions annotées `@Test`, avec ce qui conditionne leur exécution.

    Les annotations se lisent sur les lignes d'AVANT, et sur la ligne de la déclaration
    elle-même. `@Test fun parcours() {` est une forme Kotlin valide. La ranger en annotation
    sans jamais y chercher de déclaration faisait disparaître le test de l'attendu, EN SILENCE.

    `lister` rendait une liste vide avec un code 0, et le plancher retombait à ZÉRO. C'est le
    trou même que ce module existe pour boucher.

    Jumeau du défaut « commentaire entre `@Test` et `fun` », corrigé lui le 2026-09-02. Celui-ci
    a été trouvé en revue au portage vers ce skill.
    """
    trouves, annotations, position = [], [], 0
    for ligne in source.splitlines(keepends=True):
        nue = ligne.strip()
        m = DEBUT_DE_CORPS.search(ligne)
        if m:
            # La déclaration CONSOMME le bloc d'annotations, celles d'au-dessus comme celle qui
            # la précède sur sa propre ligne. Puis le bloc repart à vide, qu'elle ait été un
            # test ou non : ses annotations ne portent pas sur la déclaration suivante.
            portees = " ".join(annotations + ([nue] if nue.startswith("@") else []))
            if "@Test" in portees:
                ouvrante = source.find("{", position + m.end())
                if ouvrante == -1:
                    raise RefusDExtraction(f"corps introuvable pour {m.group(1)}")
                trouves.append({
                    "nom": m.group(1),
                    "ignore": "@Ignore" in portees,
                    "corps": _corps(source, ouvrante),
                })
            annotations = []
        elif nue.startswith("@"):
            annotations.append(nue)
        elif nue:
            annotations = []
        position += len(ligne)
    return trouves


def _noms_du_corps(corps: str, ou: str) -> list[str]:
    """Les noms photographiés par ce corps, boucles dépliées."""
    noms, pile, profondeur, i = [], [], 0, 0
    while i < len(corps):
        if m := REPETITION.match(corps, i):
            profondeur += 1                       # l'accolade avalée par le motif
            pile.append((profondeur, int(m.group(1)), m.group(2)))
            i = m.end()
            continue
        if m := CAPTURE_LITTERALE.match(corps, i):
            noms.extend(_deplier(m.group(1), pile, ou))
            i = m.end()
            continue
        if CAPTURE_QUELCONQUE.match(corps, i):
            extrait = corps[i:i + 60].splitlines()[0]
            raise RefusDExtraction(
                f"{ou} : argument non littéral, impossible d'en dériver un nom — « {extrait} »")
        if corps[i] == "{":
            profondeur += 1
        elif corps[i] == "}":
            while pile and pile[-1][0] == profondeur:
                pile.pop()
            profondeur -= 1
        i += 1
    return noms


def _deplier(brut: str, pile: list[tuple], ou: str) -> list[str]:
    """Un nom littéral, ses interpolations résolues sur les boucles qui l'entourent."""
    morceaux = INTERPOLATION.findall(brut)
    if not morceaux:
        return [brut]
    bornes, variables = [], []
    for morceau in morceaux:
        expression = EXPRESSION.match(morceau)
        if not expression:
            raise RefusDExtraction(f"{ou} : interpolation illisible — « ${{{morceau}}} »")
        variable, decalage = expression.group(1), int(expression.group(2) or 0)
        boucle = next((b for b in pile if b[2] == variable), None)
        if boucle is None:
            raise RefusDExtraction(
                f"{ou} : « {variable} » ne vient d'aucune boucle connue — nom indérivable")
        bornes.append([t + decalage for t in range(boucle[1])])
        variables.append(morceau)
    noms = []
    for valeurs in itertools.product(*bornes):
        nom = brut
        for variable, valeur in zip(variables, valeurs):
            nom = nom.replace("${" + variable + "}", str(valeur), 1)
        noms.append(nom)
    return noms


def noms_attendus(parcours: Path, avec_jeton: bool, arg_jeton: str = "jetonTest") -> list[str]:
    """Les noms de capture que ce parcours doit produire, dans l'ordre, sans doublon.

    Un test `@Ignore` n'attend rien. Un test que le jeton conditionne n'attend rien sans lui.
    Le faire rougir punirait une absence de configuration, et un garde-fou qui rougit toujours
    finit contourné. Le test est reconnu au nom de l'argument du jeton, `arg_jeton`, cité dans
    son corps à côté de `assumeTrue`.
    """
    source = code_seul(parcours.read_text(encoding="utf-8"))
    if not source.strip():
        raise RefusDExtraction(f"{parcours} est vide")
    attendus = []
    for test in _tests(source):
        if test["ignore"]:
            continue
        if arg_jeton in test["corps"] and "assumeTrue" in test["corps"] and not avec_jeton:
            continue
        attendus.extend(_noms_du_corps(test["corps"], test["nom"]))
    return list(dict.fromkeys(attendus))


def manquants(dossier: Path, parcours: Path, avec_jeton: bool,
              arg_jeton: str = "jetonTest") -> list[str]:
    """Les noms attendus qu'aucune IMAGE du dossier ne porte, sous-dossiers comprises.

    Le rapprochement se fait sur le nom ENTIER du fichier, extension ôtée, jamais sur un
    fragment. Le gabarit Kotlin écrit `<nom>.png` et rien d'autre, donc l'exactitude ne coûte
    rien. Un test de sous-chaîne, lui, rendait « 05-tour1 » satisfait par « 05-tour10.png » dès
    qu'un `repeat(n)` dépassait neuf.

    Et sur les IMAGES seules. Le dossier rapatrié porte aussi le film et les journaux. Un écran
    nommé « navigation » était donc couvert par `navigation.mp4`, un écran « debug » par
    `logcat-debug.txt`. Un contrôle satisfait par un fichier qui ne montre rien ne contrôle rien.
    """
    presents = {c.stem.lower() for c in dossier.rglob("*")
                if c.is_file() and c.suffix.lower() in EXTENSIONS_IMAGE}
    return [n for n in noms_attendus(parcours, avec_jeton, arg_jeton)
            if n.lower() not in presents]


def main(argv: list[str] | None = None) -> int:
    tete = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sous = tete.add_subparsers(dest="action", required=True)
    lister = sous.add_parser("lister", help="les noms attendus, un par ligne")
    lister.add_argument("parcours", type=Path)
    verifier = sous.add_parser("verifier", help="les noms attendus qui manquent au dossier")
    verifier.add_argument("dossier", type=Path)
    verifier.add_argument("parcours", type=Path)
    for p in (lister, verifier):
        p.add_argument("--avec-jeton", action="store_true",
                       help="le jeton de test était fourni, les écrans authentifiés sont exigés")
        p.add_argument("--arg-jeton", default="jetonTest",
                       help="le nom de l'argument d'instrumentation qui porte le jeton")
    args = tete.parse_args(argv)

    try:
        if args.action == "lister":
            for nom in noms_attendus(args.parcours, args.avec_jeton, args.arg_jeton):
                print(nom)
            return 0
        absents = manquants(args.dossier, args.parcours, args.avec_jeton, args.arg_jeton)
    except RefusDExtraction as refus:
        # Code 2, distinct du 1 : « je n'ai pas su lire » n'est pas « il manque des images ». La
        # réponse n'est pas la même, le bash les sépare, et aucun des deux ne retombe sur zéro.
        print(f"extraction refusée : {refus}", file=sys.stderr)
        return 2
    if absents:
        print(" ".join(absents))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
