#!/usr/bin/env python3
"""Ce que porte le tableau QUESTIONS d'un questionnaire sur le point d'être envoyé à l'admin.

UN seul lecteur, deux gardes. `garde-options-sans-cas.sh` et `garde-questions-illisibles.sh`
lisaient chacun la page à sa façon, par des expressions régulières. La revue du 2026-10-14 y a
trouvé sept lectures fausses, toutes reproduites sur le modèle de page.

- Une clé entre guillemets, ou `code` hors de la première place, et l'option n'était pas lue.
- Une accolade dans un champ coupait l'option avant son `gagneSi`.
- Une valeur entre apostrophes ou entre accents graves comptait comme absente.
- Une apostrophe dans un commentaire `//` déréglait le comptage, jusqu'au bout du fichier.
- Les titres des options étaient jugés comme ceux des questions.
- Les deux gardes ne trouvaient pas la fin du tableau de la même façon.

Ce lecteur découpe le JavaScript en jetons, chaînes et commentaires compris, puis lit le
tableau comme une valeur. Les deux gardes jugent ainsi la même chose.

CE QUI EST UN QUESTIONNAIRE. Une page HTML qui déclare VALIDER et QUESTIONS, comme le modèle.
Un quiz de jeu qui n'a que QUESTIONS n'est pas jugé.

Chaque déclaration de QUESTIONS qui se lit est jugée, celles d'un commentaire comprises. Un
brouillon commenté ne masque donc pas le vrai.

CE QUI EST ENVOYÉ. Tout appel Artifact qui porte une page, sauf les actions qui ne publient
rien, plus ses pages jointes par `files`. Puis les pages d'un SendUserFile, la voie de repli
que la règle prévoit sans Artifact.

UNE VALEUR QU'IL NE SAIT PAS CALCULER NE COMPTE NI POUR PRÉSENTE NI POUR ABSENTE. Une
constante, un gabarit à substitution ou un calcul se taisent. `null`, `undefined` et `false`,
eux, sont des absences.

UN QUESTIONNAIRE ILLISIBLE SE DIT. Une page qui déclare VALIDER et QUESTIONS, dont aucun
tableau ne se lit, sort une ligne qui commence par « ? ». Le garde des questions demande
alors confirmation, au lieu de laisser passer en silence.

Usage, depuis un garde : la charge du hook sur l'entrée, puis `options` ou `illisibles`. Une
faute par ligne en sortie, déjà échappée pour une chaîne JSON. Rien en sortie, rien à dire.
ÉCHOUE OUVERT : une charge illisible ne sort rien.
"""
from __future__ import annotations

import json
import os
import re
import sys


class Illisible(Exception):
    """Le tableau ne se lit pas jusqu'au bout. Le garde se tait plutôt que de deviner."""


class Nom:
    """Un nom JavaScript nu, comme `VALIDER`. Jamais confondu avec une chaîne du même texte."""

    def __init__(self, nom: str):
        self.nom = nom


class Inconnu:
    """Une valeur que ce lecteur ne calcule pas : constante, substitution, appel ou calcul."""


INCONNU = Inconnu()


def _html(chemin, base: str) -> str | None:
    """Le chemin absolu d'une source HTML, ou None. Un chemin relatif part de base."""
    if isinstance(chemin, dict):
        chemin = chemin.get("from")
    if not isinstance(chemin, str) or not chemin.endswith(".html"):
        return None
    return os.path.join(base, chemin)


# Les actions Artifact qui ne publient aucune page. Une action neuve est jugée d'emblée.
SANS_PUBLICATION = ("read", "list", "delete", "open", "pin", "unpin", "quickstart")


def pages_envoyees(charge: dict) -> list[str]:
    """Les pages HTML que cet appel publie ou envoie à l'admin."""
    ti = charge.get("tool_input")
    if not isinstance(ti, dict):
        return []
    cwd = charge.get("cwd") if isinstance(charge.get("cwd"), str) else os.getcwd()
    if charge.get("tool_name") == "SendUserFile":
        fichiers = ti.get("files") if isinstance(ti.get("files"), list) else []
        return [p for p in (_html(f, cwd) for f in fichiers) if p]
    if charge.get("tool_name") != "Artifact":
        return []
    if ti.get("action") in SANS_PUBLICATION or ti.get("asset"):
        return []
    sources = [ti.get("file_path")]
    racine = os.path.join(cwd, ti["root"]) if isinstance(ti.get("root"), str) else cwd
    joints = ti.get("files")
    if isinstance(joints, dict):
        sources += [(s, racine) for s in joints.values()]
    elif isinstance(joints, list):
        sources += [(j.get("path"), racine) for j in joints if isinstance(j, dict)]
    pages = [_html(s, cwd) if not isinstance(s, tuple) else _html(*s) for s in sources]
    return [p for p in pages if p]


