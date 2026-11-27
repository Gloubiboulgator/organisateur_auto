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
import os
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


def args_de_consigne(**changes):
    """De quoi écrire la consigne d'un testeur, réglages par défaut sauf ce qui change."""
    module = lanceur()
    reglages = module.completer(module.DEFAUTS, {"actions_max": 12, **changes})

    class Args:
        plateforme = "android"
        texte_fiche = "Une fiche.\nSur deux lignes."
    Args.reglages = reglages
    Args.temperaments_par_rang = ["", module.lire_temperaments()["Curieux"]]
    return module, Args


def consigne_avec(**changes):
    module, args = args_de_consigne(**changes)
    return module.consigne(args, 2)


def test_la_consigne_ne_garde_aucun_champ_ni_le_preambule():
    texte = consigne_avec()
    assert "{" not in texte and "}" not in texte
    assert "<!--" not in texte and "###" not in texte
    assert "> Une fiche.\n> Sur deux lignes." in texte
    assert "12 gestes" in texte
    assert "lancer_testeurs.py" not in texte
    assert "curieux" in texte
    assert "Curieux |" not in texte
    # Les défauts gardent le texte d'avant les réglages.
    assert "pour ce que promet sa fiche" in texte
    assert "au plus un quart de l'écran" in texte
    assert "combien de temps l'écran a mis" in texte
    assert "\n\n\n" not in texte


def test_la_consigne_suit_les_options_eteintes():
    texte = consigne_avec(envie=False, flou={"actif": False}, pose={"actif": False})
    assert "pour en faire le tour" in texte and "fait le tour de ce qui" in texte
    assert "pour ce que promet sa fiche" not in texte
    assert "coup d'œil" not in texte and "./piloter lire" not in texte
    assert "combien de temps" not in texte
    assert "\n\n\n" not in texte
    assert "{" not in texte


def test_la_memoire_courte_entre_dans_la_consigne():
    assert "Tu ne retiens pas tout" not in consigne_avec()
    assert "Tu ne retiens pas tout" in consigne_avec(memoire_courte={"actif": True})
    assert "la moitié de l'écran" in consigne_avec(flou={"lecture_max": 50})


# ── Les réglages ────────────────────────────────────────────────────────────────────────────


def test_les_defauts_passent_la_verification():
    module = lanceur()
    assert module.verifier_reglages(module.completer(module.DEFAUTS, {})) == []


@pytest.mark.parametrize("changes, motif", [
    ({"nombre": 0}, "nombre"),
    ({"budget_max": 50}, "budget_max"),
    ({"doigt": {"mm": "deux"}}, "doigt.mm"),
    ({"actions_max": True}, "actions_max"),
    ({"modele": "gpt"}, "modele"),
    ({"plateformes": []}, "plateformes"),
    ({"plateformes": ["web"]}, "plateformes"),
    ({"temperaments": {"mode": "choix", "choix": {"firefox-1": "Furieux"}}}, "Furieux"),
])
def test_un_reglage_hors_bornes_se_refuse(changes, motif):
    module = lanceur()
    fautes = module.verifier_reglages(module.completer(module.DEFAUTS, changes))
    assert any(motif in f for f in fautes), fautes


def test_chaque_navigateur_est_une_plateforme_avec_son_parallele():
    """Les cinq navigateurs de Playwright, chacun cochable et réglé à part. Demandé le 2026-11-27."""
    module = lanceur()
    reglages = module.completer(module.DEFAUTS, {
        "plateformes": ["chromium", "firefox", "webkit", "chrome", "msedge"],
        "paralleles": {"webkit": 2}})
    assert module.verifier_reglages(reglages) == []
    assert reglages["paralleles"]["webkit"] == 2 and reglages["paralleles"]["firefox"] == 3
    trop = module.completer(module.DEFAUTS, {"paralleles": {"msedge": 9}})
    assert any("paralleles.msedge" in f for f in module.verifier_reglages(trop))


def test_les_temperaments_au_hasard_ne_se_repetent_pas_avant_d_avoir_tous_servi():
    module = lanceur()
    reglages = module.completer(module.DEFAUTS, {"temperaments": {"mode": "hasard"}})
    tires = module.attribuer_temperaments(reglages, "firefox", 4)
    assert sorted(tires) == sorted(module.lire_temperaments().values())


