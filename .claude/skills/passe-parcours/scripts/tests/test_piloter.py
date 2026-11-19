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

# Un faux adb. Il garde chaque appel, et rend à `screencap` une mire de 1080 pixels de large.
# Elle est assez fine pour que le flou du coup d'œil s'y mesure.

# Un fichier `ecrans` fait bouger l'écran, pour l'attente de la pose. Il remplace la mire par des
# aplats, une couleur par photo, la dernière restant. La ligne `mire` y redonne la mire, `mire2`
# une autre mire. La ligne `clairseme` donne un écran blanc à deux traits, posé mais presque uni.

# Sa ligne d'activité nomme le paquet que le fichier `premier-plan` désigne.
FAUX_ADB = """#!/bin/sh
ici="$(dirname "$0")"
CLAIRSEME="drawbox=x=80:y=200:w=400:h=30:color=black:t=fill,drawbox=x=80:y=420:w=240:h=16:color=black:t=fill"
echo "$*" >> "$ici/appels.txt"
case "$*" in
  *screencap*)
    if [ -s "$ici/ecrans" ]; then
      couleur=$(head -n 1 "$ici/ecrans")
      [ "$(wc -l < "$ici/ecrans")" -gt 1 ] && sed -i 1d "$ici/ecrans"
      source="color=c=$couleur:s=$(cat "$ici/taille")"
      [ "$couleur" = mire ] && source="testsrc2=s=$(cat "$ici/taille")"
      [ "$couleur" = mire2 ] && source="testsrc=s=$(cat "$ici/taille")"
      [ "$couleur" = clairseme ] && source="color=c=white:s=$(cat "$ici/taille"),$CLAIRSEME"
    else
      source="testsrc2=s=$(cat "$ici/taille")"
    fi
    ffmpeg -loglevel error -f lavfi -i "$source" -frames:v 1 -f image2pipe -vcodec png - ;;
  *"wm density"*) printf 'Physical density: 420\\n'
    if [ -f "$ici/densite-forcee" ]; then printf 'Override density: 560\\n'; fi ;;
  *dumpsys*) echo "  topResumedActivity=ActivityRecord{1 u0 $(cat "$ici/premier-plan")/.Main}" ;;
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
                                "largeur_capture": 540, "graine": 7,
                                "dossier_net": str(tmp_path / "nettes")}))
    (tmp_path / "nettes").mkdir()
    testeur = tmp_path / "testeur-1"
    testeur.mkdir()
    return {"testeur": testeur, "conf": conf, "outils": outils, "nettes": tmp_path / "nettes"}


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


def tap(banc):
    """Le dernier toucher envoyé au téléphone, en pixels de l'écran réel."""
    ligne = [l for l in (banc["outils"] / "appels.txt").read_text().splitlines() if "input tap" in l]
    return [int(v) for v in ligne[-1].split()[-2:]]


def test_les_coordonnees_de_la_capture_sont_converties(banc):
    piloter(banc, "toucher", "100", "250", "--", "Je touche le bouton du milieu.")
    ligne = journal(banc)[-1]
    assert ligne["vise"] == [100, 250]
    assert tap(banc) == [round(v * 2) for v in ligne["touche"]]


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
    assert tap(banc) == [round(v * 2400 / 540) for v in journal(banc)[-1]["touche"]]


def test_le_geste_de_trop_se_refuse(banc):
    conf = json.loads(banc["conf"].read_text())
    banc["conf"].write_text(json.dumps({**conf, "actions_max": 1}))
    assert piloter(banc, "voir", "--", "Premier regard sur l'écran.").returncode == 0
    resultat = piloter(banc, "voir", "--", "Un second regard, de trop.")
    assert resultat.returncode == 2
    assert "Rends ton rapport" in resultat.stderr
    assert len(journal(banc)) == 1


# ── Le coup d'œil et la lecture ─────────────────────────────────────────────────────────────


def taille(chemin):
    sortie = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=width,height",
                             "-of", "csv=p=0", str(chemin)], capture_output=True, text=True)
    return tuple(int(v) for v in sortie.stdout.strip().split(","))


def test_le_testeur_ne_recoit_qu_un_coup_d_oeil(banc):
    """La capture du testeur est floue. La nette, de même taille, vit hors de son dossier."""
    resultat = piloter(banc, "voir", "--", "J'arrive sur l'app et je regarde.")
    assert "Coup d'œil" in resultat.stdout and "./piloter lire" in resultat.stdout
    floue, nette = banc["testeur"] / "captures/001.jpg", banc["nettes"] / "001.jpg"
    assert taille(floue) == taille(nette) == (540, 1200)
    # Le flou ôte le détail : un JPEG flou de la mire pèse nettement moins que le net.
    assert floue.stat().st_size < nette.stat().st_size * 0.6
    assert sorted(p.name for p in banc["testeur"].rglob("*.jpg")) == ["001.jpg"]
    assert not list(banc["testeur"].rglob("*.png"))