def _fin_de_chaine(texte: str, i: int) -> int:
    """La position après la chaîne qui s'ouvre en i. Saute d'un échappement à l'autre."""
    fin = texte[i]
    motif = re.compile(r"[\\`]|\$\{" if fin == "`" else r"[\\" + fin + "]")
    i += 1
    while True:
        m = motif.search(texte, i)
        if not m:
            raise Illisible("chaîne jamais fermée")
        if m.group(0) == "\\":
            i = m.end() + 1
        elif m.group(0) == "${":
            i = _fin_de_substitution(texte, m.end())
        else:
            return m.end()


def _fin_de_substitution(texte: str, i: int) -> int:
    """La position après le `}` qui ferme une substitution `${`, chaînes imbriquées comprises."""
    profondeur = 1
    while profondeur:
        jeton = _jeton(texte, i)
        if jeton is None:
            raise Illisible("substitution jamais fermée")
        sorte, valeur, i = jeton
        if (sorte, valeur) == ("signe", "{"):
            profondeur += 1
        elif (sorte, valeur) == ("signe", "}"):
            profondeur -= 1
    return i


def _contenu(brut: str) -> str:
    """Le texte d'une chaîne lue entre ses deux délimiteurs, échappements résolus."""
    if "\\" not in brut:
        return brut
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)),
                  brut, flags=re.S)


def _jeton(texte: str, i: int):
    """Le jeton suivant à partir de i, en (sorte, valeur, position après), ou None à la fin."""
    while i < len(texte):
        c = texte[i]
        if c.isspace():
            i += 1
        elif texte.startswith("//", i):
            fin = texte.find("\n", i)
            i = len(texte) if fin < 0 else fin
        elif texte.startswith("/*", i):
            fin = texte.find("*/", i + 2)
            if fin < 0:
                raise Illisible("commentaire jamais fermé")
            i = fin + 2
        elif c in "\"'`":
            fin = _fin_de_chaine(texte, i)
            brut = texte[i + 1:fin - 1]
            if c == "`" and "${" in brut:
                return "gabarit", None, fin
            return "chaine", _contenu(brut), fin
        elif c.isalnum() or c in "_$":
            m = re.compile(r"[\w$.]+").match(texte, i)
            return "nom", m.group(0), m.end()
        else:
            return "signe", c, i + 1
    return None


def jetons(texte: str, i: int):
    """Les jetons du JavaScript à partir de i, en (sorte, valeur)."""
    while (jeton := _jeton(texte, i)) is not None:
        sorte, valeur, i = jeton
        yield sorte, valeur


class _Lecteur:
    """Un flux de jetons qu'on peut regarder avant de le prendre."""

    def __init__(self, flux):
        self.flux, self.tete = flux, next(flux, None)

    def voir(self):
        if self.tete is None:
            raise Illisible("fin du texte avant la fin du tableau")
        return self.tete

    def prendre(self, attendu: str | None = None):
        jeton = self.voir()
        if attendu is not None and jeton != ("signe", attendu):
            raise Illisible(f"attendu {attendu}, lu {jeton[1]}")
        self.tete = next(self.flux, None)
        return jeton


def _expression(lu: _Lecteur):
    """Une valeur qui n'est ni objet ni tableau. Des chaînes jointes par + donnent leur texte."""
    morceaux, profondeur = [], 0
    while True:
        sorte, v = lu.voir()
        if sorte == "signe" and v in ",}]" and profondeur == 0:
            break
        if sorte == "signe" and v in "([{":
            profondeur += 1
        elif sorte == "signe" and v in ")]}":
            profondeur -= 1
        morceaux.append(lu.prendre())
    if len(morceaux) == 1 and morceaux[0][0] == "nom":
        nom = morceaux[0][1]
        if nom in ("null", "undefined", "false"):
            return None
        return nom if re.fullmatch(r"\d[\d.]*", nom) else Nom(nom)
    if len(morceaux) % 2 and all(s == "chaine" for s, _ in morceaux[::2]) \
            and all(j == ("signe", "+") for j in morceaux[1::2]):
        return "".join(v for _, v in morceaux[::2])
    return INCONNU


def _valeur(lu: _Lecteur):
    sorte, v = lu.voir()
    if (sorte, v) == ("signe", "{"):
        return _objet(lu)
    if (sorte, v) == ("signe", "["):
        return _tableau(lu)
    return _expression(lu)


def _objet(lu: _Lecteur) -> dict:
    """Un objet littéral. Les clés calculées, les méthodes et les étalements sont sautés."""
    lu.prendre("{")
    objet = {}
    while lu.voir() != ("signe", "}"):
        sorte, cle = lu.voir()
        if sorte in ("chaine", "nom"):
            lu.prendre()
            if lu.voir() == ("signe", ":"):
                lu.prendre(":")
                objet[cle] = _valeur(lu)
            elif lu.voir() in (("signe", ","), ("signe", "}")):
                objet[cle] = Nom(cle)
            else:
                _expression(lu)
        else:
            _expression(lu)
        if lu.voir() == ("signe", ","):
            lu.prendre(",")
        elif lu.voir() != ("signe", "}"):
            raise Illisible("objet mal fermé")
    lu.prendre("}")
    return objet