def test_les_temperaments_un_par_un_suivent_la_fenetre():
    module = lanceur()
    reglages = module.completer(module.DEFAUTS, {"temperaments": {
        "mode": "choix", "choix": {"firefox-1": "Exigeant", "firefox-2": "Aucun",
                                   "chromium-3": "Curieux"}}})
    tires = module.attribuer_temperaments(reglages, "firefox", 3)
    assert tires == [module.lire_temperaments()["Exigeant"], "", ""]


def test_l_interruption_tombe_entre_le_quart_et_la_moitie():
    module = lanceur()
    reglages = module.completer(module.DEFAUTS, {"actions_max": 40})
    for _ in range(50):
        assert 10 <= module.options_du_pilote(reglages)["interruption_geste"] <= 20


# ── Le lanceur ──────────────────────────────────────────────────────────────────────────────


def test_un_dossier_de_sortie_existant_se_refuse(tmp_path):
    (tmp_path / "android").mkdir()
    resultat = subprocess.run([sys.executable, str(LANCEUR), "android",
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

# Une photo peut se demander avant les valeurs. « retoucher » et « interrompre S » s'écrivent dans
# le fichier `demandes`, et Node répond « fait ».
FAUX_PILOTE_WEB = r"""
const fs = require('fs'), path = require('path'), readline = require('readline');
const ici = path.dirname(process.env.F5_PILOTE);
const ecrans = fs.readFileSync(path.join(ici, 'ecrans-web'), 'utf8').trim().split('\n');
if (ecrans[0] === 'panne') { process.stderr.write('la page a planté\n'); process.exit(1); }
let n = 0;
process.stdout.write('taille 1.5 412 915\n');
(async () => {
  const lignes = readline.createInterface({ input: process.stdin })[Symbol.asyncIterator]();
  const photo = () => {
    const png = fs.readFileSync(path.join(ici, ecrans[Math.min(n++, ecrans.length - 1)] + '.png'));
    process.stdout.write(`${png.length}\n`);
    process.stdout.write(png);
  };
  let { value: reponse } = await lignes.next();
  while (reponse === 'photo') { photo(); ({ value: reponse } = await lignes.next()); }
  fs.writeFileSync(path.join(ici, 'valeurs-recues'), reponse);
  process.stdout.write('fait\n');
  for (;;) {
    const { value: ligne, done } = await lignes.next();
    if (done) break;
    if (ligne === 'photo') { photo(); continue; }
    if (ligne === 'retoucher' || ligne.startsWith('interrompre ')) {
      fs.appendFileSync(path.join(ici, 'demandes'), ligne + '\n');
      process.stdout.write('fait\n');
      continue;
    }
    break;
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


def test_des_reglages_hors_bornes_n_ouvrent_rien(tmp_path):
    (tmp_path / "reglages.json").write_text(json.dumps({"nombre": 50}))
    resultat = subprocess.run([sys.executable, str(LANCEUR), "firefox", "--reglages",
                               str(tmp_path / "reglages.json"), "--fiche",
                               str(tmp_path / "fiche.txt"), "--sortie", str(tmp_path / "web"),
                               "--url", "http://127.0.0.1:1/"],
                              capture_output=True, text=True, timeout=30)
    assert resultat.returncode == 1
    assert "nombre doit valoir de 1 à 10" in resultat.stderr
    assert not (tmp_path / "web").exists()


@pytest.mark.parametrize("appareil", [None, "Pixel 5"])
def test_le_vrai_pilote_garde_la_page_d_un_geste_a_l_autre(tmp_path, appareil):
    """Le serveur du pilote, contre un vrai Chromium. Chaque geste est un processus neuf, et la
    page doit pourtant survivre. Le champ touché au premier geste reçoit le texte du deuxième.
    Ce texte mène la page sur une autre origine, que le troisième geste constate."""
    node_path = "/opt/node-tools/node_modules"
    essai = subprocess.run(["node", "-e", "require('playwright').chromium.executablePath()"],
                           capture_output=True, env={**os.environ, "NODE_PATH": node_path})
    if not shutil.which("node") or essai.returncode != 0:
        pytest.skip("node ou playwright absent")
    (tmp_path / "index.html").write_text(
        '<input style="position:absolute;left:0;top:0;width:400px;height:80px" oninput="'
        "if (this.value === 'bonjour') location.href = location.href.replace('127.0.0.1', "
        "'localhost')\">")
    serveur = subprocess.Popen([sys.executable, "-m", "http.server", "0", "--bind", "127.0.0.1",
                                "--directory", str(tmp_path)], stdout=subprocess.PIPE, text=True)
    port_http = int(serveur.stdout.readline().split("port ")[1].split()[0])
    conf = tmp_path / "pilote.json"
    conf.write_text(json.dumps({"moteur": "chromium", "appareil": appareil, "port": 9399, "profil": str(tmp_path / "p"),
                                "url": f"http://127.0.0.1:{port_http}/", "largeur_css": 412,
                                "hauteur_css": 915, "echelle": 1.5}))
    env = {**os.environ, "NODE_PATH": node_path, "F5_PILOTE": str(conf)}
    pilote = ["node", str(SKILL / "scripts" / "pilote-web.cjs")]
    import socket
    import time
    try:
        subprocess.run([*pilote, "demarrer"], env=env, check=True, capture_output=True)
        for _ in range(60):
            try:
                socket.create_connection(("127.0.0.1", 9399), timeout=1).close()
                break
            except OSError:
                time.sleep(0.5)

        def geste(nom, valeurs):
            return subprocess.run([*pilote, nom], env=env, capture_output=True, timeout=60,
                                  input=(json.dumps(valeurs) + "\nfin\n").encode())

        # Un téléphone imité défile sans molette, et se touche du doigt.
        assert geste("glisser", [150, 600, 150, 300]).returncode == 0
        assert geste("glisser", [150, 300, 150, 600]).returncode == 0
        assert geste("toucher", [150, 60]).returncode == 0
        assert geste("taper", ["bonjour"]).returncode == 0
        sortie = geste("voir", [])
        attendu = b"taille 1.5 412 915 1.5\nfait\n" if appareil is None else b"taille "
        assert sortie.stdout.startswith(attendu), sortie.stdout[:80]
        assert "quitté".encode() in sortie.stdout
        relu = subprocess.run(["node", "-e", f"""
            const net = require('net'); const s = net.connect(9399, '127.0.0.1');
            s.write('inconnu\\n'); s.on('close', () => process.exit(0));"""], env=env)
        assert relu.returncode == 0
        assert "geste inconnu" in (tmp_path / "pilote.json.erreur").read_text()
        # Un relais tué en plein geste coupe la connexion sous les photos. Le serveur doit y
        # survivre, et servir le geste suivant. Revue de la 121.
        import struct
        coupe = socket.create_connection(("127.0.0.1", 9399), timeout=5)
        coupe.sendall(b"voir\n[]\n" + b"photo\n" * 20)
        coupe.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
        coupe.close()
        assert geste("voir", []).returncode == 0
    finally:
        subprocess.run([*pilote, "arreter"], env=env, capture_output=True, timeout=30)
        serveur.kill()


FAUX_ADB_CHROME = """#!/bin/sh
ici="$(dirname "$0")"
echo "$*" >> "$ici/appels.txt"
case "$*" in
  *"pm path"*) [ -f "$ici/sans-chrome" ] || echo "package:/data/app/chrome/base.apk" ;;
  *"wm size"*) echo "Physical size: 1080x2400" ;;
