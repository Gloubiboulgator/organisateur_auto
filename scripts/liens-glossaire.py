#!/usr/bin/env python3
"""Liens vers le glossaire : lister ceux qui manquent, ou les poser.

La règle qu'il sert vit dans `docs/etalons-de-redaction.md`, section « Écrire une fiche
technique ». Dans une doc, le premier emploi d'un terme du glossaire porte un lien.

CE QUE CET OUTIL MESURE, ET CE QU'IL NE MESURE PAS. Il vérifie qu'un terme employé dans un
fichier y est lié AU MOINS UNE FOIS. Il ne vérifie pas que c'est le PREMIER emploi qui porte
le lien, ce qui demanderait de comparer des positions.

Un terme de plusieurs mots coupé par un retour à la ligne lui échappe aussi, parce qu'il
cherche dans le texte ligne à ligne. Ces deux trous sont connus et assumés, pas des oublis. Le
libellé du contrôle dit ce qui est mesuré.

TOUT TERME DU GLOSSAIRE COMPTE, avec ou sans fiche. Le périmètre a d'abord été limité aux
termes à fiche, au motif qu'un lien doit mener à une explication.

Le cas fondateur a montré le trou : une roadmap employait « spike » et « répétition espacée » sans un mot. Le glossaire les
définissait, et rien ne rougissait. Une entrée brève est déjà une explication.

Cible acceptée pour le lien, au choix de l'auteur.

- l'entrée du glossaire, toujours
- la fiche elle-même, plus précise, quand le terme en a une

Le garde-fou est le contrôle 17 du doc-lint, qui lance ce script. Il REFUSE LE COMMIT dès qu'un
terme du glossaire est employé sans jamais être lié. Cette page a longtemps dit l'inverse, « il
n'échoue jamais » : un agent qui la lisait croyait n'avoir affaire qu'à un indicateur.

Le script, lui, ne décide rien. Il liste, et il pose sur demande.

    python3 scripts/liens-glossaire.py                      # tout le corpus, ce qui manque
    python3 scripts/liens-glossaire.py docs/x.md            # un ou plusieurs fichiers
    python3 scripts/liens-glossaire.py --lint               # une ligne par manque, rien d'autre
    python3 scripts/liens-glossaire.py --poser docs/x.md    # pose les liens manquants
"""
from __future__ import annotations

import os
import re
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from corpus import fichiers as corpus_fichiers  # noqa: E402
from blocs_markdown import hors_code, masquer_code  # noqa: E402

RACINE = Path(__file__).resolve().parent.parent
GLOSSAIRE = "docs/comprendre/glossaire.md"
# Le glossaire est la cible, pas un client. Le journal et les archives citent le passé.
EXCLUS = (GLOSSAIRE, "CHANGELOG.md", "docs/archives/")


def fichiers_du_noyau() -> tuple[str, ...]:
    """Les fichiers que le projet n'a PAS le droit de modifier.

    Sans cette exclusion, un terme du glossaire employé par la doc du noyau rendait le contrôle
    rouge sur des fichiers figés. Le seul remède aurait été de les éditer, ce que le contrôle
    anti-dérive dénonce ensuite comme un bricolage. Le projet se retrouvait sans issue.

    La liste vient de `.noyau-empreintes`, écrit par l'installateur. Absent, il n'y a pas de
    noyau posé, et rien à exclure.
    """
    empreintes = RACINE / ".noyau-empreintes"
    try:
        lignes = empreintes.read_text(encoding="utf-8").splitlines()
    except OSError:
        return ()
    return tuple(
        l.split("  ", 1)[1] for l in lignes
        if l and not l.startswith("#") and "  " in l
    )


