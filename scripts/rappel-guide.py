#!/usr/bin/env python3
"""rappel-guide.py — nomme, au commit, ce que le guide HTML du projet explique et que le commit touche.

POURQUOI CE RAPPEL. Un guide qui apprend le projet porte des explications rédigées. Quand une
mécanique change, son explication peut devenir fausse sans que rien ne le signale. Le rappel
le dit au seul moment où l'auteur sait ce qu'il vient de changer.

CE QU'IL NE FAIT PAS, et c'est voulu. Il ne bloque rien, n'écrit rien et ne revient pas au
commit suivant. Relire le guide est un geste humain.

S'il n'est plus juste, une ligne se note dans guide/backlog.md, et cette ligne n'est jamais une
urgence. La règle vit dans docs/systeme-documentaire.md.

CE QU'IL LIT. La section « Ce que le guide explique » de guide/backlog.md. Une ligne par motif,
au format « - `scripts/garde-*.sh` : les gardes ». Sans ce fichier, le projet n'a pas encore
de guide, et le rappel se tait.

IL SE TAIT AUSSI quand le commit touche déjà un fichier de guide/. La relecture a eu lieu.

Usage :  python3 scripts/rappel-guide.py [racine]
Lancé par scripts/githooks/pre-commit, en fin de course, sans pouvoir le faire échouer.
"""
import fnmatch
import pathlib
import re
import subprocess
import sys

BACKLOG = 'guide/backlog.md'
SECTION = 'ce que le guide explique'
ETATS = {'A': 'ajouté', 'M': 'modifié', 'D': 'retiré', 'R': 'renommé'}


def motifs(racine):
    """Les couples (motif, partie du guide) déclarés dans le backlog du guide."""
    fichier = racine / BACKLOG
    if not fichier.is_file():
        return []
    sortie, dedans = [], False
    for ligne in fichier.read_text(encoding='utf-8').splitlines():
        if ligne.startswith('## '):
            dedans = ligne[3:].strip().lower() == SECTION
            continue
        m = re.match(r'^- `([^`]+)`\s*:\s*(.+)$', ligne) if dedans else None
        if m:
            sortie.append((m.group(1), m.group(2).strip()))
    return sortie


def indexes():
    """Les chemins que le commit emporte, avec leur état."""
    lignes = subprocess.run(['git', 'diff', '--cached', '--name-status'], check=True,
                            capture_output=True, text=True).stdout.splitlines()
    return [(l.split('\t')[0], l.split('\t')[-1]) for l in lignes if '\t' in l]


def main(argv):
    racine = pathlib.Path(argv[1] if len(argv) > 1 else '.')
    declares = motifs(racine)
    if not declares:
        return 0
    touches = indexes()
    if any(chemin.startswith('guide/') for _, chemin in touches):
        return 0
    trouves = []
    for etat, chemin in touches:
        partie = next((p for motif, p in declares if fnmatch.fnmatch(chemin, motif)), None)
        if partie:
            trouves.append(f'  {chemin} ({ETATS.get(etat[:1], "changé")}), côté guide : {partie}')
    if trouves:
        print('Le guide HTML explique ce que ce commit touche. À relire quand on a le temps, et '
              f'à noter dans {BACKLOG} si le guide n’est plus juste :', file=sys.stderr)
        print('\n'.join(trouves), file=sys.stderr)
    return 0


if __name__ == '__main__':
    # UN RAPPEL NE FAIT JAMAIS ÉCHOUER UN COMMIT. Toute panne se tait, et le commit suit son cours.
    try:
        sys.exit(main(sys.argv))
    except Exception:
        sys.exit(0)