esac
"""


def faux_adb_chrome(tmp_path):
    adb = tmp_path / "adb"
    adb.write_text(FAUX_ADB_CHROME)
    adb.chmod(0o755)
    import argparse
    return argparse.Namespace(adb=str(adb), avd="Mon_telephone", url="http://10.0.2.2:8000/")


def test_chrome_android_s_ouvre_vide_sur_le_site(tmp_path):
    """Chrome vidé, ses écrans d'accueil demandés en moins, puis le site ouvert dans Chrome."""
    module = lanceur()
    conf = module.demarrer_chrome_android(faux_adb_chrome(tmp_path), 1, "emulator-5602")
    appels = (tmp_path / "appels.txt").read_text()
    assert "shell pm clear com.android.chrome" in appels
    assert "--disable-fre" in appels
    assert ("shell am start -a android.intent.action.VIEW -d http://10.0.2.2:8000/ "
            "-p com.android.chrome") in appels
    assert conf["paquet"] == "com.android.chrome" and conf["url"] == "http://10.0.2.2:8000/"
    assert conf["facteur"] == 2.0


def test_chrome_android_absent_se_dit(tmp_path):
    (tmp_path / "sans-chrome").write_text("")
    with pytest.raises(RuntimeError, match="Chrome n'est pas installé sur le téléphone virtuel"):
        lanceur().demarrer_chrome_android(faux_adb_chrome(tmp_path), 1, "emulator-5602")


