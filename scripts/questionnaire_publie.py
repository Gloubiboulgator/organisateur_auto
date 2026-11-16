#!/usr/bin/env python3
"""Ce que porte le tableau QUESTIONS d'un questionnaire sur le point d'être envoyé à l'admin.

UN seul lecteur, quatre gardes. `garde-options-sans-cas.sh` et `garde-questions-illisibles.sh`
lisaient chacun la page à sa façon, par des expressions régulières. La revue du 2026-10-14 y a
trouvé sept lectures fausses, toutes reproduites sur le modèle de page.

- Une clé entre guillemets, ou `code` hors de la première place, et l'option n'était pas lue.
- Une accolade dans un champ coupait l'option avant son `gagneSi`.
- Une valeur entre apostrophes ou entre accents graves comptait comme absente.
- Une apostrophe dans un commentaire `//` déréglait le comptage, jusqu'au bout du fichier.
- Les titres des options étaient jugés comme ceux des questions.
- Les deux gardes ne trouvaient pas la fin du tableau de la même façon.

Ce lecteur découpe le JavaScript en jetons, chaînes et commentaires compris, puis lit le
tableau comme une valeur. Les deux gardes des cartes jugent ainsi la même chose.

`garde-lecture-a-froid.sh` en prend `pages_envoyees`, `est_questionnaire` et la lecture des
retouches du même message. `garde-revue-de-conception.sh` y ajoute `porte_un_choix`, pour ne
juger que les pages qui portent une carte à choisir.

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

UN QUESTIONNAIRE ILLISIBLE SE DIT. Une page qui déclare VALIDER et QUESTIONS, dont aucune
question ne se lit, sort une ligne qui commence par « ? ». Le garde des questions demande
alors confirmation, au lieu de laisser passer en silence.

Usage, depuis un garde : la charge du hook sur l'entrée, puis `options` ou `illisibles`. Une
faute par ligne en sortie, déjà échappée pour une chaîne JSON. Rien en sortie, rien à dire.
ÉCHOUE OUVERT : une charge illisible ne sort rien.
"""
from __future__ import annotations

import datetime
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


def est_questionnaire(texte: str) -> bool:
    """Vrai si la page déclare VALIDER et QUESTIONS, que son tableau se lise ou non."""
    return bool(_declarations(texte, "VALIDER") and _declarations(texte, "QUESTIONS"))


ILLISIBLE = "illisible"


def questions(texte: str) -> list[dict] | str | None:
    """Les questions de tous les tableaux QUESTIONS lisibles de la page.

    None si la page n'est pas un questionnaire. ILLISIBLE si elle en est un, mais qu'aucune
    question ne s'y lit. Des questions bâties par un appel en sont, le 2026-10-26.
    """
    if not _declarations(texte, "VALIDER"):
        return None
    debuts = _declarations(texte, "QUESTIONS")
    if not debuts:
        return None
    qs = []
    for debut in debuts:
        try:
            lu = _Lecteur(jetons(texte, debut))
            tableau = _tableau(lu) if lu.voir() == ("signe", "[") else []
        except Illisible:
            continue
        qs += [q for q in tableau if isinstance(q, dict) and "id" in q]
    return qs or ILLISIBLE


SCRIPT = re.compile(r"<script\b[^>]*>(.*?)</script\s*>", re.S | re.I)


def porte_un_choix(texte: str) -> bool:
    """Vrai si une carte de la page peut être à choisir. Le doute compte comme un choix.

    Les cartes ne se lisent pas toutes dans le tableau QUESTIONS. Un étalement, un `push` ou une
    fonction qui bâtit la carte y échappent. Chaque clé `options` des scripts de la page se lit
    donc, où qu'elle soit. La page ne porte que des textes à valider si toutes valent VALIDER.

    Une carte lisible sans `options` est un choix, comme pour estChoix du modèle et pour
    `questions_illisibles`.
    """
    for script in SCRIPT.findall(texte):
        try:
            flux = list(jetons(script, 0))
        except Illisible:
            return True
        for i, (sorte, valeur) in enumerate(flux):
            if valeur != "options" or sorte not in ("nom", "chaine") or i == 0:
                continue
            # Une clé d'objet suit une accolade ou une virgule. Ailleurs, « options » est une
            # chaîne ou une variable, comme la classe CSS du modèle.
            if flux[i - 1] not in (("signe", "{"), ("signe", ",")):
                continue
            suite = flux[i + 1:i + 3]
            if suite and suite[0] == ("signe", ":"):
                if suite[1:] != [("nom", "VALIDER")]:
                    return True
            elif sorte == "nom" and suite and suite[0] in (("signe", ","), ("signe", "}")):
                return True
    qs = questions(texte)
    if qs == ILLISIBLE:
        return True
    return any(not (isinstance(q.get("options"), Nom) and q["options"].nom == "VALIDER")
               for q in qs or [])


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


