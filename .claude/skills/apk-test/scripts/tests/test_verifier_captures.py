"""Le contrôle « tout écran modifié est photographié ».

POURQUOI CE FICHIER EXISTE
--------------------------
Le script d'origine n'avait aucun test, et il est parti en panne muette. Au run 32254733286, il a
imprimé « aucun écran modifié » sans avoir rien comparé. Le run est parti vert.

La cause tient en une ligne de git. `git rev-parse` écrit son argument sur sa sortie standard
quand il ne sait pas le résoudre, avant de sortir en 128. La base valait donc la chaîne « HEAD~1 »,
jamais vide, et le garde-fou « aucune base » restait inatteignable.

Ces tests lancent le vrai script sur des dépôts git jetables. Le script résout sa racine depuis
son propre chemin, on y recopie donc le dossier des scripts du skill, et un fichier de réglages.
"""
import shutil
import subprocess
from pathlib import Path

import pytest

SKILL = Path(__file__).resolve().parent.parent.parent
SCRIPTS = SKILL / "scripts"
JOB = SKILL / "references" / "job-tester.yml"

LAYOUTS = "app/src/main/res/layout"
REGLAGES = f"""PAQUET=fr.exemple.app
ACTIVITE_PRINCIPALE=.MainActivity
PARCOURS_KT=app/src/androidTest/ParcoursVisuelTest.kt
ECRANS_GLOBS={LAYOUTS}/* app/src/main/java/*Activity.kt
ECRANS_EXCLUS=feuille_*|*_item
"""

pytestmark = pytest.mark.skipif(shutil.which("git") is None, reason="git absent")


def _git(depot: Path, *args: str) -> None:
    subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", *args],
                   cwd=depot, check=True, capture_output=True)


def _depot(tmp_path: Path, ecrans: tuple[str, ...] = ()) -> Path:
    """Un dépôt jetable portant une copie des scripts, ses réglages, et un premier commit."""
    depot = tmp_path / "depot"
    cible = depot / ".claude" / "skills" / "apk-test" / "scripts"
    shutil.copytree(SCRIPTS, cible, ignore=shutil.ignore_patterns("tests", "__pycache__"))
    (depot / "apk-test.env").write_text(REGLAGES, encoding="utf-8")
    (depot / LAYOUTS).mkdir(parents=True)
    for nom in ecrans:
        (depot / LAYOUTS / nom).write_text("<View/>\n", encoding="utf-8")
    _git(depot, "init", "-q", ".")
    _git(depot, "add", "-A")
    _git(depot, "commit", "-q", "-m", "premier")
    return depot


def _toucher(depot: Path, nom: str) -> None:
    """Modifie un écran et committe : le script compare l'état courant à un commit antérieur."""
    (depot / LAYOUTS / nom).write_text("<View android:id=\"@+id/neuf\"/>\n", encoding="utf-8")
    _git(depot, "add", "-A")
    _git(depot, "commit", "-q", "-m", f"touche {nom}")


def _lancer(depot: Path, captures: Path) -> subprocess.CompletedProcess:
    script = depot / ".claude" / "skills" / "apk-test" / "scripts" / "verifier-captures.sh"
    return subprocess.run(["bash", str(script), str(captures)], capture_output=True, text=True)


def _captures(tmp_path: Path, *noms: str) -> Path:
    dossier = tmp_path / "captures"
    dossier.mkdir(exist_ok=True)
    for nom in noms:
        (dossier / nom).write_bytes(b"\x89PNG")
    return dossier


def test_une_base_irresoluble_ne_passe_pas_pour_un_diff_vide(tmp_path):
    """Régression du 2026-08-19, run 32254733286, le cas qui a produit un faux succès.

    Un dépôt d'un seul commit n'a pas de `HEAD~1`, comme le clone superficiel d'une chaîne CI.
    Un contrôle qui n'a pas pu s'exercer doit le dire."""
    depot = _depot(tmp_path, ("activity_creation.xml",))
    r = _lancer(depot, _captures(tmp_path, "04-creation.png"))
    assert "N'A RIEN VÉRIFIÉ" in r.stdout, "une panne du contrôle doit se voir"
    assert "aucun écran modifié" not in r.stdout, \
        "un contrôle qui n'a rien comparé se déguisait en « rien n'a bougé »"


def test_un_ecran_modifie_sans_capture_fait_rougir(tmp_path):
    """La promesse même du script : un écran touché et jamais photographié est un écran livré
    sans avoir été vu."""
    depot = _depot(tmp_path, ("activity_creation.xml",))
    _toucher(depot, "activity_creation.xml")
    r = _lancer(depot, _captures(tmp_path, "01-demarrage.png"))
    assert r.returncode == 1
    assert "creation" in r.stdout


def test_un_ecran_modifie_avec_sa_capture_passe(tmp_path):
    """Le pendant indispensable : un contrôle qui refuse tout est contourné en deux runs."""
    depot = _depot(tmp_path, ("activity_creation.xml",))
    _toucher(depot, "activity_creation.xml")
    assert _lancer(depot, _captures(tmp_path, "04-creation.png")).returncode == 0


def test_les_captures_sont_cherchees_dans_les_sous_dossiers(tmp_path):
    """Depuis qu'on teste plusieurs moutures, les images sont rangées par mouture."""
    depot = _depot(tmp_path, ("activity_creation.xml",))
    _toucher(depot, "activity_creation.xml")
    dossier = _captures(tmp_path)
    (dossier / "debug").mkdir()
    (dossier / "debug" / "04-creation.png").write_bytes(b"\x89PNG")
    assert _lancer(depot, dossier).returncode == 0


