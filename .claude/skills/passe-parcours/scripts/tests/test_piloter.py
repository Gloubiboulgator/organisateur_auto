"""Le pilote du testeur, joué contre un faux `adb`.

POURQUOI CE FICHIER EXISTE
--------------------------
Le pilote garantit deux choses que la synthèse suppose sans les revoir. Chaque geste porte un
commentaire, et chaque capture a sa ligne de journal. Un pilote qui laisserait passer un geste
muet rendrait un parcours troué, et personne ne le verrait avant la synthèse.

Le faux `adb` rend une vraie image PNG, que `ffmpeg` réduit pour de bon. Une imitation de
l'image ne prouverait rien sur la chaîne de capture.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

SKILL = Path(__file__).resolve().parent.parent.parent
PILOTE = SKILL / "scripts" / "piloter.py"
LANCEUR = SKILL / "scripts" / "lancer_testeurs.py"

pytestmark = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="ffmpeg absent")

# Un faux adb. Il garde chaque appel, et rend une image de 1080 pixels de large à `screencap`.
# Sa ligne d'activité nomme le paquet que le fichier `premier-plan` désigne.
FAUX_ADB = """#!/bin/sh
echo "$*" >> "$(dirname "$0")/appels.txt"
case "$*" in
  *screencap*) ffmpeg -loglevel error -f lavfi -i color=c=white:s=$(cat "$(dirname "$0")/taille") -frames:v 1 \\
                 -f image2pipe -vcodec png - ;;
  *dumpsys*) echo "  topResumedActivity=ActivityRecord{1 u0 $(cat "$(dirname "$0")/premier-plan")/.Main}" ;;
