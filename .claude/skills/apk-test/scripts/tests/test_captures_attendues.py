"""Le seuil de captures, dérivé du parcours.

POURQUOI CE FICHIER EXISTE
--------------------------
Le plancher valait zéro image. Le run 32254733286 du projet d'origine en a rapporté neuf, sans
que rien ne sache combien il en fallait. `captures-attendues.py` dérive l'attendu du parcours.

Ces tests visent surtout le parseur, parce qu'un parseur qui se trompe en silence rendrait le
seuil faux sans qu'on le voie. Une forme non comprise doit donc être refusée, jamais devinée.
"""
import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

SKILL = Path(__file__).resolve().parent.parent.parent
SCRIPT = SKILL / "scripts" / "captures-attendues.py"
PARCOURS = SKILL / "references" / "ParcoursVisuelTest.kt"

# Le fichier porte un tiret, donc il n'est pas importable par son nom : on le charge par chemin.
_spec = importlib.util.spec_from_file_location("captures_attendues", SCRIPT)
_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_module)

noms_attendus = _module.noms_attendus
manquants = _module.manquants
RefusDExtraction = _module.RefusDExtraction


def _parcours(tmp_path: Path, corps: str) -> Path:
    """Un faux parcours minimal, pour éprouver le parseur sur une forme précise."""
    chemin = tmp_path / "Faux.kt"
    chemin.write_text(corps, encoding="utf-8")
    return chemin


# ── Le garde-fou du test lui-même ────────────────────────────────────────────────────────────

def test_l_extraction_lit_bien_le_gabarit():
    """S'il ne relève plus aucune capture, il ne prouve plus rien. Le gabarit du skill est le
    contrat du DSL : ce qu'il contient doit se lire, nom par nom."""
    avec = noms_attendus(PARCOURS, avec_jeton=True)
    sans = noms_attendus(PARCOURS, avec_jeton=False)
    assert avec == ["01-demarrage", "02-premier", "03-second", "04-creation",
                    "05-rebascule-tour1", "05-rebascule-tour2", "05-rebascule-tour3",
                    "00-accueil-non-appaire"]
    assert sans == ["00-accueil-non-appaire"], "le filet minimal sans jeton a disparu"


# ── Ce que le parseur doit savoir faire ──────────────────────────────────────────────────────

def test_une_boucle_repeat_est_depliee(tmp_path):
    """`repeat(3)` produit trois images, pas une. Un comptage des sites d'appel les manquerait."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() {
        repeat(3) { tour ->
            photographier("05-rebascule-tour${tour + 1}")
        }
    }
    """)
    assert noms_attendus(kt, avec_jeton=True) == [
        "05-rebascule-tour1", "05-rebascule-tour2", "05-rebascule-tour3"]


def test_les_captures_d_un_test_ignore_ne_comptent_pas(tmp_path):
    """Un test `@Ignore` porte des appels que rien ne joue. Les compter relèverait le seuil et
    ferait rougir tous les runs, jusqu'à ce que le garde-fou soit contourné."""
    kt = _parcours(tmp_path, """
    @Ignore("prémisse fausse")
    @Test
    fun clavier() {
        photographier("clavier-passe1")
    }

    @Test
    fun accueil() {
        photographier("00-accueil")
    }
    """)
    assert noms_attendus(kt, avec_jeton=True) == ["00-accueil"]


def test_un_test_conditionne_au_jeton_n_attend_rien_sans_lui(tmp_path):
    """Sans jeton, le parcours authentifié est sauté par `Assume`. Exiger ses images punirait une
    absence de configuration, pas un défaut de l'app."""
    kt = _parcours(tmp_path, """
    @Test
    fun authentifie() {
        Assume.assumeTrue("aucun jeton", jetonTest != null)
        photographier("02-annonces")
    }

    @Test
    fun libre() {
        photographier("00-accueil")
    }
    """)
    assert noms_attendus(kt, avec_jeton=False) == ["00-accueil"]
    assert noms_attendus(kt, avec_jeton=True) == ["02-annonces", "00-accueil"]


def test_le_nom_de_l_argument_du_jeton_est_reglable(tmp_path):
    """Un projet qui nomme son argument autrement doit garder le même comportement. Sans le
    réglage, son test authentifié serait exigé sans jeton, et rougirait à chaque run."""
    kt = _parcours(tmp_path, """
    @Test
    fun authentifie() {
        Assume.assumeTrue("aucun jeton", cleSession != null)
        photographier("02-annonces")
    }
    """)
    assert noms_attendus(kt, avec_jeton=False) == ["02-annonces"]
    assert noms_attendus(kt, avec_jeton=False, arg_jeton="cleSession") == []
    r = subprocess.run([sys.executable, str(SCRIPT), "lister", str(kt), "--arg-jeton", "cleSession"],
                       capture_output=True, text=True)
    assert r.returncode == 0 and r.stdout.strip() == ""