def test_relancer_chrome_android_rouvre_le_site(banc):
    conf = json.loads(banc["conf"].read_text())
    conf.update(paquet="com.android.chrome", url="http://10.0.2.2:8000/")
    banc["conf"].write_text(json.dumps(conf))
    (banc["outils"] / "premier-plan").write_text("com.android.chrome")
    resultat = piloter(banc, "relancer", "--", "Je rouvre le site.")
    assert resultat.returncode == 0, resultat.stderr
    appels = (banc["outils"] / "appels.txt").read_text()
    assert "am start -a android.intent.action.VIEW -d http://10.0.2.2:8000/" in appels
    assert "monkey" not in appels


def test_relancer_chrome_android_protege_l_adresse_du_shell(banc):
    conf = json.loads(banc["conf"].read_text())
    conf.update(paquet="com.android.chrome", url="http://10.0.2.2:8000/?a=1&b=2")
    banc["conf"].write_text(json.dumps(conf))
    (banc["outils"] / "premier-plan").write_text("com.android.chrome")
    resultat = piloter(banc, "relancer", "--", "Je rouvre le site.")
    assert resultat.returncode == 0, resultat.stderr
    assert "-d 'http://10.0.2.2:8000/?a=1&b=2' -p" in (banc["outils"] / "appels.txt").read_text()


def test_des_reglages_mal_formes_sont_refuses_sans_trace(tmp_path):
    (tmp_path / "reglages.json").write_text(json.dumps({"paralleles": 2}))
    resultat = subprocess.run([sys.executable, str(LANCEUR), "firefox", "--reglages",
                               str(tmp_path / "reglages.json"), "--fiche",
                               str(tmp_path / "fiche.txt"), "--sortie", str(tmp_path / "web"),
                               "--url", "http://127.0.0.1:1/"],
                              capture_output=True, text=True, timeout=30)
    assert resultat.returncode == 1
    assert "réglages refusés" in resultat.stderr and "Traceback" not in resultat.stderr


def test_les_trois_plateformes_mobiles_se_cochent():
    module = lanceur()
    reglages = module.completer(module.DEFAUTS, {
        "plateformes": ["chrome_android", "chrome_mobile", "safari_mobile"]})
    assert module.verifier_reglages(reglages) == []
    assert reglages["paralleles"]["chrome_android"] == 1
    assert module.NAVIGATEURS["chrome_mobile"]["appareil"] == "Pixel 5"
    assert module.NAVIGATEURS["safari_mobile"]["appareil"] == "iPhone 12"


# ── Les réglages du pilote ──────────────────────────────────────────────────────────────────


def regler(banc, **options):
    conf = json.loads(banc["conf"].read_text())
    conf["options"] = {**conf.get("options", {}), **options}
    banc["conf"].write_text(json.dumps(conf))


def taps(banc):
    lignes = (banc["outils"] / "appels.txt").read_text().splitlines()
    return [l for l in lignes if "input tap" in l]


def test_sans_flou_le_testeur_recoit_la_capture_nette(banc):
    regler(banc, flou=False)
    resultat = piloter(banc, "voir", "--", "Je regarde l'écran tel qu'il est.")
    assert resultat.returncode == 0, resultat.stderr
    assert "Capture : captures/001.jpg" in resultat.stdout
    assert "petit texte" not in resultat.stdout
    assert ((banc["testeur"] / "captures/001.jpg").read_bytes()
            == (banc["nettes"] / "001.jpg").read_bytes())


def test_un_flou_fort_pese_moins_qu_un_flou_leger(banc):
    regler(banc, flou_niveau="léger")
    piloter(banc, "voir", "--", "Je regarde l'écran, premier coup.")
    regler(banc, flou_niveau="fort")
    piloter(banc, "voir", "--", "Je regarde l'écran, second coup.")
    leger, fort = ((banc["testeur"] / f"captures/00{n}.jpg").stat().st_size for n in (1, 2))
    assert fort < leger


def test_la_part_lisible_se_regle(banc):
    regler(banc, lecture_max=0.5)
    piloter(banc, "voir", "--", "Je regarde avant de lire.")
    resultat = piloter(banc, "lire", "0", "0", "540", "500", "--", "Je lis toute la moitié du haut.")
    assert resultat.returncode == 0, resultat.stderr
    resultat = piloter(banc, "lire", "0", "0", "540", "800", "--", "Je lis plus que la moitié ici.")
    assert "tu ne peux lire que la moitié de l'écran" in resultat.stderr
    assert "rend au plus la moitié de l'écran" in resultat.stderr


