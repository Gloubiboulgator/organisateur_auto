#!/usr/bin/env python3
"""L'étalon de rédaction, mesuré. UN seul endroit, deux appelants.

Le texte qui fait foi est le bloc `sync:etalon-redaction` de docs/etalons-de-redaction.md.
Ce module l'implémente. Deux outils s'en servent, et c'est la raison de son existence.

- `doc-mesure.py` mesure la prose des fichiers Markdown.
- `code-mesure.py` mesure la prose des commentaires et des docstrings.

Les commentaires sont de la prose. Ils obéissent donc au même étalon, sans qu'une règle soit
réinventée. Recopier ce calcul dans le second outil aurait créé deux vérités pour une seule
règle, ce que le dépôt combat partout ailleurs.

Les constantes restent lisibles depuis `doc-mesure.py` par simple import. Le contrôle « étalon écrit et mesuré » du
doc-lint les y cherche comme attributs de module, et un nom importé en est un.
"""
from __future__ import annotations

import re

# Les valeurs de l'étalon, nommées pour que le contrôle 10 du doc-lint puisse les confronter au
# TEXTE qui fait foi. Sans cette confrontation, changer 25 en 30 ici laisserait la doc dire
# autre chose, sans un bruit.
MOTS_MAX = 25                        # au-delà, la phrase est comptée comme trop longue
SIGNES_INTERDITS = (";", "→", "&")   # nulle part en prose
TIRETS_MAX = 1                       # incises « — » par ligne
PHRASES_PAR_PARAGRAPHE_MAX = 4       # au-delà, le paragraphe est compté comme dense


def decouper_en_phrases(texte: str) -> list[str]:
    """Les phrases d'un texte de prose, une par élément.

    Une puce ou un titre sans point final n'est PAS la suite du paragraphe suivant. On coupe
    donc aussi sur les lignes vides et sur les débuts de puce ou de titre. Sans ça, une liste
    entière compte pour une seule phrase géante. Faux positif corrigé au fil du terrain.

    Un point suivi d'un guillemet fermant ne coupe pas. La citation française met la ponctuation
    DEDANS, et couper là fabriquait une phrase commençant par « » ». Le compte enflait d'une
    unité par citation, ce que le critère de densité amplifie.

    LIMITE ASSUMÉE. Une citation qui se termine en milieu de phrase colle donc la suite à
    elle-même, et le compte descend d'une unité. Sous-compter est le sens prudent pour un
    contrôle qui refuse un commit.
    """
    blocs = re.split(r"\n\s*\n|\n(?=\s*(?:[-*+]|\d+\.|#{1,6}|>)\s)", texte)
    return [
        phrase for bloc in blocs
        for phrase in re.split(r"(?<=[.!?])(?!\s*»)\s+", re.sub(r"\s+", " ", bloc).strip())
        if phrase
    ]


def decouper_en_paragraphes(texte: str) -> list[str]:
    """Les paragraphes de prose d'un texte, une par élément.

    Un paragraphe est un bloc entre deux lignes vides. Une puce, une citation n'en sont pas :
    elles portent leur propre rythme, et une liste est justement le remède au pavé.

    LA DÉCOUPE EST CELLE DES PHRASES, et ce n'est pas un détail. Couper sur les seules lignes
    vides comptait deux fautes symétriques, trouvées en exécution par /code-review.

    Une amorce suivie sans ligne vide de quatre puces formait UN bloc de cinq phrases. C'était
    donc un pavé, alors que la liste est le remède annoncé. Et un titre collé à un pavé de six
    phrases faisait tomber le bloc entier, puisqu'il commençait par un marqueur.

    Un titre n'annule donc plus la prose qui le suit : on retire la ligne de titre, et on mesure
    ce qui reste.
    """
    blocs = re.split(r"\n\s*\n|\n(?=\s*(?:[-*+]|\d+\.|#{1,6}|>)\s)", texte)
    out = []
    for bloc in blocs:
        # Un titre porte son propre rythme, la prose qui le suit non. On pèle les lignes de
        # titre en tête, puis on juge le reste.
        bloc = re.sub(r"\A(?:\s*#{1,6} [^\n]*\n?)+", "", bloc)
        if bloc.strip() and not re.match(r"^\s*(?:[-*+]|\d+\.|#{1,6}|>)\s", bloc):
            out.append(bloc.strip())
    return out


def mesurer_prose(texte: str, lignes: list[str] | None = None) -> dict:
    """Compte les écarts à l'étalon dans un texte DÉJÀ réduit à sa prose.

    L'appelant a retiré ce qui n'est pas de la prose, blocs de code et tableaux côté Markdown,
    lignes de code d'exemple côté docstrings. Ce module ne sait pas de quel langage vient le
    texte, et c'est voulu.

    La règle des incises se compte PAR LIGNE, donc sur des lignes que l'appelant peut vouloir
    fournir lui-même. Côté Markdown, retirer les commentaires HTML recolle deux lignes en une,
    ce qui fausserait le compte. L'appelant passe alors ses lignes d'origine.

    Les clés rendues portent leur sens en toutes lettres, l'appelant les affiche telles quelles.
    """
    if lignes is None:
        lignes = texte.splitlines()
    phrases = decouper_en_phrases(texte)
    ecarts = {
        "point_virgule": texte.count(SIGNES_INTERDITS[0]),
        "fleche": texte.count(SIGNES_INTERDITS[1]),
        "esperluette": len(re.findall(r"&(?!\w+;)", texte)),
        "tirets": sum(1 for ligne in lignes if ligne.count("—") > TIRETS_MAX),
        "phrases_longues": sum(1 for p in phrases if len(p.split()) > MOTS_MAX),
        "paragraphes_denses": sum(
            1 for p in decouper_en_paragraphes(texte)
            if len(decouper_en_phrases(p)) > PHRASES_PAR_PARAGRAPHE_MAX),
    }
    ecarts["score"] = (
        ecarts["point_virgule"] + ecarts["fleche"] + ecarts["esperluette"]
        + ecarts["tirets"] * 2 + ecarts["phrases_longues"] * 2
        + ecarts["paragraphes_denses"] * 2
    )
    return ecarts
