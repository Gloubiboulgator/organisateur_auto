"""La page du parcours, et son encart des écarts.

POURQUOI CE FICHIER EXISTE
--------------------------
L'encart des écarts s'affichait sans dire ce qu'il était, et l'admin a dû le demander le
2026-11-16. Les écarts portent depuis une sorte, et la page les regroupe. Un parcours écrit avant
ce tri garde des écarts sans sorte, qui doivent rester lisibles.
"""
import importlib.util
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "rendre_parcours.py"
_spec = importlib.util.spec_from_file_location("rendre_parcours", SCRIPT)
R = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(R)

PARCOURS = {
    "sections": [{"id": "S1", "titre": "Départ"}],
    "ecrans": [{"id": "E1", "section": "S1", "titre": "Accueil", "ce_qu_on_y_voit": "Un titre.",
                "source": "a.js:1"},
               {"id": "E2", "section": "S1", "titre": "Jeu « vrai »", "source": "b.js:2"}],
    "transitions": [{"de": "E1", "vers": "E2", "geste": 'Toucher "Jouer"', "condition": ""}],
    "ecarts": [{"sorte": "hors-spec", "texte": "Un cul-de-sac."}, "Un écart d'avant le tri."],
}


def test_les_ecarts_se_regroupent_par_sorte_et_les_anciens_restent():
    page = R.rendre(PARCOURS)
    assert "Le code fait ce qu'aucune spec ne dit" in page
    assert "Non triés" in page and "Un écart d&#x27;avant le tri." in page
    assert page.index("Le code fait") < page.index("Non triés")


def test_l_encart_dit_ce_qu_il_contient():
    assert "Ce que l'agent a trouvé en confrontant le code aux specs" in R.rendre(PARCOURS)


def test_aucun_champ_du_gabarit_ne_reste():
    assert "{{" not in R.rendre(PARCOURS)


def test_un_guillemet_double_ne_casse_pas_le_logigramme():
    code = R.logigramme_section(PARCOURS, PARCOURS["sections"][0], None)
    assert '"' not in code.split('|"')[1].split('"|')[0]