esac
"""


@pytest.fixture
def banc(tmp_path):
    """Un dossier de testeur, un faux adb et la configuration hors du dossier."""
    outils = tmp_path / "outils"
    outils.mkdir()
    adb = outils / "adb"
    adb.write_text(FAUX_ADB)
    adb.chmod(0o755)
    (outils / "premier-plan").write_text("org.exemple.app")
    (outils / "taille").write_text("1080x2400")
    conf = tmp_path / "pilote.json"
    conf.write_text(json.dumps({"plateforme": "android", "adb": str(adb), "serie": "emulator-1",
                                "paquet": "org.exemple.app", "facteur": 2.0,
                                "largeur_capture": 540}))
    testeur = tmp_path / "testeur-1"
    testeur.mkdir()
    return {"testeur": testeur, "conf": conf, "outils": outils}


def piloter(banc, *arguments):
    return subprocess.run([sys.executable, str(PILOTE), *arguments], cwd=banc["testeur"],
                          capture_output=True, text=True, timeout=60,
                          env={"PATH": "/usr/bin:/bin", "F5_PILOTE": str(banc["conf"])})


def journal(banc):
    chemin = banc["testeur"] / "journal.jsonl"
    if not chemin.exists():
        return []
    return [json.loads(ligne) for ligne in chemin.read_text().splitlines()]


# ── Les refus ───────────────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("arguments", [
    ("toucher", "10", "20"),
    ("toucher", "10", "20", "--"),
    ("toucher", "10", "20", "--", "court"),
    ("voler", "--", "Je tente un geste qui n'existe pas."),
    ("toucher", "10", "--", "Il manque une coordonnée à ce geste."),
    ("toucher", "dix", "vingt", "--", "Des coordonnées qui ne sont pas des nombres."),
])
def test_un_geste_mal_forme_est_refuse_sans_trace(banc, arguments):
    resultat = piloter(banc, *arguments)
    assert resultat.returncode == 2
    assert journal(banc) == []
    assert not (banc["outils"] / "appels.txt").exists()


def test_le_refus_ne_nomme_aucun_chemin(banc):
    resultat = piloter(banc, "toucher", "1", "2")
    assert str(banc["conf"].parent) not in resultat.stderr


def test_sans_configuration_le_pilote_refuse(banc):
    resultat = subprocess.run([sys.executable, str(PILOTE), "voir", "--", "Je regarde l'écran."],
                              cwd=banc["testeur"], capture_output=True, text=True,
                              env={"PATH": "/usr/bin:/bin"})
    assert resultat.returncode == 2
    assert "pas branché" in resultat.stderr


# ── Le geste ────────────────────────────────────────────────────────────────────────────────


def test_un_geste_donne_une_capture_et_une_ligne(banc):
    resultat = piloter(banc, "voir", "--", "J'arrive sur l'app et je regarde.")
    assert resultat.returncode == 0, resultat.stderr
    assert "captures/001.jpg (540 px de large)" in resultat.stdout
    ligne, = journal(banc)
    assert ligne["capture"] == "captures/001.jpg"
    assert ligne["commentaire"] == "J'arrive sur l'app et je regarde."
    largeur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=width", "-of",
                              "csv=p=0", str(banc["testeur"] / "captures/001.jpg")],
                             capture_output=True, text=True).stdout.strip()
    assert largeur == "540"


def test_les_coordonnees_de_la_capture_sont_converties(banc):
    piloter(banc, "toucher", "100", "250", "--", "Je touche le bouton du milieu.")
    appels = (banc["outils"] / "appels.txt").read_text()
    assert "input tap 200 500" in appels


def test_les_captures_se_numerotent_a_la_suite(banc):
    piloter(banc, "voir", "--", "Premier regard sur l'écran.")
    piloter(banc, "retour", "--", "Je reviens en arrière pour voir.")
    assert [l["capture"] for l in journal(banc)] == ["captures/001.jpg", "captures/002.jpg"]


def test_le_texte_tape_garde_ses_espaces(banc):
    piloter(banc, "taper", "deux mots", "--", "J'écris mon pseudo dans le champ.")
    assert "input text 'deux%smots'" in (banc["outils"] / "appels.txt").read_text()


def test_une_app_quittee_se_signale(banc):
    (banc["outils"] / "premier-plan").write_text("com.android.launcher")
    resultat = piloter(banc, "retour", "--", "J'appuie sur retour pour voir.")
    assert "plus au premier plan" in resultat.stdout


def test_un_pourcent_tape_passe_tel_quel(banc):
    piloter(banc, "taper", "100%", "--", "J'écris un pourcentage dans le champ.")
    assert "input text '100%'" in (banc["outils"] / "appels.txt").read_text()


def test_une_lettre_accentuee_se_refuse_sur_android(banc):
    resultat = piloter(banc, "taper", "élève", "--", "J'écris un mot accentué dans le champ.")
    assert resultat.returncode == 2
    assert "limite du pilote" in resultat.stderr
    assert journal(banc) == []


def test_un_ecran_tourne_change_le_facteur(banc):
    """Un écran passé en paysage rend une capture plus large que celle du démarrage."""
    (banc["outils"] / "taille").write_text("2400x1080")
    piloter(banc, "voir", "--", "Je regarde l'écran tourné en paysage.")
    piloter(banc, "toucher", "100", "250", "--", "Je touche le bouton du milieu.")
    assert "input tap 444 1111" in (banc["outils"] / "appels.txt").read_text()


def test_le_geste_de_trop_se_refuse(banc):
    conf = json.loads(banc["conf"].read_text())
    banc["conf"].write_text(json.dumps({**conf, "actions_max": 1}))
    assert piloter(banc, "voir", "--", "Premier regard sur l'écran.").returncode == 0
    resultat = piloter(banc, "voir", "--", "Un second regard, de trop.")
    assert resultat.returncode == 2
    assert "Rends ton rapport" in resultat.stderr
    assert len(journal(banc)) == 1


# ── La consigne ─────────────────────────────────────────────────────────────────────────────


def lanceur():
    import importlib.util
    spec = importlib.util.spec_from_file_location("lancer_testeurs", LANCEUR)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_la_consigne_ne_garde_aucun_champ_ni_le_preambule():
    module = lanceur()

    class Args:
        plateforme, actions_max, temperaments = "android", 12, True
        texte_fiche = "Une fiche.\nSur deux lignes."

    texte = module.consigne(Args, 2)
    assert "{" not in texte and "}" not in texte
    assert "> Une fiche.\n> Sur deux lignes." in texte
    assert "12 gestes" in texte
    assert "lancer_testeurs.py" not in texte
    assert "curieux" in texte


# ── Le lanceur ──────────────────────────────────────────────────────────────────────────────


def test_un_dossier_de_sortie_existant_se_refuse(tmp_path):
    (tmp_path / "android").mkdir()
    resultat = subprocess.run([sys.executable, str(LANCEUR), "android", "--nombre", "1",
                               "--fiche", str(tmp_path / "fiche.txt"),
                               "--sortie", str(tmp_path / "android"), "--apk", "x.apk",
                               "--paquet", "org.exemple.app", "--avd", "Telephone"],
                              capture_output=True, text=True, timeout=30)
    assert resultat.returncode == 1
    assert "existe déjà" in resultat.stderr


def test_un_plafond_atteint_se_nomme_dans_le_bilan(tmp_path):
    dossier = tmp_path / "essai"
    dossier.mkdir()
    sortie = tmp_path / "sortie"
    sortie.mkdir()
    brut = json.dumps({"is_error": True, "subtype": "error_max_budget_usd"})
    bilan = lanceur().rapatrier(1, dossier, sortie, brut, "")
    assert "error_max_budget_usd" in bilan["erreur"]