def test_lire_rend_la_zone_nette_et_compte_un_geste(banc):
    piloter(banc, "voir", "--", "Premier regard sur l'écran.")
    resultat = piloter(banc, "lire", "270", "600", "0", "300", "--", "Je lis le texte du milieu.")
    assert resultat.returncode == 0, resultat.stderr
    assert taille(banc["testeur"] / "captures/002.jpg") == (270, 300)
    ligne = journal(banc)[-1]
    assert ligne["geste"] == "lire" and ligne["valeurs"] == [0, 300, 270, 600]
    assert "screencap" in (banc["outils"] / "appels.txt").read_text().splitlines()[-2]
    assert "input" not in (banc["outils"] / "appels.txt").read_text()


@pytest.mark.parametrize("zone, motif", [
    (("0", "0", "540", "1200"), "un quart de l'écran"),
    (("600", "0", "700", "100"), "vide ou hors de l'écran"),
    (("inf", "inf", "inf", "inf"), "vide ou hors de l'écran"),
    (("nan", "0", "100", "100"), "vide ou hors de l'écran"),
])
def test_une_lecture_trop_grande_ou_hors_ecran_se_refuse(banc, zone, motif):
    piloter(banc, "voir", "--", "Premier regard sur l'écran.")
    resultat = piloter(banc, "lire", *zone, "--", "Je voudrais tout lire d'un coup.")
    assert resultat.returncode == 2
    assert motif in resultat.stderr
    assert len(journal(banc)) == 1


def test_lire_avant_tout_coup_d_oeil_se_refuse(banc):
    resultat = piloter(banc, "lire", "0", "0", "100", "100", "--", "Je lis avant d'avoir regardé.")
    assert resultat.returncode == 2
    assert "Commence par ./piloter voir" in resultat.stderr


def test_une_lecture_compte_dans_le_plafond(banc):
    conf = json.loads(banc["conf"].read_text())
    banc["conf"].write_text(json.dumps({**conf, "actions_max": 2}))
    piloter(banc, "voir", "--", "Premier regard sur l'écran.")
    piloter(banc, "lire", "0", "0", "100", "100", "--", "Je lis le coin en haut.")
    resultat = piloter(banc, "voir", "--", "Un troisième geste, de trop.")
    assert resultat.returncode == 2
    assert "Rends ton rapport" in resultat.stderr


def test_lire_sur_un_ecran_tourne_depuis_le_coup_d_oeil_se_refuse(banc):
    """La zone se vise sur le dernier coup d'œil. Un écran tourné depuis rendrait une bande
    sans rapport, et le geste serait perdu. Relevé par la revue de la 113, le 2026-11-19."""
    piloter(banc, "voir", "--", "Premier regard sur l'écran.")
    (banc["outils"] / "taille").write_text("2400x1080")
    resultat = piloter(banc, "lire", "0", "600", "540", "900", "--", "Je lis le bas de l'écran.")
    assert resultat.returncode == 1
    assert "changé de forme" in resultat.stdout
    assert journal(banc)[-1]["capture"] is None
    # Le numéro resservira : sa capture nette ne reste pas sous ce numéro.
    assert sorted(p.name for p in banc["nettes"].glob("*.jpg")) == ["001.jpg"]
    # Le coup d'œil d'avant ne vaut plus : une lecture demande d'abord de regarder.
    resultat = piloter(banc, "lire", "0", "0", "100", "100", "--", "Je relis le coin en haut.")
    assert resultat.returncode == 2 and "Commence par ./piloter voir" in resultat.stderr


def test_une_zone_d_un_pixel_arrondie_a_zero_se_refuse(banc):
    """Le contrôle de la zone suit l'arrondi. Relevé par la revue de la 113."""
    piloter(banc, "voir", "--", "Premier regard sur l'écran.")
    resultat = piloter(banc, "lire", "1.5", "10", "2.5", "300", "--", "Je lis une colonne fine.")
    assert resultat.returncode == 2
    assert "vide ou hors de l'écran" in resultat.stderr