def sans_accent(s: str) -> str:
    """Plie casse et accents. Sert à COMPARER des termes, la longueur n'y importe pas."""
    s = unicodedata.normalize("NFD", s.lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def plier(s: str) -> str:
    """Même pliage, mais caractère par caractère, donc à LONGUEUR CONSTANTE.

    Indispensable dès qu'on reporte vers le texte d'origine une position trouvée ici. Cas
    vécu : le sélecteur de variante des emoji est une marque Unicode, que le pliage effaçait.
    Un caractère de moins, et tous les liens suivants coupaient les mots en deux.
    """
    out = []
    for c in s:
        plie = sans_accent(c)
        out.append(plie[0] if plie else " ")
    return "".join(out)


SECTION_ENTREES = "Les entrées"


def section_des_entrees(txt: str) -> str:
    """La seule partie du glossaire où une puce en gras est un TERME.

    Le périmètre s'est élargi à tout terme du glossaire, à fiche ou non. Le test « l'entrée
    porte-t-elle un lien de fiche » tombait alors, et il servait AUSSI de marqueur d'entrée.

    Sans remplaçant, n'importe quelle puce en gras du fichier devenait un terme à lier partout,
    y compris une note de maintenance. Trouvé en exécution par /code-review.

    Le titre « Les entrées » reprend ce rôle, et le gabarit du glossaire le pose. Un glossaire
    qui ne le porte pas est lu en ENTIER, faute de mieux.

    Ce repli garde donc le défaut, toute puce en gras y devenant un terme. Il est choisi quand
    même : rendre zéro terme mettrait le contrôle 17 au vert sans rien avoir lu, ce qui est pire.
    Le remède tient en une ligne, poser le titre dans son glossaire.
    """
    lignes = txt.splitlines()
    for i, ligne in enumerate(lignes):
        titre = re.match(r"^(#{1,6}) +(.*?) *$", ligne)
        # Le titre se compare EN ENTIER. Sur une sous-chaîne, un titre d'introduction comme
        # « Comment lire les entrées » gagnait la course au premier trouvé.
        # Le glossaire rendait alors zéro terme, et le contrôle 17 passait au vert.
        if not titre or sans_accent(titre.group(2)) != sans_accent(SECTION_ENTREES):
            continue
        niveau = len(titre.group(1))
        for j, suite in enumerate(lignes[i + 1:], i + 1):
            suivant = re.match(r"^(#{1,6}) +", suite)
            if suivant and len(suivant.group(1)) <= niveau:
                return "\n".join(lignes[i + 1:j])
        return "\n".join(lignes[i + 1:])
    return txt


def termes() -> dict[str, str]:
    """Les termes du glossaire : forme normalisée vers la cible du lien.

    La cible est la fiche quand l'entrée en porte une, sinon le glossaire lui-même. Un projet
    sans glossaire rend un dictionnaire vide, et tout le reste devient sans objet. C'est l'état
    normal d'un dépôt neuf.
    """
    source = RACINE / GLOSSAIRE
    if not source.exists():
        return {}
    out = {}
    # Un exemple de format vit dans un bloc de code. Le lire en ferait un vrai terme.
    for ligne in section_des_entrees(hors_code(source.read_text(encoding="utf-8"))).splitlines():
        if not ligne.startswith("- **"):
            continue
        fiche = re.search(r"\]\((fiches-techniques/[a-z0-9-]+\.md)\)", ligne)
        cible = os.path.dirname(GLOSSAIRE) + "/" + fiche.group(1) if fiche else GLOSSAIRE
        for part in re.split(r"\s*/\s*|,", ligne[2:].split("**")[1]):
            part = re.sub(r"\(.*?\)", "", re.sub(r"[`«»]", "", part)).strip()
            if len(part) >= 3:
                # Le dossier vient de GLOSSAIRE. Le réécrire ici ferait deux vérités, et
                # déplacer le glossaire fabriquerait des chemins de fiche faux, en silence.
                out.setdefault(sans_accent(part), cible)
    return out


def est_entete_yaml(lignes: list[str]) -> bool:
    """Un « --- » en tête ouvre-t-il un en-tête YAML, ou sépare-t-il juste deux parties ?

    Le seul test du « --- » prenait une barre de séparation pour un en-tête. Tout ce qui suit
    jusqu'au « --- » suivant disparaissait alors de la mesure, en silence.

    La ligne d'après tranche : un en-tête YAML y porte une clé, une séparation n'en porte pas.
    """
    if len(lignes) < 2 or lignes[0].strip() != "---":
        return False
    return bool(re.match(r"[A-Za-z_][\w.-]* *:", lignes[1]))


def masquer_yaml(txt: str) -> str:
    """Neutralise l'en-tête YAML d'un fichier, à longueur constante.

    Un en-tête entre deux lignes « --- » porte des MÉTADONNÉES, pas de la prose. `doc-mesure.py`
    le reconnaît déjà comme tel, et le sautait. Ce script, non.

    Un terme du glossaire employé dans le `description:` d'un SKILL.md rendait donc le contrôle
    17 rouge sans geste correct possible. Pire, `--poser` y écrivait un lien Markdown, dans le
    champ même qui déclenche le skill. Trouvé en exécution par /code-review.
    """
    lignes = txt.split("\n")
    if not est_entete_yaml(lignes):
        return txt
    for i, ligne in enumerate(lignes[1:], 1):
        if ligne.strip() == "---":
            # Les positions sont sacrées ici : tout appelant reporte vers le texte d'origine.
            tete = ["" if not l else " " * len(l) for l in lignes[:i + 1]]
            return "\n".join(tete + lignes[i + 1:])
    return txt


def masquer(txt: str) -> str:
    """Neutralise ce qui ne compte pas comme un emploi de prose.

    Les blocs de code, le code en ligne et les liens déjà posés, évidemment. Mais aussi les
    titres et le gras. Un lien glissé dans un titre casse ce que d'autres contrôles y lisent.

    TROU CONNU, ET IL VIENT DE LÀ. Le gras ne sert PAS qu'aux titres : le corpus l'emploie en
    pleine prose pour marquer une notion. Un terme dont le premier emploi est en gras est donc
    invisible au contrôle, qui va lier le deuxième. Le mesurer demanderait de distinguer un gras
    de titre d'un gras de prose, ce que le masquage ne sait pas faire.
    """
    # Le masquage DOIT conserver les positions. On remplace caractère par caractère, jamais
    # par une chaîne plus courte. Les retours à la ligne sont gardés, et le reste devient une
    # espace.
    #
    # Cas vécu : un bloc de code réduit à ses seuls retours à la ligne décalait tout ce qui
    # suivait. Les liens coupaient alors les mots en deux.
    txt = masquer_yaml(txt)
    txt = masquer_code(txt)
    txt = re.sub(r"`[^`\n]*`", lambda m: " " * len(m.group()), txt)
    txt = re.sub(r"\[[^\]\n]*\]\([^)\n]*\)", lambda m: " " * len(m.group()), txt)
    txt = re.sub(r"^#{1,6} .*$", lambda m: " " * len(m.group()), txt, flags=re.M)
    # Un bloc synchronisé vit à l'identique dans plusieurs fichiers, à des profondeurs
    # différentes. Aucun lien relatif ne peut y être juste partout, et le contrôle 3 refuserait
    # la moindre divergence. On n'y demande donc aucun lien.
    txt = re.sub(r"<!--\s*sync:[a-z0-9-]+\s*-->.*?<!--\s*/sync:[a-z0-9-]+\s*-->",
                 lambda m: re.sub(r"[^\n]", " ", m.group()), txt, flags=re.S)
    txt = re.sub(r"\*\*[^*\n]+\*\*", lambda m: " " * len(m.group()), txt)
    return txt


def deja_lie(txt: str, terme: str, fiche: str) -> bool:
    """Un lien dont le TEXTE contient le terme et la CIBLE est le glossaire ou sa fiche."""
    cible = Path(fiche).name
    for m in re.finditer(r"\[([^\]\n]*)\]\(([^)\n]*)\)", txt):
        texte, url = sans_accent(m.group(1)), m.group(2)
        if terme in texte and ("glossaire.md" in url or cible in url):
            return True
    return False


class Illisible(Exception):
    """Le fichier existe, mais ne se lit pas dans l'encodage attendu."""


def lire(rel: str) -> str:
    """Le texte d'un fichier, ou « Illisible ». LA garde de lecture, pour tous les appelants.

    Elle a d'abord vécu chez le seul lint, puis chez « manquants ». La pose gardait sa propre
    lecture, nue, avant d'appeler « manquants ». Elle mourait donc toujours sur une trace
    Python, devant un chemin absent comme devant un autre encodage.

    Le commentaire d'à côté annonçait pourtant le contraire. Une garde qu'un appelant contourne
    n'est pas une garde.
    """
    try:
        return (RACINE / rel).read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as e:
        raise Illisible(f"{rel} : illisible ({type(e).__name__})") from e


def manquants(rel: str, tous: dict[str, str]) -> list[tuple[int, str, str]]:
    """Les premiers emplois non liés d'un fichier, du plus haut au plus bas."""
    txt = lire(rel)
    visible = plier(masquer(txt))
    trouves = []
    for terme, fiche in tous.items():
        # Une fiche ne se renvoie pas à elle-même. Son sujet, c'est elle qui l'explique.
        if fiche == rel or deja_lie(txt, terme, fiche):
            continue
        m = re.search(r"(?<![\w-])" + re.escape(terme) + r"s?(?![\w-])", visible)
        if m:
            trouves.append((txt.count("\n", 0, m.start()) + 1, terme, fiche))
    return sorted(trouves)


def relatif_vers(depuis: str, vers: str) -> str:
    """Le chemin de la fiche, vu depuis le dossier du fichier qui la cite."""
    return os.path.relpath(vers, os.path.dirname(depuis))


def poser(rel: str, tous: dict[str, str]) -> int:
    """Enveloppe le premier emploi de chaque terme manquant dans un lien vers sa fiche."""
    chemin = RACINE / rel
    txt = lire(rel)
    pose = 0
    for _, terme, fiche in manquants(rel, tous):
        visible = plier(masquer(txt))
        m = re.search(r"(?<![\w-])" + re.escape(terme) + r"s?(?![\w-])", visible)
        if not m:
            continue
        mot = txt[m.start():m.end()]
        # Garde-fou : le mot enveloppé DOIT être le terme. Si les positions ont dérivé, on
        # refuse plutôt que de couper un mot en deux.
        if sans_accent(mot).rstrip("s") != terme.rstrip("s"):
            print(f"  {rel} : « {mot} » n'est pas « {terme} », lien NON posé", file=sys.stderr)
            continue
        relatif = relatif_vers(rel, fiche)
        txt = txt[:m.start()] + f"[{mot}]({relatif})" + txt[m.end():]
        pose += 1
    # Sans rien de posé, on ne réécrit pas. Une écriture inutile normaliserait les fins de
    # ligne en silence, et ferait mentir un « 0 lien posé ».
    if pose:
        chemin.write_text(txt, encoding="utf-8")
    return pose


def fichiers() -> list[str]:
    """Toute la doc du corpus, moins ce qui cite le passé.

    Le corpus vit dans scripts/corpus.py, qui porte aussi le pourquoi du séparateur zéro.
    """
    suivis = corpus_fichiers("*.md")
    figes = fichiers_du_noyau()
    return sorted(f for f in suivis
                  if f and not f.startswith(EXCLUS) and f not in figes)


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    tous = termes()
    cibles = args or fichiers()
    if "--lint" in sys.argv[1:]:
        # Sortie plate, une ligne par manque. C'est ce que lit le doc-lint.
        for rel in cibles:
            # Un fichier illisible se NOMME. Sans cette garde, un .md enregistré dans un
            # autre encodage faisait remonter une trace Python au doc-lint. Le nom du fautif
            # s'y cherchait à la main.
            try:
                manques = manquants(rel, tous)
            except Illisible as e:
                print(f"{e}, les liens n'ont pas pu être lus")
                continue
            for ligne, terme, fiche in manques:
                print(f"{rel}:{ligne} « {terme} » sans lien (fiche : {fiche})")
        return
    if "--poser" in sys.argv[1:]:
        # Une cible explicite est EXIGÉE. Sans elle, un seul appel réécrirait toute la doc du
        # dépôt, ce que la docstring ne laisse pas deviner.
        if not args:
            print("--poser exige un ou plusieurs fichiers", file=sys.stderr)
            raise SystemExit(1)
        for rel in cibles:
            try:
                print(f"{poser(rel, tous):>3} lien(s) posé(s) — {rel}")
            except Illisible as e:
                print(f"  — {e}")
        return
    total = 0
    for rel in cibles:
        try:
            trous = manquants(rel, tous)
        except Illisible as e:
            print(f"  — {e}")
            continue
        total += len(trous)
        if trous:
            print(f"\n{rel} — {len(trous)} lien(s) manquant(s)")
            for ligne, terme, fiche in trous:
                print(f"  l.{ligne:<5} {terme:<28} -> {fiche}")
    print(f"\n{len(cibles)} fichier(s) — {total} lien(s) manquant(s) "
          f"sur {len(tous)} termes du glossaire")


if __name__ == "__main__":
    main()