# LES RETOUCHES FAITES DANS LE MÊME MESSAGE QU'UN APPEL D'AGENT.
# Les deux gardes de relecture comparent l'heure de l'appel à la dernière écriture de la page.
# Une retouche lancée dans le même message, juste avant l'appel, peut porter une heure plus
# tardive. Ce qui suit dit si une telle retouche a laissé la page telle que l'agent l'a lue.
#
# OBSERVÉ le 2026-11-07, sur la transcription d'un run de ramasser-pr. Chaque appel d'outil d'un
# message a sa propre entrée, qui porte l'identifiant du message. Les appels s'y suivent dans
# l'ordre, chacun après le retour du précédent. Le retour d'une retouche y datait de trois
# millisecondes après l'écriture du fichier.
RETOUCHES = ("Write", "Edit", "MultiEdit", "NotebookEdit")


def heure(entree: dict) -> float | None:
    """L'heure d'une entrée du journal, en secondes, ou None si elle n'en porte pas."""
    try:
        return datetime.datetime.fromisoformat(entree["timestamp"].replace("Z", "+00:00")).timestamp()
    except Exception:
        return None


def retouches_reussies(lignes: list[str], cwd: str) -> list[tuple]:
    """Les retouches de fichier réussies : (ligne, bloc, message, chemin réel, heure du retour).

    UN FILTRE DE TEXTE PASSE AVANT LE DÉCODAGE. Seules se décodent les lignes qui nomment un
    outil de retouche, ou l'identifiant d'une retouche qui attend son retour. Une image du
    journal ne coûte donc qu'une recherche de texte.
    """
    attente, faites = {}, []
    noms = tuple(f'"{nom}"' for nom in RETOUCHES)
    for n, ligne in enumerate(lignes):
        if not any(nom in ligne for nom in noms) and not any(i in ligne for i in attente):
            continue
        try:
            e = json.loads(ligne)
        except Exception:
            continue
        if not isinstance(e, dict) or e.get("isSidechain"):
            continue
        message = e.get("message") if isinstance(e.get("message"), dict) else {}
        contenu = message.get("content")
        for k, bloc in enumerate(contenu if isinstance(contenu, list) else []):
            if not isinstance(bloc, dict):
                continue
            if e.get("type") == "assistant" and bloc.get("type") == "tool_use" \
                    and bloc.get("name") in RETOUCHES and isinstance(bloc.get("id"), str):
                entree = bloc.get("input") or {}
                f = entree.get("file_path") or entree.get("notebook_path")
                if isinstance(f, str):
                    attente[bloc["id"]] = (n, k, message.get("id"), os.path.realpath(os.path.join(cwd, f)))
            elif bloc.get("type") == "tool_result" and bloc.get("tool_use_id") in attente:
                place = attente.pop(bloc["tool_use_id"])
                if bloc.get("is_error") is not True:
                    faites.append((*place, heure(e)))
    return faites


def retouchee_dans_le_message(faites: list[tuple], place: tuple, mid, page: str, fin, ecrite: float) -> bool:
    """Vrai si une retouche de la page, dans le même message et avant l'appel, couvre la relecture.

    La retouche doit avoir réussi, et son retour dater d'après la dernière écriture de la page.
    Rien ne l'a donc changée depuis, ni un outil lancé en parallèle, ni un échec.

    Le retour de l'appel doit dater, lui aussi, d'après la page. Le journal arrondit à la
    milliseconde, d'où la marge.

    UNE HEURE DE FICHIER À LA SECONDE NE PROUVE RIEN. Un montage réseau en rend parfois. Une
    écriture plus tardive, dans la même seconde, s'y cacherait derrière la retouche.
    """
    if mid is None or fin is None or fin + 0.001 < ecrite or ecrite == int(ecrite):
        return False
    page = os.path.realpath(page)
    return any((i, k) < place and m == mid and f == page and h is not None and h + 0.001 >= ecrite
               for i, k, m, f, h in faites)


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