def test_un_jpeg_a_octets_de_remplissage_se_lit(tmp_path):
    """Des 0xFF de remplissage peuvent précéder un marqueur. Relevé par la revue de la 113."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("piloter_essai", PILOTE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    image = tmp_path / "mire.jpg"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc2=s=320x240",
                    "-frames:v", "1", str(image)], check=True)
    octets = image.read_bytes()
    # Trois octets de remplissage glissés devant le deuxième marqueur.
    rembourre = octets[:2] + b"\xff\xff\xff" + octets[2:]
    image.write_bytes(rembourre)
    assert module.taille_image(image) == (320, 240)


def test_les_captures_nettes_sont_rapatriees(tmp_path):
    dossier, nettes, sortie = tmp_path / "essai", tmp_path / "nettes", tmp_path / "sortie"
    for d in (dossier, nettes, sortie):
        d.mkdir()
    (nettes / "001.jpg").write_bytes(b"x")
    (nettes / ".coup-d-oeil").write_text("540 1200")
    lanceur().rapatrier(1, dossier, sortie, "{}", "", nettes)
    assert [p.name for p in (sortie / "testeur-1" / "nettes").iterdir()] == ["001.jpg"]


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


# ── Le doigt ────────────────────────────────────────────────────────────────────────────────


def test_le_doigt_tombe_pres_du_point_vise_sans_y_etre_toujours(banc):
    """2 mm d'écart type, à 420 points par pouce, font 33 pixels d'écran, soit 16,5 de capture.

    Une densité forcée de 560 ne change rien : elle agrandit l'affichage, pas le pouce."""
    (banc["outils"] / "densite-forcee").write_text("")
    piloter(banc, "voir", "--", "Je regarde l'écran avant de toucher.")
    for i in range(8):
        piloter(banc, "toucher", "270", "600", "--", f"Je touche le bouton, essai {i}.")
    ecarts = [(l["touche"][0] - 270, l["touche"][1] - 600) for l in journal(banc)[1:]]
    assert len(ecarts) == 8
    # Borné à trois écarts types, et pas collé au point visé.
    assert all(abs(dx) <= 50 and abs(dy) <= 50 for dx, dy in ecarts)
    assert sum(1 for dx, dy in ecarts if (dx, dy) != (0, 0)) >= 6


def test_le_doigt_reste_dans_l_ecran(banc):
    piloter(banc, "voir", "--", "Je regarde l'écran avant de toucher.")
    for i in range(6):
        piloter(banc, "toucher", "0", "1199", "--", f"Je touche le coin en bas, essai {i}.")
    for ligne in journal(banc)[1:]:
        x, y = ligne["touche"]
        assert 0 <= x <= 539 and 0 <= y <= 1199


def test_un_glisser_se_decale_tout_entier(banc):
    piloter(banc, "voir", "--", "Je regarde l'écran avant de glisser.")
    piloter(banc, "glisser", "270", "900", "270", "300", "--", "Je fais défiler vers le bas.")
    vise, touche = journal(banc)[-1]["vise"], journal(banc)[-1]["touche"]
    assert touche[0] - vise[0] == touche[2] - vise[2]
    assert touche[1] - vise[1] == touche[3] - vise[3]


def test_lire_ne_se_decale_pas(banc):
    piloter(banc, "voir", "--", "Premier regard sur l'écran.")
    piloter(banc, "lire", "0", "300", "270", "600", "--", "Je lis le texte du milieu.")
    assert "touche" not in journal(banc)[-1]


# ── La pose de l'écran ──────────────────────────────────────────────────────────────────────


