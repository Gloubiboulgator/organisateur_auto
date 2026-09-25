#!/usr/bin/env python3
"""Mesure la conformité de la doc au format lisible (docs/etalons-de-redaction.md § Écrire
lisible). Outil de SUIVI du chantier de refonte, pas un garde-fou : il n'échoue jamais et ne
bloque aucun commit. Le garde-fou est le contrôle 7 du doc-lint. Il exige un score de 0
de TOUT fichier, sauf ceux inscrits à la dette de scripts/dette-doc.txt.

Ce qui est compté, hors blocs de code et hors tableaux :

- « ; », « → », « & » en prose (interdits, un signe un rôle)
- les lignes portant plus d'un « — »
- les phrases de plus de 25 mots (l'étalon vise une idée par phrase, ~15 mots)
- les paragraphes de plus de 4 phrases (l'étalon vise trois phrases, de l'air entre les idées)
- le dépassement de la longueur cible du fichier

Le score agrège ces six mesures pour classer les fichiers par effort restant. Il descend à
mesure que le chantier avance.

    python3 scripts/doc-mesure.py           # tout le corpus, trié par score
    python3 scripts/doc-mesure.py README.md # un ou plusieurs fichiers
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from corpus import fichiers as corpus_fichiers  # noqa: E402

RACINE = Path(__file__).resolve().parent.parent

# L'étalon lui-même vit à côté, dans etalon_prose.py, et sert AUSSI à code-mesure.py. Les
# commentaires sont de la prose, ils obéissent aux mêmes règles. Recopier le calcul ici en
# aurait fait deux vérités pour une seule règle. Le chemin est posé à la main parce que le
# contrôle 10 du doc-lint charge ce fichier par son emplacement, hors de tout paquet.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from etalon_prose import (  # noqa: E402
    MOTS_MAX, PHRASES_PAR_PARAGRAPHE_MAX, SIGNES_INTERDITS, TIRETS_MAX, mesurer_prose,
)

# Longueurs cibles de l'étalon. Le CHANGELOG (append-only) et les archives sont hors chantier.
# UNE DISPENSE PASSE PAR LA DETTE, JAMAIS PAR UNE LISTE À PART. Un fichier scripts/cibles-locales.json
# redéfinissait ici la cible de longueur, fichier par fichier. Il n'entrait dans aucune empreinte,
# aucun contrôle ne le lisait, et rien n'empêchait la liste de grandir. C'était donc une liste
# d'autorisés sans garde, exactement ce que le dépôt a tranché deux fois contre. Les fichiers
# trop longs se dispensent par scripts/dette-doc.txt et son jumeau local, qui portent les trois
# contrôles solidaires 7, 8 et 9.
CIBLE_SPEC, CIBLE_DECISION, CIBLE_AUTRE = 300, 150, 300

# MOTS_MAX, PHRASES_PAR_PARAGRAPHE_MAX, SIGNES_INTERDITS et TIRETS_MAX sont importés d'etalon_prose ci-dessus. Le contrôle
# « étalon écrit et mesuré » du doc-lint les cherche comme attributs de ce module, et un nom importé en est un.
EXCLUS = ("docs/archives/", "CHANGELOG.md")


def cible(rel: str) -> int:
    if rel.startswith("specs/"):
        return CIBLE_SPEC
    if "decisions/" in rel:
        return CIBLE_DECISION
    return CIBLE_AUTRE


def fichiers() -> list[str]:
    suivis = corpus_fichiers("*.md")
    return sorted(f for f in suivis if f and not f.startswith(EXCLUS))


def mesurer(rel: str) -> dict:
    lignes = (RACINE / rel).read_text(encoding="utf-8").splitlines()
    prose, dans_code = [], False
    # Un en-tête YAML entre deux lignes « --- » porte des métadonnées, pas de la prose.
    corps = lignes
    # Un « --- » suivi d'une CLÉ ouvre un en-tête. Suivi d'autre chose, il sépare deux parties,
    # et tout ce qui suivait disparaissait alors de la mesure, en silence.
    entete = len(lignes) > 1 and lignes[0].strip() == "---" and re.match(r"[A-Za-z_][\w.-]* *:", lignes[1])
    if entete and "---" in (l.strip() for l in lignes[1:]):
        corps = lignes[next(i for i, l in enumerate(lignes[1:], 1) if l.strip() == "---") + 1:]
    # Une ligne retirée laisse une ligne VIDE à sa place, jamais un trou. Les supprimer
    # recollait deux paragraphes que seul un bloc de code ou un tableau séparait.
    # Le compteur de paragraphes denses y voyait un pavé, et refusait une prose correcte.
    for ligne in corps:
        if ligne.strip().startswith("```"):
            dans_code = not dans_code
            prose.append("")
            continue
        if dans_code or ligne.strip().startswith("|"):
            prose.append("")  # les tableaux ont leur ponctuation, l'étalon ne les vise pas
            continue
        prose.append(ligne)
    texte = "\n".join(prose)
    # Les commentaires HTML ne sont pas de la prose. Les recoller à la phrase suivante
    # gonflait le compte de mots. On n'écrit pas ici de marqueur littéral de bloc partagé,
    # parce que le contrôle 3 le lirait comme un vrai.
    texte = re.sub(r"<!--.*?-->", " ", texte, flags=re.S)
    # Les incises se comptent sur les lignes D'ORIGINE : la substitution ci-dessus recolle deux
    # lignes en une quand un commentaire HTML s'étend sur plusieurs, ce qui fausserait le compte.
    ecarts = mesurer_prose(texte, lignes=prose)
    d = {
        "f": rel,
        "n": len(lignes),
        "cible": cible(rel),
        "pv": ecarts["point_virgule"],
        "fleche": ecarts["fleche"],
        "et": ecarts["esperluette"],
        "tirets": ecarts["tirets"],
        "longues": ecarts["phrases_longues"],
        "denses": ecarts["paragraphes_denses"],
    }
    # Au score de prose s'ajoute le dépassement de longueur, qui ne concerne que les fichiers.
    d["score"] = ecarts["score"] + max(0, d["n"] - d["cible"]) // 25
    return d


def main() -> None:
    cibles = sys.argv[1:] or fichiers()
    res = sorted((mesurer(f) for f in cibles), key=lambda d: -d["score"])
    print(f"{'fichier':<52}{'lig':>5}{'cib':>5}{';':>4}{'→':>4}{'&':>4}{'—×2':>5}{'ph>25':>6}{'par>4':>6}{'SCORE':>7}")
    for d in res:
        print(f"{d['f']:<52}{d['n']:>5}{d['cible']:>5}{d['pv']:>4}{d['fleche']:>4}"
              f"{d['et']:>4}{d['tirets']:>5}{d['longues']:>6}{d['denses']:>6}{d['score']:>7}")
    conformes = sum(1 for d in res if d["score"] == 0)
    print(f"\n{len(res)} fichier(s) — score cumulé {sum(d['score'] for d in res)} "
          f"— conformes {conformes}/{len(res)}")


if __name__ == "__main__":
    main()
