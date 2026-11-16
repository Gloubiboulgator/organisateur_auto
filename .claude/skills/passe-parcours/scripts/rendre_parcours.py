#!/usr/bin/env python3
"""Rend le parcours modélisé en page HTML, un logigramme par section.

POURQUOI CE FICHIER EXISTE
--------------------------
Un parcours complet compte des dizaines d'écrans. Un seul logigramme de cette taille se lit
mal, et l'admin doit pourtant le valider écran par écran. La page découpe donc le parcours en
sections, chacune avec son logigramme, ses écrans et ses sorties vers les autres sections.

En tête, le logigramme d'un seul tenant se dessine dans la page, avec des filtres. Deux cent
trente liens d'un coup le rendaient illisible, vu par l'admin le 2026-11-16. On y masque des
sections, et un écran choisi ne montre que ses voisins.

La synthèse reprend la même page. Une couverture optionnelle colore chaque écran selon le nombre
de testeurs qui l'ont atteint, et marque ceux où un testeur a abandonné. Écrire deux pages à la
main aurait donné deux logigrammes qui divergent.

COMMENT ON S'EN SERT
--------------------
    python3 rendre_parcours.py parcours.json page.html
    python3 rendre_parcours.py parcours.json page.html --couverture couverture.json
La couverture se lit ainsi : {"testeurs": 6, "ecrans": {"E1": {"atteint": 6, "abandons": 0}}}.
"""
import argparse
import html
import json
from pathlib import Path

GABARIT = Path(__file__).resolve().parent.parent / "references" / "gabarit-parcours.html"


def libelle(texte):
    """Un libellé Mermaid sans guillemet double, qui casserait le rendu du logigramme."""
    return " ".join(str(texte).replace('"', "«").split())


def classe_couverture(couverture, ident):
    if not couverture:
        return None
    vu = couverture["ecrans"].get(ident, {})
    if vu.get("abandons"):
        return "abandon"
    atteint = vu.get("atteint", 0)
    if atteint == 0:
        return "jamais"
    return "tous" if atteint >= couverture["testeurs"] else "certains"


CLASSES = """    classDef ailleurs stroke-dasharray: 4 3,opacity:0.75
    classDef tous fill:#cfe8d6,stroke:#2b7a4b
    classDef certains fill:#fbefc4,stroke:#a77b00
    classDef jamais fill:#eceef3,stroke:#8a90a2,color:#5b6070
    classDef abandon fill:#f6d0cb,stroke:#b3261e,stroke-width:3px"""


def gestes_section(parcours, section):
    """Les gestes qui partent de la section, numérotés dans leur ordre d'écriture."""
    ici = {e["id"] for e in parcours["ecrans"] if e["section"] == section["id"]}
    return [(n, t) for n, t in enumerate((t for t in parcours["transitions"] if t["de"] in ici),
                                         start=1)]


def logigramme_section(parcours, section, couverture):
    """Le logigramme d'une section, avec ses sorties vers les autres en pointillé.

    Une flèche ne porte que les numéros de ses gestes. Le texte entier des gestes rendait le
    schéma illisible : trente-trois libellés sur une section, vu par l'admin le 2026-11-16.
    """
    ecrans = {e["id"]: e for e in parcours["ecrans"]}
    lignes = ["flowchart TD"]
    for ecran in (e for e in parcours["ecrans"] if e["section"] == section["id"]):
        lignes.append(f'    {ecran["id"]}["{ecran["id"]} · {libelle(ecran["titre"])}"]')
        classe = classe_couverture(couverture, ecran["id"])
        if classe:
            lignes.append(f"    class {ecran['id']} {classe}")
    fleches = {}
    for numero, t in gestes_section(parcours, section):
        cible = t["vers"]
        if ecrans.get(cible, {}).get("section") != section["id"]:
            cible = f"x_{t['vers']}"
        fleches.setdefault((t["de"], cible), []).append(str(numero))
    for (de, cible), numeros in fleches.items():
        if cible.startswith("x_") and f"    {cible}[" not in "\n".join(lignes):
            titre = libelle(ecrans.get(cible[2:], {}).get("titre", "?"))
            lignes.append(f'    {cible}["→ {cible[2:]} · {titre}"]:::ailleurs')
        lignes.append(f'    {de} -->|"{" · ".join(numeros)}"| {cible}')
    lignes.append(CLASSES)
    return "\n".join(lignes)


def table_gestes(parcours, section):
    lignes = "".join(
        f'<tr><td class="num">{n}</td><td><a href="#{html.escape(t["de"])}">'
        f'{html.escape(t["de"])}</a> → <a href="#{html.escape(t["vers"])}">'
        f'{html.escape(t["vers"])}</a></td><td>{html.escape(t["geste"])}</td>'
        f'<td>{html.escape(t.get("condition") or "")}</td></tr>'
        for n, t in gestes_section(parcours, section))
    return (f'<div class="tableau"><table><thead><tr><th>N°</th><th>De → vers</th>'
            f'<th>Geste</th><th>Condition</th></tr></thead><tbody>{lignes}</tbody></table></div>')