def test_la_duree_de_pose_se_dit_et_s_ecrit(banc):
    """L'écran clignote douze fois, puis montre la mire : il a mis du temps à se poser."""
    (banc["outils"] / "ecrans").write_text("black\nwhite\n" * 6 + "mire\n")
    resultat = piloter(banc, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert resultat.returncode == 0, resultat.stderr
    pose = journal(banc)[-1]["pose"]
    assert pose >= 0.5
    assert f"L'écran a mis {pose:.1f} s à se poser.".replace(".", ",", 1) in resultat.stdout
    # Le coup d'œil vient de la dernière photo, la mire, bien plus lourde qu'un aplat.
    assert (banc["nettes"] / "001.jpg").stat().st_size > 40_000


def test_un_ecran_immobile_se_pose_aussitot(banc):
    resultat = piloter(banc, "retour", "--", "J'appuie sur retour pour voir.")
    assert "L'écran s'est posé aussitôt." in resultat.stdout
    assert journal(banc)[-1]["pose"] < 0.5


def test_un_ecran_qui_bouge_sans_fin_se_dit(banc):
    (banc["outils"] / "ecrans").write_text("mire\nmire2\n" * 400)
    resultat = piloter(banc, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert "L'écran bouge encore après 10 s." in resultat.stdout
    assert journal(banc)[-1]["pose"] == "bouge"


def test_un_ecran_vide_n_est_jamais_pose(banc):
    """Un aplat blanc qui ne bouge plus est un chargement, pas un écran posé."""
    (banc["outils"] / "ecrans").write_text("white\n")
    resultat = piloter(banc, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert "L'écran est resté vide 10 s." in resultat.stdout
    assert journal(banc)[-1]["pose"] == "vide"


def test_un_ecran_vide_puis_rempli_compte_son_attente(banc):
    """Six photos blanches et immobiles, plus d'une seconde, puis la mire : la durée court
    jusqu'à la mire, au lieu de s'arrêter sur le blanc."""
    (banc["outils"] / "ecrans").write_text("white\n" * 6 + "mire\n")
    resultat = piloter(banc, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert resultat.returncode == 0, resultat.stderr
    pose = journal(banc)[-1]["pose"]
    assert isinstance(pose, float) and pose >= 1.0
    assert "a mis" in resultat.stdout


def test_voir_et_lire_ne_mesurent_rien(banc):
    resultat = piloter(banc, "voir", "--", "Je regarde l'écran sans toucher.")
    assert "se poser" not in resultat.stdout and "posé" not in resultat.stdout
    assert "pose" not in journal(banc)[-1]
    appels = (banc["outils"] / "appels.txt").read_text()
    assert appels.count("screencap") == 1


def test_une_app_quittee_ne_souffle_pas_la_commande(banc):
    (banc["outils"] / "premier-plan").write_text("com.android.launcher")
    resultat = piloter(banc, "retour", "--", "J'appuie sur retour pour voir.")
    assert "Remarque : L'app n'est plus au premier plan." in resultat.stdout
    assert "relancer" not in resultat.stdout


def test_un_ecran_clairseme_se_pose(banc):
    """Un écran blanc à deux traits est posé, pas vide. À 98 %, il passait pour un chargement, et
    chaque geste y coûtait dix secondes. Relevé par la revue de la 114."""
    (banc["outils"] / "ecrans").write_text("clairseme\n")
    resultat = piloter(banc, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert "L'écran s'est posé aussitôt." in resultat.stdout, resultat.stdout


def module_pilote():
    import importlib.util
    spec = importlib.util.spec_from_file_location("piloter_essai", PILOTE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_un_glisser_pres_du_bord_garde_un_seul_ecart():
    """Borner chaque point seul raccourcissait le glisser. Relevé par la revue de la 114."""
    touche = module_pilote().decaler([270, 1190, 270, 300], [0, 20], 540, 1200)
    assert touche == [270, 1199, 270, 309]


def test_un_toucher_sans_coup_d_oeil_reste_dans_l_ecran(banc):
    """Sans capture, la taille de l'écran se lit sur une photo. Sans elle, le point sortait."""
    for i in range(4):
        piloter(banc, "toucher", "539", "1199", "--", f"Je touche le coin d'emblée, essai {i}.")
        (banc["testeur"] / ".largeur-ecran").unlink(missing_ok=True)
    for ligne in journal(banc):
        assert ligne["erreur"] is None
        x, y = ligne["touche"]
        assert 0 <= x <= 539 and 0 <= y <= 1199


def test_l_ancien_format_de_la_largeur_se_relit(banc):
    (banc["testeur"] / ".largeur-ecran").write_text("1080")
    resultat = piloter(banc, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert resultat.returncode == 0, resultat.stderr
    assert journal(banc)[-1]["erreur"] is None


# ── Le web, contre un faux pilote Node ─────────────────────────────────────────────────────

# Il donne la taille de sa page, garde les valeurs reçues, puis dit « fait ». À chaque ligne
# « photo », il rend l'image suivante de la liste `ecrans-web`, la dernière restant. Sur « fin »,
# il rend sa sortie JSON. La ligne `panne` le fait échouer.
FAUX_PILOTE_WEB = r"""
const fs = require('fs'), path = require('path'), readline = require('readline');
const ici = path.dirname(process.env.F5_PILOTE);
const ecrans = fs.readFileSync(path.join(ici, 'ecrans-web'), 'utf8').trim().split('\n');
if (ecrans[0] === 'panne') { process.stderr.write('la page a planté\n'); process.exit(1); }
let n = 0;
process.stdout.write('taille 1.5 412 915\n');
(async () => {
  const lignes = readline.createInterface({ input: process.stdin })[Symbol.asyncIterator]();
  fs.writeFileSync(path.join(ici, 'valeurs-recues'), (await lignes.next()).value);
  process.stdout.write('fait\n');
  for (;;) {
    const { value: ligne, done } = await lignes.next();
    if (done || ligne !== 'photo') break;
    const png = fs.readFileSync(path.join(ici, ecrans[Math.min(n++, ecrans.length - 1)] + '.png'));
    process.stdout.write(`${png.length}\n`);
    process.stdout.write(png);
  }
  process.stdout.write(JSON.stringify({ remarques: [] }));
})();
"""


@pytest.fixture
def banc_web(tmp_path):
    if not shutil.which("node"):
        pytest.skip("node absent")
    for nom, source in (("white", "color=c=white:s=640x1200"), ("mire", "testsrc2=s=640x1200")):
        subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "lavfi", "-i", source, "-frames:v",
                        "1", str(tmp_path / f"{nom}.png")], check=True)
    (tmp_path / "pilote.cjs").write_text(FAUX_PILOTE_WEB)
    conf = tmp_path / "pilote.json"
    conf.write_text(json.dumps({"plateforme": "web", "pilote_web": str(tmp_path / "pilote.cjs"),
                                "graine": 7, "dossier_net": str(tmp_path / "nettes")}))
    (tmp_path / "nettes").mkdir()
    testeur = tmp_path / "testeur-1"
    testeur.mkdir()
    return {"testeur": testeur, "conf": conf, "ici": tmp_path, "nettes": tmp_path / "nettes"}


def test_le_web_attend_la_pose_et_garde_la_derniere_photo(banc_web):
    """La pose se mesure côté Python, et le coup d'œil vient de la dernière photo. Le pilote Node
    portait une copie de l'attente, qui divergeait. Relevé par la revue de la 114."""
    (banc_web["ici"] / "ecrans-web").write_text("white\n" * 6 + "mire\n")
    resultat = piloter(banc_web, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert resultat.returncode == 0, resultat.stderr
    ligne = journal(banc_web)[-1]
    assert ligne["pose"] >= 0.5
    # Le doigt se décale côté Python, et Node reçoit le point touché. 2 mm font 19 px de capture.
    recues = json.loads((banc_web["ici"] / "valeurs-recues").read_text())
    assert [round(v) for v in recues] == ligne["touche"]
    assert all(abs(t - v) <= 57 for t, v in zip(ligne["touche"], ligne["vise"]))
    assert "a mis" in resultat.stdout
    assert (banc_web["nettes"] / "001.jpg").stat().st_size > 40_000
    assert (banc_web["testeur"] / "captures" / "001.jpg").is_file()


def test_le_web_voir_ne_mesure_rien(banc_web):
    (banc_web["ici"] / "ecrans-web").write_text("mire\n")
    resultat = piloter(banc_web, "voir", "--", "Je regarde la page sans toucher.")
    assert resultat.returncode == 0, resultat.stderr
    assert "pose" not in journal(banc_web)[-1]


def test_une_panne_du_navigateur_se_dit(banc_web):
    (banc_web["ici"] / "ecrans-web").write_text("panne\n")
    resultat = piloter(banc_web, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert resultat.returncode == 1
    assert "la page a planté" in resultat.stdout
    assert journal(banc_web)[-1]["erreur"] == "la page a planté"


def test_une_barre_d_etat_n_empeche_pas_l_ecran_vide():
    """Deux rangées sombres en haut, une barre d'état, au-dessus d'un corps blanc. Relevé par la
    revue de la 114 : la barre faisait passer le chargement pour un écran posé."""
    gris = bytes([40] * 128 + [250] * (64 * 64 - 128))
    assert module_pilote().est_vide(gris)


def test_une_capture_lente_ne_gonfle_pas_la_duree(tmp_path):
    """Une photo prend une demi-seconde, et l'écran change dès la deuxième. La durée se prend au
    milieu des deux demandes, sous la demi-seconde. Relevé par la revue de la 114."""
    module = module_pilote()
    images = []
    for nom, source in (("a", "testsrc2=s=320x640"), ("b", "testsrc=s=320x640")):
        chemin = tmp_path / f"{nom}.png"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "lavfi", "-i", source,
                        "-frames:v", "1", str(chemin)], check=True)
        images.append(chemin.read_bytes())
    suite = iter([images[0]] + [images[1]] * 20)

    def photographier():
        import time
        time.sleep(0.5)
        return next(suite)

    _, duree = module.attendre_la_pose(photographier)
    assert duree < 0.5