# ── Les commentaires ne sont pas du parcours ─────────────────────────────────────────────────

def test_un_appel_cite_en_commentaire_n_est_ni_compte_ni_refuse(tmp_path):
    """`// photographier(nom)` aurait fait rougir chaque run comme argument non littéral.
    `// photographier("fantome")` aurait exigé une image que rien ne produit."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() {
        // photographier(nom) serait plus propre
        photographier("01-vrai")   // photographier("fantome") était trop tôt
        /* photographier("dans-un-bloc") */
    }
    """)
    assert noms_attendus(kt, avec_jeton=True) == ["01-vrai"]


def test_un_commentaire_entre_test_et_fun_ne_fait_pas_disparaitre_le_test(tmp_path):
    """Toute ligne non vide remettait les annotations à zéro. Un commentaire entre `@Test` et
    `fun` sortait le test de l'attendu, et ses images avec, sans un mot."""
    kt = _parcours(tmp_path, """
    @Test
    // dure 77 s
    fun parcours() {
        photographier("01-vrai")
    }
    """)
    assert noms_attendus(kt, avec_jeton=True) == ["01-vrai"]


def test_un_commentaire_de_bloc_jamais_referme_est_refuse(tmp_path):
    """Une forme non comprise est un refus : un `/*` ouvert avalerait le reste du fichier."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() { /* ouvert
        photographier("01-vrai")
    }
    """)
    with pytest.raises(RefusDExtraction, match="jamais refermé"):
        noms_attendus(kt, avec_jeton=True)


def test_une_chaine_contenant_deux_barres_n_est_pas_un_commentaire(tmp_path):
    """`"https://…"` dans une chaîne n'ouvre pas de commentaire, sinon la fin de la ligne
    disparaîtrait, appel de capture compris."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() {
        charger("https://exemple.test"); photographier("01-vrai")
    }
    """)
    assert noms_attendus(kt, avec_jeton=True) == ["01-vrai"]


# ── Ce que le parseur doit refuser ───────────────────────────────────────────────────────────

def test_un_argument_non_litteral_est_refuse(tmp_path):
    """Le jour où quelqu'un écrit `photographier(nom)`, le seuil doit rougir en une fraction de
    seconde. Le deviner ferait disparaître une image de l'attendu sans un mot."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() {
        photographier(nomCalcule)
    }
    """)
    with pytest.raises(RefusDExtraction, match="non littéral"):
        noms_attendus(kt, avec_jeton=True)


def test_une_interpolation_hors_boucle_est_refusee(tmp_path):
    """Une variable qui ne vient d'aucune boucle connue rend le nom indérivable."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() {
        photographier("ecran-${indice}")
    }
    """)
    with pytest.raises(RefusDExtraction, match="aucune boucle connue"):
        noms_attendus(kt, avec_jeton=True)


def test_un_parcours_vide_est_refuse(tmp_path):
    """Un fichier illisible rendrait une liste vide, donc un seuil de zéro, donc le trou
    d'origine restauré en silence."""
    with pytest.raises(RefusDExtraction):
        noms_attendus(_parcours(tmp_path, "  \n"), avec_jeton=True)


# ── Le rapprochement avec les fichiers rapportés ─────────────────────────────────────────────

def test_une_capture_manquante_est_nommee(tmp_path):
    """Dire laquelle manque, pas seulement combien : c'est tout l'intérêt des noms."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() {
        photographier("01-demarrage")
        photographier("02-annonces")
    }
    """)
    dossier = tmp_path / "captures"
    dossier.mkdir()
    (dossier / "01-demarrage.png").write_bytes(b"\x89PNG")
    assert manquants(dossier, kt, avec_jeton=True) == ["02-annonces"]


def test_les_captures_sont_cherchees_dans_les_sous_dossiers(tmp_path):
    """Les images sont rangées par mouture depuis qu'on en teste plusieurs."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() {
        photographier("01-demarrage")
    }
    """)
    dossier = tmp_path / "captures"
    (dossier / "debug").mkdir(parents=True)
    (dossier / "debug" / "01-demarrage.png").write_bytes(b"\x89PNG")
    assert manquants(dossier, kt, avec_jeton=True) == []


