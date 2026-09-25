#!/usr/bin/env python3
"""Mesure la conformité de la PROSE DU CODE à l'étalon de rédaction.

Les commentaires et les docstrings sont de la prose. Ils obéissent donc au bloc
`sync:etalon-redaction` de docs/etalons-de-redaction.md, sans qu'une règle soit réinventée. Le
calcul lui-même vit dans etalon_prose.py, partagé avec doc-mesure.py.

Outil de SUIVI du chantier de lisibilité, pas un garde-fou. Il n'échoue jamais et ne bloque
aucun commit. Le garde-fou, lui, est le contrôle 12 du doc-lint.

    python3 scripts/code-mesure.py                    # tout le Python suivi par git
    python3 scripts/code-mesure.py scripts/x.py       # un ou plusieurs fichiers

Périmètre du jour, le Python seul. Kotlin, JavaScript, bash et Jinja n'ont aucun analyseur
disponible sans dépendance nouvelle. Sur ces piles l'étalon vaut en relecture, pas en mesure, et
un score de zéro n'y signifierait rien.

Ce qui est retiré avant de compter, faute d'être de la prose.

- Les lignes d'exemple d'une docstring, reconnues à leur indentation, comme doc-mesure.py
  retire les blocs de code d'un Markdown.
- Les lignes de doctest.
- Les directives destinées aux outils, du genre « noqa ».

Limite connue et assumée. Un commentaire qui cite du code sans accent grave, une requête SQL
par exemple, compte encore ses points-virgules. Le chiffre surestime donc un peu, dans les mêmes
proportions que son aîné surestime les liens d'un Markdown.
"""
from __future__ import annotations

import ast
import io
import re
import sys
import tokenize
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from corpus import fichiers as corpus_fichiers  # noqa: E402

from etalon_prose import mesurer_prose  # noqa: E402

RACINE = Path(__file__).resolve().parent.parent

# Un artefact engendré se règle à son générateur : le mesurer arriverait après la dépense.
EXCLUS = ("tests/fixtures/",)

# Directives lues par des outils, jamais par un humain.
PRAGMAS = re.compile(r"^\s*(noqa|type:|pylint:|mypy:|pragma:|shellcheck)", re.I)

# Les nombres de l'étalon, nommés pour que le contrôle 11 du doc-lint puisse les confronter au
# TEXTE qui fait foi, le bloc sync:etalon-code de docs/etalons-de-redaction.md. Sans cette
# confrontation, changer 50 en 40 ici laisserait la doc promettre autre chose, sans un bruit.
LIGNES_MAX_FONCTION = 50
LIGNES_MAX_FICHIER = 500

# Un bandeau de section, à la convention du dépôt. Il commence la ligne, jamais au milieu.
BANDEAU = re.compile(r"^#\s*(-{3,}|={3,})")


def fichiers() -> list[str]:
    """Les fichiers Python du corpus, hors exclusions, chemins relatifs à la racine."""
    suivis = corpus_fichiers("*.py")
    return sorted(f for f in suivis if f and not f.startswith(EXCLUS))


def _prose_des_commentaires(source: str) -> tuple[list[str], bool]:
    """Le texte de chaque commentaire, plus un drapeau de lecture réussie.

    Deux commentaires éloignés dans le fichier sont séparés par une ligne vide. Sans elle, le
    dernier mot de l'un se recolle au premier de l'autre, et la phrase ainsi fabriquée passe
    pour trop longue. Des commentaires qui se suivent restent collés, eux, parce qu'ils forment
    bel et bien un paragraphe.

    Un fichier illisible rend le drapeau à faux. L'appelant l'affiche, au lieu de laisser croire
    à un score de zéro qui voudrait dire conforme.
    """
    lignes = []
    precedente = None
    try:
        for jeton in tokenize.generate_tokens(io.StringIO(source).readline):
            if jeton.type != tokenize.COMMENT:
                continue
            texte = jeton.string.lstrip("#").strip()
            if not texte or PRAGMAS.match(texte):
                continue
            numero = jeton.start[0]
            if precedente is not None and numero > precedente + 1:
                lignes.append("")
            lignes.append(texte)
            precedente = numero
    except (tokenize.TokenError, IndentationError, SyntaxError) as erreur:
        print(f"  ⚠️  illisible, non mesuré : {erreur}", file=sys.stderr)
        return lignes, False
    return lignes, True


