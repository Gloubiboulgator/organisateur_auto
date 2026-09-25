#!/usr/bin/env python3
"""Où sont les blocs de code d'un Markdown. UN seul endroit, plusieurs appelants.

Un lien, un terme ou un signe qui vit dans un bloc de code montre une forme. Il ne vaut pas
comme emploi de prose. Trois contrôles avaient donc besoin de la même réponse, et chacun
l'écrivait à sa façon.

Deux le faisaient par une expression régulière, un par un drapeau ligne à ligne. Un même
fichier pouvait alors compter comme du code ici, et comme de la prose là.

La règle de découpe est celle du contrôle 3, la plus ancienne du dépôt. Une ligne dont le
premier caractère non blanc ouvre trois accents graves bascule l'état. Les deux délimiteurs
appartiennent au bloc.

Deux sorties, parce que les appelants n'ont pas le même besoin.

- `hors_code` retire les lignes de code. À employer quand la position n'importe pas.
- `masquer_code` les remplace par des espaces. À employer quand une position trouvée ici sera
  reportée dans le texte d'origine.

Le contrôle 3 garde sa propre boucle, et c'est voulu. Il accumule les blocs partagés en
même temps qu'il suit les délimiteurs. Il doit garder les lignes de code qui vivent DANS un
bloc partagé. Le sortir d'ici demanderait de lui rendre un état, pas un texte.
"""
from __future__ import annotations


def _drapeaux(txt: str) -> list[bool]:
    """Pour chaque ligne, dit si elle appartient à un bloc de code, délimiteurs compris."""
    dedans, out = False, []
    for ligne in txt.splitlines(keepends=True):
        delimiteur = ligne.lstrip().startswith("```")
        out.append(dedans or delimiteur)
        if delimiteur:
            dedans = not dedans
    return out


def hors_code(txt: str) -> str:
    """Le texte sans ses blocs de code. Les positions ne sont PAS conservées."""
    lignes = txt.splitlines(keepends=True)
    return "".join(l for l, code in zip(lignes, _drapeaux(txt)) if not code)


def masquer_code(txt: str) -> str:
    """Le texte dont les blocs de code deviennent des espaces. Les positions sont conservées.

    Le retour à la ligne est gardé, tout le reste devient une espace. Sans ça, une position
    trouvée dans le texte masqué désignerait un autre caractère dans l'original.
    """
    sortie = []
    for ligne, code in zip(txt.splitlines(keepends=True), _drapeaux(txt)):
        if not code:
            sortie.append(ligne)
            continue
        sortie.append("".join(" " if c != "\n" else "\n" for c in ligne))
    return "".join(sortie)