def test_le_seuil_est_bien_branche_sur_le_parcours():
    """Le motif « le contrôle est parfait, et il n'est branché nulle part »."""
    bash = (SKILL / "scripts" / "parcours-emulateur.sh").read_text(encoding="utf-8")
    assert "captures-attendues.py" in bash, "le seuil dérivé n'est appelé par personne"


def test_le_script_rend_deux_sur_un_refus(tmp_path):
    """« Je n'ai pas su lire » n'est pas « il manque des images ». Le bash sépare les deux, et
    aucun des deux ne retombe sur un plancher nul."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() {
        photographier(nomCalcule)
    }
    """)
    dossier = tmp_path / "captures"
    dossier.mkdir()
    r = subprocess.run([sys.executable, str(SCRIPT), "verifier", str(dossier), str(kt)],
                       capture_output=True, text=True)
    assert r.returncode == 2, "un refus d'extraction doit se distinguer d'une image manquante"


# ── Les formes que le parseur laissait tomber EN SILENCE (revue du 2026-09-21) ───────────────

def test_un_test_annote_sur_sa_propre_ligne_est_vu(tmp_path):
    """`@Test fun parcours() {` est du Kotlin valide, et la forme la plus courte.

    Elle était rangée en annotation, et jamais soumise au motif de déclaration. Le test
    disparaissait donc de l'attendu. `lister` rendait une liste vide avec un code 0, et le
    plancher retombait à ZÉRO.

    C'est le trou même que ce module existe pour boucher, rouvert par une forme d'écriture.
    Jumeau du défaut « commentaire entre `@Test` et `fun` »."""
    kt = _parcours(tmp_path, """
    @Test fun parcours() {
        photographier("01-demarrage")
        photographier("02-annonces")
    }
    """)
    assert noms_attendus(kt, avec_jeton=True) == ["01-demarrage", "02-annonces"]


def test_un_test_ignore_sur_sa_propre_ligne_reste_ignore(tmp_path):
    """Le pendant : lire la ligne ne doit pas faire perdre ce qu'elle porte d'autre.

    Seul des treize tests neufs à passer DÉJÀ sur le code d'avant, et pour la mauvaise raison.
    Ce parseur-là ne voyait pas le test du tout. Il garde le correctif, il ne le prouve pas."""
    kt = _parcours(tmp_path, """
    @Ignore("en panne") @Test fun parcours() {
        photographier("01-demarrage")
    }
    """)
    assert noms_attendus(kt, avec_jeton=True) == []


def test_une_declaration_sans_test_ne_prend_pas_les_annotations_de_la_suivante(tmp_path):
    """Le bloc d'annotations se vide à CHAQUE déclaration, testée ou non. Sans ça, un `@Test`
    laissé au-dessus d'une fonction utilitaire ferait passer la suivante pour un test."""
    kt = _parcours(tmp_path, """
    @Test
    @Suppress("x") private fun aide() {
        photographier("99-jamais")
    }

    private fun autre() {
        photographier("98-jamais-non-plus")
    }
    """)
    assert noms_attendus(kt, avec_jeton=True) == ["99-jamais"]


# ── Le rapprochement porte sur une IMAGE, par son nom ENTIER (revue du 2026-09-21) ───────────

def test_une_capture_voisine_ne_couvre_pas_un_nom_plus_court(tmp_path):
    """Le test de sous-chaîne rendait « 05-tour1 » satisfait par « 05-tour10.png ». Un
    `repeat(n)` au-delà de neuf suffisait, et la capture manquante ne se voyait plus."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() {
        repeat(10) { tour ->
            photographier("05-tour${tour + 1}")
        }
    }
    """)
    dossier = tmp_path / "captures"
    dossier.mkdir()
    for n in range(2, 11):
        (dossier / f"05-tour{n}.png").write_bytes(b"\x89PNG")
    assert manquants(dossier, kt, avec_jeton=True) == ["05-tour1"]


def test_un_fichier_qui_n_est_pas_une_image_ne_couvre_rien(tmp_path):
    """Le dossier rapatrié porte le film et les journaux. Un écran « navigation » y était
    couvert par `navigation.mp4`, qui ne montre rien à qui lit des images."""
    kt = _parcours(tmp_path, """
    @Test
    fun parcours() {
        photographier("navigation")
    }
    """)
    dossier = tmp_path / "captures"
    dossier.mkdir()
    (dossier / "navigation.mp4").write_bytes(b"\x00\x00\x00 ftyp")
    assert manquants(dossier, kt, avec_jeton=True) == ["navigation"]