def _tableau(lu: _Lecteur) -> list:
    lu.prendre("[")
    elements = []
    while lu.voir() != ("signe", "]"):
        if lu.voir() == ("signe", ","):
            lu.prendre(",")
            continue
        elements.append(_valeur(lu))
        if lu.voir() == ("signe", ","):
            lu.prendre(",")
        elif lu.voir() != ("signe", "]"):
            raise Illisible("tableau mal fermé")
    lu.prendre("]")
    return elements


DECLARE = re.compile(r"\b(?:const|let|var)\s+$")
EGAL = re.compile(r"\s*=")


def _declarations(texte: str, nom: str) -> list[int]:
    """Les positions après chaque `const NOM =` du texte.

    Le nom se cherche d'abord, puis son entourage. Une expression qui part de chaque position
    du texte prenait une demi-seconde sur une image de huit mégaoctets.
    """
    positions, i = [], texte.find(nom)
    while i >= 0:
        egal = EGAL.match(texte, i + len(nom))
        if egal and DECLARE.search(texte, max(0, i - 40), i):
            positions.append(egal.end())
        i = texte.find(nom, i + 1)
    return positions


ILLISIBLE = "illisible"


def questions(texte: str) -> list[dict] | str | None:
    """Les questions de tous les tableaux QUESTIONS lisibles de la page.

    None si la page n'est pas un questionnaire. ILLISIBLE si elle en est un, mais qu'aucun de
    ses tableaux ne se lit.
    """
    if not _declarations(texte, "VALIDER"):
        return None
    qs, rate = [], False
    for debut in _declarations(texte, "QUESTIONS"):
        try:
            lu = _Lecteur(jetons(texte, debut))
            tableau = _tableau(lu) if lu.voir() == ("signe", "[") else []
        except Illisible:
            rate = True
            continue
        qs += [q for q in tableau if isinstance(q, dict) and "id" in q]
    if not qs:
        return ILLISIBLE if rate else None
    return qs


def nom_de(q: dict) -> str:
    """L'identifiant d'une question tel qu'il se cite dans un refus."""
    return q["id"] if isinstance(q["id"], str) else "?"


def options_sans_cas(qs: list[dict]) -> list[str]:
    """Chaque option à choisir qui ne dit pas, en douze signes au moins, quand elle gagne."""
    fautes = []
    for q in qs:
        options = q.get("options")
        if not isinstance(options, list):
            continue
        for o in options:
            if not isinstance(o, dict):
                continue
            cas = o.get("gagneSi")
            if isinstance(cas, (Nom, Inconnu)):
                continue
            if not (isinstance(cas, str) and len(cas.strip()) >= 12):
                code = o.get("code") if isinstance(o.get("code"), str) else "?"
                fautes.append(nom_de(q) + "-" + code)
    return fautes


# Ce qui trahit la langue du dépôt dans une carte. A3 à A5 et MP3, MP4 sont des mots courants.
INTERDITS = [
    (r"\b(?!(?:A[345]|MP[34])\b)[A-Z]{1,4}\d{1,3}\b", "sigle"),
    (r"#\d+", "numéro d issue"),
    (r"\b[\w.-]+\.(?:md|js|mjs|json|jsonl|html|css|sh|py)\b", "nom de fichier"),
    (r"`", "accent grave de code"),
    (r"mcp__", "nom d outil"),
]


def questions_illisibles(qs: list[dict]) -> list[str]:
    """Une question à choisir sans scène, ou dont le titre, le « quand » ou la scène parle code.

    Seuls les champs de la question sont lus. Les titres des options n'en font pas partie.
    """
    fautes = []
    for q in qs:
        options = q.get("options")
        choix = not (isinstance(options, Nom) and options.nom == "VALIDER")
        scene = q.get("scene")
        if choix and not isinstance(scene, (Nom, Inconnu)) \
                and not (isinstance(scene, str) and len(scene.strip()) >= 40):
            fautes.append(nom_de(q) + " sans scène d'au moins quarante signes")
        for champ in ("titre", "quand", "scene"):
            valeur = q.get(champ)
            if not isinstance(valeur, str):
                continue
            for motif, nom in INTERDITS:
                trouve = re.search(motif, valeur)
                if trouve:
                    fautes.append(f"{nom_de(q)} {champ} : {nom} « {trouve.group(0)} »")
    return fautes


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    juge = {"options": options_sans_cas, "illisibles": questions_illisibles}.get(mode)
    try:
        charge = json.load(sys.stdin)
        pages = pages_envoyees(charge) if juge and isinstance(charge, dict) else []
    except Exception:
        return
    for chemin in pages:
        try:
            with open(chemin, encoding="utf-8") as f:
                qs = questions(f.read())
        except Exception:
            continue
        nom = os.path.basename(chemin)
        if qs == ILLISIBLE:
            if mode == "illisibles":
                print("?" + json.dumps(nom, ensure_ascii=False)[1:-1])
            continue
        prefixe = nom + " " if len(pages) > 1 else ""
        for faute in (juge(qs) if qs else []):
            print(json.dumps(prefixe + faute, ensure_ascii=False)[1:-1])


if __name__ == "__main__":
    main()