def _prose_dune_docstring(doc: str) -> list[str]:
    """Les lignes de prose d'une docstring, exemples et doctests retirés.

    L'indentation marque l'exemple, par convention dans ce dépôt comme dans la plupart. Une
    ligne indentée de quatre espaces ou plus est du code montré, l'équivalent du bloc encadré
    d'un Markdown. La compter reviendrait à reprocher à un exemple d'être du code.
    """
    return [
        ligne for ligne in doc.splitlines()
        if not re.match(r"^\s{4,}\S", ligne) and not ligne.strip().startswith(">>>")
    ]


def _prose_des_docstrings(source: str) -> list[str]:
    """Toutes les docstrings du fichier, module, classes et fonctions comprises.

    Chacune est séparée de la suivante par une ligne vide, pour la même raison que les
    commentaires. Deux docstrings sont deux textes, jamais un seul paragraphe.
    """
    lignes = []
    try:
        arbre = ast.parse(source)
    except SyntaxError:
        return lignes
    porteurs = (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)
    for noeud in ast.walk(arbre):
        if not isinstance(noeud, porteurs):
            continue
        doc = ast.get_docstring(noeud)
        if doc:
            if lignes:
                lignes.append("")
            lignes.extend(_prose_dune_docstring(doc))
    return lignes


def _mute_son_argument(fonction: ast.AST, parametres: set[str]) -> bool:
    """Vrai si la fonction affecte un champ ou un attribut de l'un de ses paramètres."""
    for noeud in ast.walk(fonction):
        if not isinstance(noeud, ast.Assign):
            continue
        for cible in noeud.targets:
            racine = cible
            while isinstance(racine, (ast.Subscript, ast.Attribute)):
                racine = racine.value
            if isinstance(racine, ast.Name) and racine.id in parametres and racine is not cible:
                return True
    return False


def _rend_une_valeur(fonction: ast.AST) -> bool:
    """Vrai si la fonction porte au moins un retour non vide."""
    return any(isinstance(n, ast.Return) and n.value is not None for n in ast.walk(fonction))


def _rattrapage_muet(gestionnaire: ast.ExceptHandler) -> bool:
    """Vrai si le rattrapage ne fait rien du tout.

    Le compteur est PLUS ÉTROIT que la règle, et c'est voulu. La règle veut une trace à chaque
    rattrapage. Un « except ValueError: return None » n'en laisse aucune, et reste pourtant un
    choix légitime, lisible dans sa brièveté. Compter ceux-là noierait le vrai signal.

    On ne retient donc que le rattrapage qui n'exécute rien, celui que l'audit du 2026-08-05
    recommandait déjà d'interdire.

    Une action attendue reste une action. Un premier jet cherchait un appel au ras du corps, et
    manquait « await message.reply_text(…) », où l'appel est enveloppé dans une attente.
    """
    def inerte(noeud: ast.AST) -> bool:
        if isinstance(noeud, ast.Pass):
            return True
        return isinstance(noeud, ast.Expr) and isinstance(noeud.value, ast.Constant)

    return all(inerte(noeud) for noeud in gestionnaire.body)


def _sections_trop_longues(source: str) -> int:
    """Le nombre de tronçons de plus de LIGNES_MAX_FICHIER lignes sans aucun bandeau.

    C'est la règle « un fichier long porte un bandeau par section », rendue comptable. On ne sait
    pas découper un fichier en sections, mais on sait mesurer la distance entre deux repères. Le
    défaut que l'audit du 2026-08-05 décrivait était exactement celui-là, mille cinq cents lignes
    de routes à la file sans un seul repère visuel.
    """
    lignes = source.splitlines()
    if len(lignes) <= LIGNES_MAX_FICHIER:
        return 0
    reperes = [0]
    reperes += [i for i, ligne in enumerate(lignes) if BANDEAU.match(ligne)]
    reperes.append(len(lignes))
    return sum(1 for debut, fin in zip(reperes, reperes[1:]) if fin - debut > LIGNES_MAX_FICHIER)