def test_un_fragment_d_interface_exclu_par_le_projet_n_est_pas_exigible(tmp_path):
    """Une feuille ou un élément de liste n'est pas une destination. Le projet les nomme dans
    ECRANS_EXCLUS, vide par défaut : un projet neuf exige tout."""
    depot = _depot(tmp_path, ("feuille_photos.xml",))
    _toucher(depot, "feuille_photos.xml")
    assert _lancer(depot, _captures(tmp_path, "01-demarrage.png")).returncode == 0


def test_sans_exclusion_un_fragment_est_exige(tmp_path):
    """Le pendant : la liste d'exclusion est celle du projet, pas une liste cachée du script."""
    depot = _depot(tmp_path, ("feuille_photos.xml",))
    (depot / "apk-test.env").write_text(REGLAGES.replace("ECRANS_EXCLUS=feuille_*|*_item\n", ""),
                                        encoding="utf-8")
    _git(depot, "commit", "-q", "-am", "sans exclusion")
    _toucher(depot, "feuille_photos.xml")
    assert _lancer(depot, _captures(tmp_path, "01-demarrage.png")).returncode == 1


def test_un_dossier_de_captures_vide_avertit_sans_rougir(tmp_path):
    """Sans jeton de test, le parcours authentifié ne tourne pas. Échouer ici punirait une
    absence de configuration, pas un défaut de l'app."""
    depot = _depot(tmp_path, ("activity_creation.xml",))
    _toucher(depot, "activity_creation.xml")
    r = _lancer(depot, _captures(tmp_path))
    assert r.returncode == 0
    assert "::warning::" in r.stdout


def test_sans_reglage_des_ecrans_le_script_refuse(tmp_path):
    """Sans motif d'écrans, le script ne pourrait que comparer à rien et passer au vert."""
    depot = _depot(tmp_path, ("activity_creation.xml",))
    (depot / "apk-test.env").write_text("PAQUET=fr.exemple.app\nACTIVITE_PRINCIPALE=.M\n",
                                        encoding="utf-8")
    r = _lancer(depot, _captures(tmp_path, "04-creation.png"))
    assert r.returncode == 1
    assert "ECRANS_GLOBS" in r.stderr


def test_le_verificateur_est_bien_appele_par_le_job():
    """Le motif « le contrôle est parfait, et il n'est branché nulle part »."""
    assert "verifier-captures.sh" in JOB.read_text(encoding="utf-8")


def test_le_clone_du_job_porte_de_quoi_resoudre_la_base():
    """L'autre moitié du correctif. `rev-parse --verify` sans `fetch-depth` rendrait le contrôle
    jaune à chaque run, et un garde-fou qui crie toujours finit ignoré."""
    assert "fetch-depth: 0" in JOB.read_text(encoding="utf-8")


def test_le_bloc_script_du_job_tient_sur_une_ligne():
    """L'action découpe le bloc `script:` ligne par ligne (run 31428980946). Une boucle sur
    plusieurs lignes y est amputée."""
    lignes = JOB.read_text(encoding="utf-8").splitlines()
    scripts = [l for l in lignes if l.strip().startswith("script:")]
    assert scripts, "le job n'appelle plus le parcours"
    for l in scripts:
        assert not l.rstrip().endswith("|") and not l.rstrip().endswith(">"), \
            "le bloc script: est sur plusieurs lignes, l'action l'amputera"


# ── Une capture est une IMAGE (trouvé en revue au portage, 2026-09-21) ───────────────────────
#
# Le dossier que le job passe au script est celui où le parcours a TOUT écrit. Les images, mais
# aussi `echecs.txt`, `resultat-<mouture>.txt`, `logcat-<mouture>.txt` et le film. Le script
# lisait « un fichier », d'où deux défauts jumeaux couverts ici.

def test_un_dossier_sans_image_declenche_la_tolerance(tmp_path):
    """La tolérance « aucune capture » était INATTEIGNABLE telle que le job la câble.

    Elle testait si le DOSSIER est vide. Or le parcours y écrit toujours ses journaux, même quand
    il n'a produit aucune image faute de jeton. Le script partait donc en mode strict et
    rougissait sur chaque écran modifié, exactement ce que cette tolérance existe pour éviter."""
    depot = _depot(tmp_path, ("activity_creation.xml",))
    _toucher(depot, "activity_creation.xml")
    dossier = tmp_path / "captures"
    dossier.mkdir()
    (dossier / "echecs.txt").write_text("", encoding="utf-8")
    (dossier / "logcat-debug.txt").write_text("rien\n", encoding="utf-8")
    r = _lancer(depot, dossier)
    assert r.returncode == 0
    assert "aucune capture produite" in r.stdout


def test_le_film_ne_photographie_aucun_ecran(tmp_path):
    """Le nom du film est celui d'un écran chez plus d'un projet. Un écran « navigation » était
    déclaré photographié par `navigation.mp4`, qui ne montre rien à qui lit des images."""
    depot = _depot(tmp_path, ("activity_navigation.xml",))
    _toucher(depot, "activity_navigation.xml")
    dossier = _captures(tmp_path, "01-demarrage.png")
    (dossier / "navigation.mp4").write_bytes(b"\x00\x00\x00 ftyp")
    r = _lancer(depot, dossier)
    assert r.returncode == 1, "le film passait pour la capture de l'écran « navigation »"
    assert "navigation" in r.stdout