def test_sans_doigt_le_toucher_tombe_au_point_vise(banc):
    regler(banc, doigt=False)
    piloter(banc, "toucher", "100", "250", "--", "Je touche le bouton du milieu.")
    ligne = journal(banc)[-1]
    assert ligne["touche"] == ligne["vise"] == [100, 250]


def test_sans_mesure_de_pose_rien_ne_se_dit(banc):
    regler(banc, pose=False)
    resultat = piloter(banc, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert resultat.returncode == 0, resultat.stderr
    assert "posé" not in resultat.stdout and "se poser" not in resultat.stdout
    assert "pose" not in journal(banc)[-1]


def test_un_ecran_qui_ne_reagit_pas_se_retouche(banc):
    """La mire ne change jamais : le testeur impatient touche une seconde fois, au même point."""
    regler(banc, double_toucher=True, double_seuil=0.5)
    resultat = piloter(banc, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert resultat.returncode == 0, resultat.stderr
    premier, second = taps(banc)
    assert premier == second
    assert journal(banc)[-1]["double"] is True


def test_un_ecran_qui_reagit_ne_se_retouche_pas(banc):
    """L'écran d'avant est une mire, puis une autre : l'app a réagi, un seul toucher part. La
    première photo sert à lire la taille de l'écran, faute de coup d'œil avant ce toucher."""
    regler(banc, double_toucher=True, double_seuil=0.5)
    (banc["outils"] / "ecrans").write_text("mire\nmire\nmire2\n")
    resultat = piloter(banc, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert resultat.returncode == 0, resultat.stderr
    assert len(taps(banc)) == 1
    assert "double" not in journal(banc)[-1]


def test_le_retouche_tient_aussi_sans_mesure_de_pose(banc):
    regler(banc, double_toucher=True, double_seuil=0.5, pose=False)
    piloter(banc, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert len(taps(banc)) == 2


def test_les_fautes_de_frappe_s_ecrivent_au_journal(banc):
    regler(banc, fautes=True, fautes_taux=1.0)
    resultat = piloter(banc, "taper", "bonjour", "--", "J'écris mon pseudo dans le champ.")
    assert resultat.returncode == 0, resultat.stderr
    ligne = journal(banc)[-1]
    assert ligne["voulu"] == "bonjour" and ligne["tape"] != "bonjour"
    assert ligne["tape"].isascii()
    assert "bonjour" not in (banc["outils"] / "appels.txt").read_text()


def test_sans_fautes_le_texte_part_tel_quel(banc):
    piloter(banc, "taper", "bonjour", "--", "J'écris mon pseudo dans le champ.")
    assert "voulu" not in journal(banc)[-1]


def test_une_lettre_seule_part_toujours():
    module = module_pilote()
    for graine in range(40):
        conf = {"graine": graine, "options": {"fautes": True, "fautes_taux": 1.0}}
        assert module.faire_des_fautes(conf, 1, "a") != ""


def test_le_calme_se_compte_depuis_le_second_toucher(monkeypatch):
    """L'écran ne répond qu'un peu après le second toucher. La photo rendue doit le montrer."""
    module = module_pilote()
    monkeypatch.setattr(module, "empreinte", lambda photo: photo)
    monkeypatch.setattr(module, "a_bouge", lambda a, b: a != b)
    monkeypatch.setattr(module, "est_vide", lambda e: False)
    rejoue = []

    def photographier():
        return "apres" if rejoue and module.time.monotonic() - rejoue[0] > 0.3 else "avant"

    double = {"avant": "avant", "seuil": 1.0, "fait": False,
              "rejouer": lambda: rejoue.append(module.time.monotonic())}
    photo, pose = module.attendre_la_pose(photographier, double)
    assert double["fait"] and photo == "apres"


def test_chrome_android_parle_du_navigateur(banc):
    conf = json.loads(banc["conf"].read_text())
    conf.update(paquet="com.android.chrome", url="http://10.0.2.2:8000/")
    banc["conf"].write_text(json.dumps(conf))
    resultat = piloter(banc, "voir", "--", "Je regarde où je suis arrivé.")
    assert "Remarque : Le navigateur n'est plus au premier plan." in resultat.stdout


@pytest.mark.parametrize("donnes, faute", [
    ({"nombre": 2.5}, "nombre doit être un nombre entier"),
    ({"fautes": {"actif": "false"}}, "fautes.actif doit valoir vrai ou faux"),
    ({"pose": {"max": 3}, "double_toucher": {"actif": True, "seuil": 4}},
     "double_toucher.seuil doit rester sous pose.max"),
])
def test_des_reglages_trompeurs_sont_refuses(donnes, faute):
    module = lanceur()
    assert faute in " ; ".join(module.verifier_reglages(module.completer(module.DEFAUTS, donnes)))


def test_un_fichier_de_reglages_illisible_est_refuse(tmp_path):
    (tmp_path / "reglages.json").write_text("{\"nombre\": 3,}")
    resultat = subprocess.run([sys.executable, str(LANCEUR), "firefox", "--reglages",
                               str(tmp_path / "reglages.json"), "--fiche",
                               str(tmp_path / "fiche.txt"), "--sortie", str(tmp_path / "web"),
                               "--url", "http://127.0.0.1:1/"],
                              capture_output=True, text=True, timeout=30)
    assert resultat.returncode == 1
    assert "réglages refusés" in resultat.stderr and "Traceback" not in resultat.stderr


def test_une_faute_garde_la_casse_et_epargne_le_reste():
    module = module_pilote()
    conf = {"graine": 3, "options": {"fautes": True, "fautes_taux": 1.0}}
    tape = module.faire_des_fautes(conf, 1, "A 1 é")
    assert "1" in tape and "é" in tape and " " in tape
    assert all(c.isupper() for c in tape if c.isalpha() and c.isascii())


def test_la_memoire_courte_retire_les_vieilles_captures(banc):
    regler(banc, memoire_courte=True, memoire_ecrans=2)
    for n in range(5):
        piloter(banc, "voir", "--", f"Je regarde l'écran, coup numéro {n}.")
    restantes = sorted(c.name for c in (banc["testeur"] / "captures").glob("*.jpg"))
    assert restantes == ["004.jpg", "005.jpg"]
    assert sorted(c.name for c in (banc["nettes"] / "anciens").glob("*.jpg")) == [
        "001.jpg", "002.jpg", "003.jpg"]
    assert journal(banc)[-1]["capture"] == "captures/005.jpg"


def test_les_captures_oubliees_reviennent_au_rapatriement(banc, tmp_path):
    regler(banc, memoire_courte=True, memoire_ecrans=1)
    for n in range(3):
        piloter(banc, "voir", "--", f"Je regarde l'écran, coup numéro {n}.")
    sortie = tmp_path / "sortie"
    sortie.mkdir()
    lanceur().rapatrier(1, banc["testeur"], sortie, "{}", "", banc["nettes"])
    cible = sortie / "testeur-1"
    assert sorted(c.name for c in (cible / "captures").glob("*.jpg")) == [
        "001.jpg", "002.jpg", "003.jpg"]
    assert not (cible / "nettes" / "anciens").exists()


def test_la_memoire_courte_garde_le_dernier_coup_d_oeil(banc):
    """Des lectures à la suite ne retirent pas le coup d'œil où se lisent les coordonnées."""
    regler(banc, memoire_courte=True, memoire_ecrans=1)
    piloter(banc, "voir", "--", "Je regarde l'écran une première fois.")
    piloter(banc, "voir", "--", "Je regarde l'écran une deuxième fois.")
    for n in range(2):
        resultat = piloter(banc, "lire", "0", "0", "100", "100", "--", f"Je lis le coin, fois {n}.")
        assert resultat.returncode == 0, resultat.stderr
    restantes = sorted(c.name for c in (banc["testeur"] / "captures").glob("*.jpg"))
    assert restantes == ["002.jpg", "004.jpg"]


def test_l_interruption_tombe_une_fois(banc):
    regler(banc, interruption=True, interruption_geste=2, interruption_duree=0)
    piloter(banc, "voir", "--", "Premier regard sur l'écran.")
    resultat = piloter(banc, "voir", "--", "Deuxième regard sur l'écran.")
    assert "Tu as été interrompu 0 s, puis tu es revenu à l'app." in resultat.stdout
    assert journal(banc)[-1]["interruption"] == 0
    resultat = piloter(banc, "voir", "--", "Troisième regard sur l'écran.")
    assert "interrompu" not in resultat.stdout
    appels = (banc["outils"] / "appels.txt").read_text()
    assert appels.count("keyevent 3") == 1


def test_l_interruption_saute_une_lecture(banc):
    regler(banc, interruption=True, interruption_geste=2, interruption_duree=0)
    piloter(banc, "voir", "--", "Premier regard sur l'écran.")
    resultat = piloter(banc, "lire", "0", "0", "100", "100", "--", "Je lis le coin du haut.")
    assert "interrompu" not in resultat.stdout
    resultat = piloter(banc, "voir", "--", "Troisième regard sur l'écran.")
    assert "interrompu" in resultat.stdout


def test_le_web_retouche_et_s_interrompt(banc_web):
    regler(banc_web, double_toucher=True, double_seuil=0.5, interruption=True,
           interruption_geste=1, interruption_duree=0)
    (banc_web["ici"] / "ecrans-web").write_text("mire\n")
    resultat = piloter(banc_web, "toucher", "270", "600", "--", "Je touche le bouton du milieu.")
    assert resultat.returncode == 0, resultat.stderr
    assert (banc_web["ici"] / "demandes").read_text().splitlines() == ["retoucher",
                                                                        "interrompre 0"]
    ligne = journal(banc_web)[-1]
    assert ligne["double"] is True and ligne["interruption"] == 0
    assert "puis tu es revenu au site." in resultat.stdout


# ── La fenêtre de réglages ──────────────────────────────────────────────────────────────────


REGLER = SKILL / "scripts" / "regler.py"


def ouvrir_fenetre(sortie, *options):
    processus = subprocess.Popen([sys.executable, str(REGLER), "--sortie", str(sortie),
                                  "--sans-navigateur", "--delai", "20", *options],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    ligne = processus.stdout.readline()
    return processus, ligne.split()[-1]


def poster(adresse, donnees):
    import urllib.error
    import urllib.request
    demande = urllib.request.Request(adresse + "enregistrer", data=json.dumps(donnees).encode(),
                                     method="POST")
    try:
        with urllib.request.urlopen(demande, timeout=10) as reponse:
            return reponse.status, json.loads(reponse.read())
    except urllib.error.HTTPError as refus:
        return refus.code, json.loads(refus.read())


def test_la_fenetre_porte_les_defauts_du_lanceur(tmp_path):
    import urllib.request
    processus, adresse = ouvrir_fenetre(tmp_path / "run" / "reglages.json")
    try:
        page = urllib.request.urlopen(adresse, timeout=10).read().decode()
        assert "/*DONNEES*/null" not in page
        assert '"actions_max": 40' in page and '"Peu à l\'aise"' in page
    finally:
        processus.kill()


def test_la_fenetre_refuse_un_reglage_puis_ecrit_le_bon(tmp_path):
    sortie = tmp_path / "run" / "reglages.json"
    processus, adresse = ouvrir_fenetre(sortie)
    try:
        code, corps = poster(adresse, {"nombre": 99})
        assert code == 400 and "nombre" in corps["fautes"][0]
        assert not sortie.exists()
        code, corps = poster(adresse, {"nombre": 2, "fautes": {"actif": True}})
        assert code == 200
        assert processus.wait(timeout=10) == 0
    finally:
        processus.kill()
    ecrit = json.loads(sortie.read_text())
    assert ecrit["nombre"] == 2 and ecrit["fautes"] == {"actif": True, "taux": 5}
    assert ecrit["modele"] == "sonnet"


def test_la_fenetre_n_ecrase_pas_des_reglages(tmp_path):
    (tmp_path / "reglages.json").write_text("{}")
    resultat = subprocess.run([sys.executable, str(REGLER), "--sortie",
                               str(tmp_path / "reglages.json"), "--sans-navigateur"],
                              capture_output=True, text=True, timeout=10)
    assert resultat.returncode == 1 and "existe déjà" in resultat.stderr


def test_le_nombre_du_skill_ouvre_la_fenetre_reglee(tmp_path):
    import urllib.request
    processus, adresse = ouvrir_fenetre(tmp_path / "run" / "reglages.json", "--nombre", "4")
    try:
        page = urllib.request.urlopen(adresse, timeout=10).read().decode()
        donnees = json.loads(page.split("const DONNEES = ", 1)[1].split(";\n", 1)[0])
        assert donnees["initial"]["nombre"] == 4 and donnees["defauts"]["nombre"] == 3
    finally:
        processus.kill()