def _ecarts_de_structure(source: str) -> dict:
    """Les quatre règles que l'outil sait compter. Les trois autres rendent None.

    C1, C2 et C4 ne se comptent pas. Aucun programme ne distingue un commentaire qui explique du
    pourquoi d'un commentaire qui répète sa ligne, ni deux logiques jumelles écrites autrement.
    Elles rendent None, jamais zéro, parce qu'un zéro se lirait comme une conformité.
    """
    ecarts = {"C1": None, "C2": None, "C3": 0, "C4": None,
              "C5": 0, "C6": _sections_trop_longues(source), "C7": 0}
    try:
        arbre = ast.parse(source)
    except SyntaxError:
        return ecarts
    for noeud in ast.walk(arbre):
        if isinstance(noeud, ast.ExceptHandler) and _rattrapage_muet(noeud):
            ecarts["C7"] += 1
        if not isinstance(noeud, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        if noeud.end_lineno - noeud.lineno + 1 > LIGNES_MAX_FONCTION:
            ecarts["C5"] += 1
        parametres = {a.arg for a in noeud.args.args}
        if _mute_son_argument(noeud, parametres) and _rend_une_valeur(noeud):
            ecarts["C3"] += 1
    return ecarts


def mesurer(rel: str) -> dict:
    """Les écarts à l'étalon dans un fichier Python, la prose d'abord, la structure ensuite."""
    source = (RACINE / rel).read_text(encoding="utf-8")
    commentaires, lisible = _prose_des_commentaires(source)
    docstrings = _prose_des_docstrings(source)
    # La ligne vide empêche le dernier commentaire de se recoller à la première docstring.
    prose = commentaires + [""] + docstrings if commentaires and docstrings else \
        commentaires + docstrings
    ecarts = mesurer_prose("\n".join(prose), lignes=prose)
    volume = sum(1 for ligne in prose if ligne.strip())
    return {"fichier": rel, "lignes_de_prose": volume, "lisible": lisible, **ecarts,
            "structure": _ecarts_de_structure(source)}


REGLES = ("C1", "C2", "C3", "C4", "C5", "C6", "C7")


def main() -> None:
    cibles = sys.argv[1:] or fichiers()
    mesures = sorted((mesurer(f) for f in cibles), key=lambda m: -m["score"])
    colonnes = "".join(f"{r:>4}" for r in REGLES)
    print(f"{'fichier':<40}{'PROSE':>6}   {colonnes}")
    for m in mesures:
        structure = "".join(
            f"{'-' if m['structure'][r] is None else m['structure'][r]:>4}" for r in REGLES
        )
        marque = "" if m["lisible"] else "   (illisible)"
        print(f"{m['fichier']:<40}{m['score']:>6}   {structure}{marque}")
    conformes = sum(1 for m in mesures if m["score"] == 0)
    print(f"\n{len(mesures)} fichier(s) — prose cumulée {sum(m['score'] for m in mesures)} "
          f"— conformes {conformes}/{len(mesures)}")
    for regle in REGLES:
        total = sum(m["structure"][regle] or 0 for m in mesures)
        if any(m["structure"][regle] is not None for m in mesures):
            print(f"  {regle} : {total} écart(s)")
    print("  C1, C2 et C4 ne se comptent pas. L'audit nocturne et la relecture les regardent.")
    print("  Seule la colonne PROSE refuse un commit, par le contrôle 12 du doc-lint.")


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        # Sortie tronquée par un « head » ou un « less ». Ce n'est pas une panne de la mesure.
        sys.stderr.close()