def carte_ecran(ecran):
    return (f'<li class="ecran" id="{html.escape(ecran["id"])}"><span class="ident">'
            f'{html.escape(ecran["id"])}</span><div><strong>{html.escape(ecran["titre"])}'
            f'</strong><p>{html.escape(ecran.get("ce_qu_on_y_voit", ""))}</p>'
            f'<code>{html.escape(ecran.get("source", ""))}</code></div></li>')


def bloc_section(parcours, section, couverture):
    ecrans = [e for e in parcours["ecrans"] if e["section"] == section["id"]]
    cartes = "\n".join(carte_ecran(e) for e in ecrans)
    return (f'<section class="section" id="{html.escape(section["id"])}">'
            f'<h2><span class="ident">{html.escape(section["id"])}</span> '
            f'{html.escape(section["titre"])} <small>{len(ecrans)} écrans</small></h2>'
            f'{ZOOM}<div class="schema"><pre class="mermaid">'
            f'{html.escape(logigramme_section(parcours, section, couverture))}</pre></div>'
            f'<details open><summary>Les gestes, par numéro</summary>'
            f'{table_gestes(parcours, section)}</details>'
            f'<details><summary>Les écrans de la section</summary><ul class="ecrans">'
            f'{cartes}</ul></details></section>')


ZOOM = ('<div class="zoom" role="group" aria-label="Zoom du logigramme">'
        '<button type="button" data-zoom="-1">−</button>'
        '<button type="button" data-zoom="0">Taille réelle</button>'
        '<button type="button" data-zoom="1">+</button></div>')


# Les sortes d'écarts, dans l'ordre de l'encart. Leur définition vit dans la consigne de la
# modélisation. Un écart sans sorte, écrit avant ce tri, tombe dans « Non triés ».
SORTES = {
    "promis-non-atteint": "La spec le promet, aucun geste n'y mène",
    "specs-contradictoires": "Des specs qui se contredisent",
    "hors-spec": "Le code fait ce qu'aucune spec ne dit",
    "version-testee": "La version testée diffère du code actuel",
}


def bloc_ecarts(ecarts):
    """Les écarts regroupés par sorte, une liste par sorte présente."""
    groupes = {}
    for ecart in ecarts:
        sorte, texte = ((ecart.get("sorte"), ecart.get("texte", "")) if isinstance(ecart, dict)
                        else (None, ecart))
        groupes.setdefault(sorte if sorte in SORTES else None, []).append(texte)
    blocs = []
    for sorte, titre in [*SORTES.items(), (None, "Non triés")]:
        if sorte in groupes:
            items = "".join(f"<li>{html.escape(t)}</li>" for t in groupes[sorte])
            blocs.append(f"<h3>{titre} <small>{len(groupes[sorte])}</small></h3><ul>{items}</ul>")
    return "\n".join(blocs) or "<p>Aucun.</p>"


def rendre(parcours, couverture=None, titre="Parcours", chapeau=""):
    sections = "\n".join(bloc_section(parcours, s, couverture) for s in parcours["sections"])
    version = parcours.get("version_modelisee", {})
    remplacements = {
        "{{titre}}": html.escape(titre), "{{chapeau}}": chapeau,
        "{{compte}}": (f'{len(parcours["sections"])} sections · {len(parcours["ecrans"])} écrans '
                       f'· {len(parcours["transitions"])} gestes'),
        "{{version}}": html.escape(f'{version.get("commit", "?")}, {version.get("raison", "")}'),
        "{{legende}}": "" if not couverture else LEGENDE,
        "{{sections}}": sections, "{{ecarts}}": bloc_ecarts(parcours.get("ecarts", [])),
        "{{donnees}}": json.dumps({"parcours": parcours, "couverture": couverture},
                                  ensure_ascii=False).replace("</", "<\\/"),
    }
    page = GABARIT.read_text(encoding="utf-8")
    for champ, valeur in remplacements.items():
        page = page.replace(champ, valeur)
    return page


LEGENDE = """<ul class="legende"><li><i class="tous"></i>atteint par tous</li>
<li><i class="certains"></i>atteint par certains</li><li><i class="jamais"></i>jamais atteint</li>
<li><i class="abandon"></i>un testeur y a abandonné</li></ul>"""


def principal():
    analyse = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    analyse.add_argument("parcours", type=Path)
    analyse.add_argument("page", type=Path)
    analyse.add_argument("--couverture", type=Path)
    analyse.add_argument("--titre", default="Parcours")
    analyse.add_argument("--chapeau", default="")
    args = analyse.parse_args()
    parcours = json.loads(args.parcours.read_text(encoding="utf-8"))
    couverture = None
    if args.couverture:
        couverture = json.loads(args.couverture.read_text(encoding="utf-8"))
    args.page.write_text(rendre(parcours, couverture, args.titre, args.chapeau), encoding="utf-8")


if __name__ == "__main__":
    principal()
