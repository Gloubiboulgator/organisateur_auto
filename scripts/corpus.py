#!/usr/bin/env python3
"""Le corpus que les contrôles regardent. UN seul endroit, tous les appelants.

Un contrôle qui ne voit pas un fichier ne le juge pas, et rend vert. Le corpus décide donc de
ce qui est vérifié, et il vivait à douze endroits, trois scripts et neuf sites du doc-lint.

CE QUE LE CORPUS EST, PAR DÉFAUT. L'index, ce que `git ls-files` rend. C'est exactement ce que
le hook de pre-commit matérialise en scène, donc ce qu'un commit emporte.

Un fichier jamais indexé n'y est donc pas, et l'appel À LA MAIN retarde d'un `git add`.
Constaté : une note neuve employait un terme du glossaire sans lien, et le doc-lint lancé à la
main est resté vert jusqu'à son indexation.

CE RETARD NE LAISSE RIEN PASSER, et c'est pourquoi il n'est pas comblé par défaut. Committer un
fichier, c'est l'indexer, donc le verrou du commit le voit toujours. Seul l'aperçu ment, en
sous-déclarant.

POURQUOI LE COMBLER PAR DÉFAUT SERAIT PIRE. La scène du hook recopie les fichiers non suivis,
pour d'autres contrôles qui en ont besoin. Balayer les non-suivis y ferait juger l'arbre de
travail, et un brouillon jamais indexé refuserait des commits qui ne le touchent pas.

Mesuré sur un projet neuf, noyau posé. Un `docs/brouillon.md` jamais indexé refusait le commit
du seul README. Le corpus par défaut, lui, le laisse passer.

L'APERÇU HONNÊTE RESTE POSSIBLE, à la demande. `CORPUS_NEUFS=1` ajoute les fichiers neufs que
git n'ignore pas, pour qui veut voir ce que dira le commit d'après.

    CORPUS_NEUFS=1 bash scripts/doc-lint.sh

Usage en ligne de commande, pour le shell du doc-lint. La sortie est terminée par un zéro, à
l'identique de `git ls-files -z`, et se lit donc avec les mêmes idiomes.

LE SÉPARATEUR EST UN ZÉRO, ET PAS UNE ESPACE. Sans lui, git cite « docs/étape.md » en octets
échappés, le fichier devient introuvable, et le contrôle plante au lieu de mesurer.

    python3 scripts/corpus.py '*.md'
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent


def fichiers(motif: str = "", racine: Path | None = None,
             neufs: bool | None = None) -> list[str]:
    """Les fichiers de l'index, plus les fichiers neufs quand on les demande.

    `--others` rend ce que git ne suit pas encore, et `--exclude-standard` retire ce que le
    .gitignore écarte. Sans le second, un dossier de dépendances entrerait dans le corpus.

    Le `--` sépare les options du motif. Sans lui, un motif ouvrant par un tiret se lirait
    comme une option, et git refuserait la commande.
    """
    if neufs is None:
        neufs = os.environ.get("CORPUS_NEUFS", "") not in ("", "0")
    cmd = ["git", "-C", str(racine or RACINE), "ls-files", "-z", "--cached"]
    if neufs:
        cmd += ["--others", "--exclude-standard"]
    if motif:
        cmd += ["--", motif]
    # ON LIT DES OCTETS, PAS DU TEXTE. Un nom de fichier n'est pas forcément de l'UTF-8, et
    # `text=True` levait alors une exception là où les pipelines shell étaient transparents.
    # Mesuré : la recherche de prénoms passait de 118 correspondances à zéro, contrôle vert.
    # `surrogateescape` rend les octets illisibles à l'encodage, sans jamais perdre le chemin.
    brut = subprocess.check_output(cmd).decode("utf-8", "surrogateescape")
    # Le « if f » n'est pas décoratif. La sortie finit par un zéro, donc la découpe laisse une
    # chaîne VIDE, qui passe startswith et fait ouvrir la racine du dépôt.
    # Le dédoublonnage vise les stades non fusionnés, qu'un index en conflit répète.
    return sorted({f for f in brut.split("\0") if f})


# Un plantage sort en 2, JAMAIS en 1. Le contrôle des prénoms du doc-lint blanchit 0, 1 et 123,
# les trois états nominaux de son grep à travers xargs.
#
# Une trace Python nue sort en 1, donc elle passait pour un « aucun prénom trouvé » sans qu'un
# seul fichier ait été lu. L'ancien « git ls-files » sortait en 128, que le garde attrapait.
# Reproduit avant correctif.
PANNE = 2


def main() -> None:
    motif = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        noms = fichiers(motif)
    except (subprocess.CalledProcessError, OSError) as e:
        sys.stderr.write(f"corpus : la liste des fichiers est inconnue ({e})\n")
        raise SystemExit(PANNE) from e
    # Les octets ressortent tels qu'ils sont entrés, sans repasser par un encodage strict.
    sys.stdout.buffer.write(b"".join(n.encode("utf-8", "surrogateescape") + b"\0"
                                     for n in noms))


if __name__ == "__main__":
    main()
