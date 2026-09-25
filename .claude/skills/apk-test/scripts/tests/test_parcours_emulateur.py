"""Le verdict du parcours dans l'Android virtuel, joué sur de vraies sorties de runs.

POURQUOI CE FICHIER EXISTE
--------------------------
Le run 31431701893 du projet d'origine a été déclaré vert alors qu'aucun test n'avait tourné. Le
jeton de test manquait, Android a refusé la commande et répondu par sa page d'aide. Le contrôle
ne cherchait que des marques d'échec, il n'a rien trouvé et a conclu au succès.

C'est le défaut que toute cette chaîne est censée éliminer, un vert qui ne prouve rien. Le
verdict exige donc une preuve positive, et ces tests le soumettent aux sorties réelles relevées
sur la machine de build, pas à des imitations. Le paquet y est devenu `fr.exemple.app`, parce
que ce que le test éprouve est la forme `Displayed <paquet>/<activité>`, pas un projet.
"""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

SKILL = Path(__file__).resolve().parent.parent.parent
SCRIPT = SKILL / "scripts" / "parcours-emulateur.sh"
PARCOURS = SKILL / "references" / "ParcoursVisuelTest.kt"

# Les réglages passent par l'environnement : aucun fichier apk-test.env n'est écrit ici.
REGLAGES = {"PAQUET": "fr.exemple.app", "ACTIVITE_PRINCIPALE": ".MainActivity",
            "APK_TEST_REGLAGES": "/dev/null"}
ENV = {**os.environ, **REGLAGES}

# Extrait exact de la sortie du run 31431701893. `am instrument` a reçu une commande tronquée
# (jeton vide évaporé), a déroulé sa page d'aide et fini sur cette erreur. Aucun test n'a tourné.
COMMANDE_REFUSEE = """Activity manager (activity) commands:
  help
      Print this help text.
  start-activity [-D] [-N] [-W] [-P <FILE>] [--start-profiler <FILE>]
      Start an Activity.  Options are:

Error: Argument expected after "fr.exemple.app.test/androidx.test.runner.AndroidJUnitRunner"
"""

# La forme que prend un passage réussi d'AndroidJUnitRunner.
SUCCES = """INSTRUMENTATION_STATUS: numtests=3
INSTRUMENTATION_STATUS_CODE: 0

Time: 41.203

OK (3 tests)


INSTRUMENTATION_CODE: -1
"""

# Un test tombé : le résumé de JUnit ne laisse aucun doute.
ECHEC_DE_TEST = """INSTRUMENTATION_STATUS: numtests=3
Time: 12.1

FAILURES!!!
Tests run: 3,  Failures: 1


INSTRUMENTATION_CODE: -1
"""

# L'app se ferme brutalement pendant le parcours.
PLANTAGE = """INSTRUMENTATION_RESULT: shortMsg=Process crashed.
INSTRUMENTATION_CODE: 0
"""

# Extrait réel du journal système du run 31471955570. L'activité principale n'y apparaît jamais,
# malgré un JUnit « OK (3 tests) ». Seul un autre écran, ouvert par le troisième test, finit
# par s'afficher. Un dialogue système bloqué a recouvert tout le parcours.
JOURNAL_SANS_ACTIVITE = """08-11 08:27:56.411   486  2628 E ActivityManager: ANR in com.google.android.apps.nexuslauncher
08-11 08:30:55.448   486   519 I ActivityTaskManager: Displayed fr.exemple.app/.WelcomeActivity: +4s935ms
"""

# La même chose, mais l'activité principale s'affiche bien, la preuve positive attendue.
JOURNAL_AVEC_ACTIVITE = """08-11 08:28:11.203   486   519 I ActivityTaskManager: Displayed fr.exemple.app/.MainActivity: +2s340ms
"""

# Extrait réel du journal système du run 31967863064. Ce run a montré qu'un run peut être vert
# de bout en bout pendant que l'Android sous l'app se fait tuer. Les lignes sont recopiées telles
# quelles de l'artefact de ce run.
JOURNAL_MACHINE_MORTE = """08-16 19:44:05.270   489  4599 E ActivityManager: ANR in com.android.systemui
08-16 19:44:05.270   489  4599 E ActivityManager: Load: 45.83 / 18.2 / 6.74
08-16 19:44:08.803   489   576 I WindowManager: WIN DEATH: Window{5acc942 u0 NavigationBar0}
08-16 19:44:09.595   489  1683 I WindowManager: WIN DEATH: Window{af2b2ea u0 StatusBar}
08-16 19:44:10.398   489   529 I ActivityManager: Start proc 4838:com.android.systemui for restart
"""

# Notre app qui cesse de répondre. Invisible autrement : le script demande à Android de masquer
# les boîtes d'erreur, donc rien ne s'affiche et rien n'est photographié.
JOURNAL_ANR_DE_NOTRE_APP = """08-16 19:44:05.270   489  4599 E ActivityManager: ANR in fr.exemple.app
"""

# Machine lente mais entière : aucune fenêtre morte, aucun ANR. Les images restent lisibles, elles
# risquent seulement d'être prises trop tôt. On avertit, on ne fait pas rougir.
JOURNAL_MACHINE_LENTE = """08-16 19:44:05.270   489  4599 E ActivityManager: Load: 21.40 / 9.1 / 3.2
08-16 19:44:11.203   489   519 I ActivityTaskManager: Displayed fr.exemple.app/.MainActivity: +3s390ms
"""


def _lancer(*args: str, env: dict | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(["bash", str(SCRIPT), *args], capture_output=True, text=True,
                          env=ENV if env is None else env)


def _verdict(contenu: str, tmp_path: Path, journal: str | None = None) -> bool:
    """Rend vrai si le verdict conclut au succès."""
    fichier = tmp_path / "resultat.txt"
    fichier.write_text(contenu, encoding="utf-8")
    args = ["--verdict", str(fichier)]
    if journal is not None:
        fichier_journal = tmp_path / "journal.txt"
        fichier_journal.write_text(journal, encoding="utf-8")
        args.append(str(fichier_journal))
    return _lancer(*args).returncode == 0


def _sante(journal: str, tmp_path: Path) -> subprocess.CompletedProcess:
    """Passe un journal système au contrôle de santé et rend le résultat complet."""
    fichier = tmp_path / "journal.txt"
    fichier.write_text(journal, encoding="utf-8")
    return _lancer("--sante", str(fichier))


def _code(fichier: Path, marque: str = "#") -> list[str]:
    """Les lignes de code seules. Lire du commentaire, c'est ne rien tester."""
    return [l for l in fichier.read_text(encoding="utf-8").splitlines()
            if not l.lstrip().startswith(marque)]


# ── Les réglages ─────────────────────────────────────────────────────────────────────────────

def test_sans_reglage_le_script_refuse_en_nommant_la_cle(tmp_path):
    """Un paquet par défaut désignerait un projet réel, et un verdict rendu sur le mauvais paquet
    dirait « jamais affichée » à tort. Le refus nomme la clé, pour qu'on sache quoi écrire."""
    fichier = tmp_path / "resultat.txt"
    fichier.write_text(SUCCES, encoding="utf-8")
    env = {k: v for k, v in ENV.items() if k != "PAQUET"}
    r = _lancer("--verdict", str(fichier), env=env)
    assert r.returncode == 1
    assert "PAQUET" in r.stderr


def test_le_fichier_de_reglages_est_lu_et_l_environnement_gagne(tmp_path):
    """La CI passe ses secrets par l'environnement. Une valeur du fichier ne doit pas l'écraser."""
    fichier = tmp_path / "apk-test.env"
    fichier.write_text("PAQUET=fr.fichier.app\nACTIVITE_PRINCIPALE=.Fichier\n", encoding="utf-8")
    resultat = tmp_path / "resultat.txt"
    resultat.write_text(SUCCES, encoding="utf-8")
    journal = tmp_path / "journal.txt"
    journal.write_text("Displayed fr.fichier.app/.Fichier: +1s\n", encoding="utf-8")
    env = {k: v for k, v in os.environ.items() if k not in ("PAQUET", "ACTIVITE_PRINCIPALE")}
    env["APK_TEST_REGLAGES"] = str(fichier)
    assert _lancer("--verdict", str(resultat), str(journal), env=env).returncode == 0
    env["PAQUET"] = "fr.environnement.app"
    assert _lancer("--verdict", str(resultat), str(journal), env=env).returncode == 1


# ── Le verdict ───────────────────────────────────────────────────────────────────────────────

def test_une_commande_refusee_par_android_ne_passe_pas_pour_un_succes(tmp_path):
    """Régression du 2026-08-10, run 31431701893, le cas qui a produit un faux vert.

    Cette sortie ne contient aucune marque d'échec, pour la meilleure des raisons : il ne s'est
    rien passé. L'ancien contrôle n'a rien trouvé et a écrit « parcours terminé sans échec »."""
    assert not _verdict(COMMANDE_REFUSEE, tmp_path)


def test_une_sortie_vide_ne_passe_pas_non_plus(tmp_path):
    """Même famille de piège : l'absence de preuve n'est pas une preuve d'absence de problème."""
    assert not _verdict("", tmp_path)


def test_un_vrai_passage_est_reconnu(tmp_path):
    """Le pendant indispensable : un contrôle qui refuse tout ne vaut pas mieux qu'un contrôle
    qui accepte tout. Il serait simplement contourné au bout de deux runs."""
    assert _verdict(SUCCES, tmp_path)


def test_un_test_tombe_fait_rougir(tmp_path):
    assert not _verdict(ECHEC_DE_TEST, tmp_path)


def test_un_plantage_de_l_app_fait_rougir(tmp_path):
    """Ici `INSTRUMENTATION_CODE` vaut 0 : le processus est mort avant la fin."""
    assert not _verdict(PLANTAGE, tmp_path)


@pytest.mark.parametrize("marque", ["FAILURES!!!", "Process crashed", "INSTRUMENTATION_CODE: 0"])
def test_chaque_marque_d_echec_est_bien_attrapee(marque, tmp_path):
    """Chaque marque prise isolément, pour qu'aucune ne puisse être retirée sans qu'un test
    rougisse. Trois marques dans un même `grep`, on en supprime une, tout reste vert."""
    assert not _verdict(f"OK (3 tests)\n{marque}\nINSTRUMENTATION_CODE: -1\n", tmp_path)


def test_le_run_du_11_08_est_detecte(tmp_path):
    """Régression du 2026-08-11, run 31471955570, le deuxième faux vert.

    JUnit disait « OK (3 tests) », des images existaient. En réalité un dialogue système bloqué a
    recouvert tout le parcours et l'activité principale n'a jamais pris l'écran."""
    assert not _verdict(SUCCES, tmp_path, journal=JOURNAL_SANS_ACTIVITE)


def test_l_activite_reellement_affichee_passe(tmp_path):
    """Le pendant indispensable : un run où l'activité apparaît dans le journal reste vert."""
    assert _verdict(SUCCES, tmp_path, journal=JOURNAL_AVEC_ACTIVITE)


def test_sans_journal_fourni_seul_junit_decide(tmp_path):
    """Rétrocompatibilité explicite : la preuve d'affichage est sautée sans journal, jamais un
    échec par défaut."""
    assert _verdict(SUCCES, tmp_path)


def test_le_jeton_n_est_transmis_que_s_il_existe():
    """Régression du 2026-08-10 : un argument vide traverse un second interpréteur, celui du
    téléphone, qui le fait disparaître. Le nom du robot est alors avalé comme valeur du jeton et
    Android refuse tout. Le script construit donc ses arguments, il ne les écrit pas en dur."""
    code = _code(SCRIPT)
    en_dur = [l for l in code if "$JETON_TEST" in l and "set --" not in l
              and "-n \"$JETON_TEST\"" not in l and "JETON_TEST:-" not in l
              and "#JETON_TEST" not in l and "film_lisible" not in l]
    assert not en_dur, f"le jeton est écrit en dur dans la commande : {en_dur}"
    assert any('if [ -n "$JETON_TEST" ]' in l for l in code), \
        "le script ne teste plus la présence du jeton avant de le passer"


def test_le_plancher_de_captures_est_derive_du_parcours():
    """Une seule image sur la douzaine attendue passait pour un succès. L'attendu vient du
    fichier Kotlin, et une extraction cassée rougit au lieu de retomber sur zéro."""
    code = _code(SCRIPT)
    assert any("captures-attendues.py" in l for l in code), \
        "le seuil dérivé a disparu : le plancher est retombé à zéro sans que rien ne le dise"
    assert any("seuil-inderivable" in l for l in code), \
        "une extraction cassée doit rougir, jamais se rabattre sur un plancher nul"


def test_les_moutures_sans_seuil_derive_gardent_le_plancher_zero():
    """Le seuil dérivé ne vise que les moutures du réglage. Le remplacer avait retiré toute porte
    aux autres : un parcours release sans une seule image partait vert."""
    code = _code(SCRIPT)
    assert any('[ "$images" -eq 0 ]' in l for l in code), "hors seuil dérivé, zéro image ne rougit plus"


# ── La santé de la machine ───────────────────────────────────────────────────────────────────

def test_le_run_du_16_08_est_detecte_comme_machine_morte(tmp_path):
    """Régression du 2026-08-16, run 31967863064, le troisième faux vert.

    Toutes les preuves passaient, et pendant ce temps SystemUI s'est fait tuer deux fois. Les
    bandes noires sur les images ont été prises pour des défauts de l'app."""
    assert _sante(JOURNAL_MACHINE_MORTE, tmp_path).returncode != 0


def test_un_anr_de_notre_app_fait_rougir(tmp_path):
    """L'ANR de notre propre app n'a aucun autre détecteur : le script masque les boîtes d'erreur,
    et JUnit ne tombe pas pour autant."""
    assert _sante(JOURNAL_ANR_DE_NOTRE_APP, tmp_path).returncode != 0


def test_une_machine_seulement_lente_avertit_sans_faire_rougir(tmp_path):
    """Une charge élevée n'invalide pas les images, elle explique qu'elles partent trop tôt."""
    resultat = _sante(JOURNAL_MACHINE_LENTE, tmp_path)
    assert resultat.returncode == 0
    assert "::warning::" in resultat.stdout, "la lenteur doit au moins être dite"


def test_le_seuil_de_charge_est_un_reglage(tmp_path):
    """Posé faute d'observation, il se révise à la première fausse alerte. Sans le recompiler."""
    fichier = tmp_path / "journal.txt"
    fichier.write_text(JOURNAL_MACHINE_LENTE, encoding="utf-8")
    r = _lancer("--sante", str(fichier), env={**ENV, "SEUIL_CHARGE": "30"})
    assert r.returncode == 0
    assert "::warning::" not in r.stdout


def test_un_journal_sain_passe(tmp_path):
    """Sans quoi le contrôle serait un refus par défaut déguisé."""
    assert _sante(JOURNAL_AVEC_ACTIVITE, tmp_path).returncode == 0


def test_journal_absent_ne_fait_pas_rougir(tmp_path):
    """Pas de journal = information manquante, pas échec. On le dit, on ne l'invente pas."""
    fichier = tmp_path / "vide.txt"
    fichier.write_text("", encoding="utf-8")
    assert _lancer("--sante", str(fichier)).returncode == 0


def test_la_sante_de_la_machine_est_bien_branchee_sur_le_parcours():
    """Le contrôle peut être parfait et n'être appelé nulle part."""
    assert any('sante_machine "$SORTIE/logcat-$mouture.txt"' in l for l in _code(SCRIPT)), \
        "sante_machine n'est plus appelé sur le journal de la mouture"


# ── Le film est-il regardable ? ──────────────────────────────────────────────────────────────

FFMPEG = pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg absent")


def _film(tmp_path: Path, film: Path | str, journal: str = "", jeton: str = "") -> \
        subprocess.CompletedProcess:
    fichier = tmp_path / "logcat.txt"
    fichier.write_text(journal, encoding="utf-8")
    return _lancer("--film", str(film), str(fichier), jeton)


def _mp4(tmp_path: Path, nom: str, secondes: int = 2) -> Path:
    """Un vrai MP4, fabriqué par ffmpeg. Une imitation ne prouverait rien sur un format."""
    chemin = tmp_path / nom
    subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "testsrc=size=64x64:rate=5",
                    "-t", str(secondes), "-pix_fmt", "yuv420p", str(chemin), "-y"], check=True)
    return chemin


@FFMPEG
def test_un_film_decodable_passe(tmp_path):
    """Le pendant indispensable du test suivant : un contrôle qui refuse tout est contourné."""
    assert _film(tmp_path, _mp4(tmp_path, "ok.mp4")).returncode == 0


@FFMPEG
def test_un_film_indecodable_fait_rougir(tmp_path):
    """Régression du 2026-08-19, run 32254733286. L'atome `moov` s'écrit à la fermeture du
    fichier. Un enregistrement jamais arrêté laisse un fichier gros et sans une image décodable."""
    entier = _mp4(tmp_path, "ok.mp4").read_bytes()
    tronque = tmp_path / "navigation.mp4"
    tronque.write_bytes(entier[:len(entier) // 2])
    r = _film(tmp_path, tronque)
    assert r.returncode == 1
    assert "INDÉCODABLE" in r.stdout


@FFMPEG
def test_un_film_sans_duree_fait_rougir_aussi(tmp_path):
    """Vérifié sur ce flux : ffprobe imprime « N/A » et sort en 0 sur un H.264 brut. Un test
    « durée vide » le laissait passer, et le film était déclaré regardable sans une image."""
    brut = tmp_path / "navigation.h264"
    subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "testsrc=size=64x64:rate=5",
                    "-t", "2", "-pix_fmt", "yuv420p", "-f", "h264", str(brut), "-y"], check=True)
    r = _film(tmp_path, brut)
    assert r.returncode == 1
    assert "INDÉCODABLE" in r.stdout


def test_ffprobe_absent_fait_rougir(tmp_path):
    """Le contrôle est resté muet des semaines parce que son absence n'était qu'un avertissement.
    Une panne d'outillage doit se voir, pas se taire."""
    film = tmp_path / "navigation.mp4"
    film.write_bytes(b"\x00" * 4096)
    # Un PATH réduit à un dossier vide, mais bash appelé par son chemin absolu. Sans ça, c'est
    # l'interpréteur qui devient introuvable, et le test ne prouve plus rien sur ffprobe.
    vide = tmp_path / "sans-outils"
    vide.mkdir()
    env = {**REGLAGES, "PATH": str(vide)}
    r = subprocess.run([shutil.which("bash"), str(SCRIPT), "--film", str(film)],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 1
    assert "ffprobe absent" in r.stdout


def test_un_film_absent_fait_rougir_quand_le_jeton_etait_la(tmp_path):
    """Avec un jeton, le parcours filmé devait tourner. Ne rien enregistrer est un défaut."""
    assert _film(tmp_path, tmp_path / "jamais-ecrit.mp4", jeton="un-jeton").returncode == 1


def test_un_film_absent_sans_jeton_avertit_seulement(tmp_path):
    """Sans jeton, `Assume` saute le parcours filmé. Punir cette absence rendrait rouge tout run
    lancé pour vérifier autre chose."""
    r = _film(tmp_path, tmp_path / "jamais-ecrit.mp4")
    assert r.returncode == 0
    assert "::warning::" in r.stdout


def test_le_controle_du_film_est_bien_branche_sur_le_parcours():
    """Le motif « le contrôle est parfait, et il n'est appelé nulle part »."""
    code = _code(SCRIPT)
    assert any('film_lisible "$film"' in l for l in code), "film_lisible n'est plus appelé"
    assert any("mouture-film" in l for l in code), "un film illisible ne remonte plus en échec"


def test_screenrecord_est_arrete_avant_le_rapatriement():
    """Rien n'arrêtait l'enregistrement : le processus mourait avec l'instrumentation, et le
    fichier n'était jamais fermé. Rapatrier pendant l'écriture donne le même symptôme."""
    code = _code(SCRIPT)
    arret = next(i for i, l in enumerate(code) if "pkill -INT screenrecord" in l)
    pull = next(i for i, l in enumerate(code) if l.strip().startswith("adb pull"))
    assert arret < pull, "le film est rapatrié avant d'avoir été arrêté, donc jamais fermé"


def test_le_gabarit_arrete_son_film_avant_de_rendre_la_main():
    """Le test abandonnait screenrecord au lieu de l'arrêter. L'ordre est tout : demander
    l'arrêt après avoir attendu la fin ne fermerait jamais le fichier."""
    code = _code(PARCOURS, marque="//")
    arret = next(i for i, l in enumerate(code) if "pkill -INT screenrecord" in l)
    attente = next(i for i, l in enumerate(code) if "enregistrement.join" in l)
    assert arret < attente, "on attend la fin du film avant d'en demander l'arrêt, donc pour rien"
    finally_ = next(i for i, l in enumerate(code) if l.strip() == "} finally {")
    assert finally_ < arret, "l'arrêt du film n'est pas dans un finally : une assertion tombée le saute"
    assert any("isAlive" in l for l in code), "rien ne dit plus qu'un film non rendu est tronqué"


# ── Où le contrôle cherche-t-il le film ? (run 25 du projet d'origine, 2026-09-17) ───────────
#
# Le job de test a rougi sur « aucun film ». Trois tests passaient pourtant, les onze captures
# étaient là, et un `navigation.mp4` de 3 953 964 octets venait d'être rapatrié.
#
# Le défaut ne vivait PAS dans `film_lisible`, que les tests ci-dessus couvraient déjà. Il vivait
# dans la CONSTRUCTION du chemin, que rien ne couvrait.
#
# Le bloc de trace ANR crée le dossier de sortie avant le rapatriement. Le rapatriement niche
# alors son contenu d'un cran, et le contrôle lisait un chemin plat. Le compte de captures
# passait, lui, parce qu'il cherche en récursif.
#
# La leçon est celle du fichier entier. Un contrôle exact nourri d'une entrée fausse rend un
# verdict faux, et ce sont deux surfaces distinctes à couvrir.

def _trouver(dossier: Path) -> str:
    r = subprocess.run(["bash", str(SCRIPT), "--trouver-film", str(dossier)],
                       capture_output=True, text=True, env=ENV)
    assert r.returncode == 0, r.stderr
    return r.stdout.strip()


def test_le_film_est_trouve_a_la_racine_du_dossier(tmp_path):
    """La disposition plate, celle que le script attendait. Elle doit continuer de marcher."""
    (tmp_path / "navigation.mp4").write_bytes(b"x")
    assert _trouver(tmp_path) == str(tmp_path / "navigation.mp4")


def test_le_film_est_trouve_dans_le_sous_dossier_du_rapatriement(tmp_path):
    """LE CAS FONDATEUR, reproduit tel que le journal du run 25 le montre.

    Le rapatriement a déposé son contenu sous `<sortie>/parcours/`. Le dossier `anr` existait
    déjà, et c'est lui qui a fait exister la destination, donc qui a provoqué la nidification."""
    (tmp_path / "anr").mkdir()
    niche = tmp_path / "parcours"
    niche.mkdir()
    (niche / "navigation.mp4").write_bytes(b"x")
    (niche / "00-accueil.png").write_bytes(b"x")
    assert _trouver(tmp_path) == str(niche / "navigation.mp4")


def test_le_nom_du_film_vient_du_reglage(tmp_path):
    """Le skill sert des projets qui ne nomment pas tous leur film `navigation.mp4`.

    La recherche porte sur NOM_FILM, jamais sur un nom gravé. Le graver rendrait la fonction
    muette chez le premier projet qui le change, et le chemin plat reviendrait sans bruit."""
    niche = tmp_path / "parcours"
    niche.mkdir()
    (niche / "film-du-parcours.mp4").write_bytes(b"x")
    r = subprocess.run(["bash", str(SCRIPT), "--trouver-film", str(tmp_path)],
                       capture_output=True, text=True,
                       env={**ENV, "NOM_FILM": "film-du-parcours.mp4"})
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == str(niche / "film-du-parcours.mp4")


def test_sans_film_le_chemin_plat_reste_le_repli(tmp_path):
    """Un chemin nommé plutôt qu'une chaîne vide, pour qui lit le journal ou débogue.

    Le verdict serait le même sans ce repli, `film_lisible` traitant un argument vide comme un
    fichier absent. Ce que le repli change est ailleurs. La variable `film` vaut un chemin
    lisible, et non du vide, partout où le script ou un humain la regarde ensuite."""
    (tmp_path / "anr").mkdir()
    assert _trouver(tmp_path) == str(tmp_path / "navigation.mp4")


def test_la_localisation_du_film_est_bien_branchee_sur_le_parcours():
    """Sans cette assertion, le correctif se désarme en silence.

    Le drapeau pourrait rester juste et exercé pendant que la boucle du parcours, elle, revient
    au chemin plat. C'est exactement ce qui s'est passé pour la santé de la machine, restée muette
    des semaines alors que sa fonction était bonne. Le portage vers ce skill l'a refait. La
    fonction avait disparu, le chemin plat était revenu, et aucun test ne le voyait."""
    code = _code(SCRIPT)
    pose = next(l for l in code if l.strip().startswith("film=") and "chemin_du_film" in l)
    assert "$SORTIE/$mouture" in pose
    assert not any(l.strip() == 'film="$SORTIE/$mouture/$NOM_FILM"' for l in code), \
        "le chemin plat est revenu dans la boucle, la nidification n'est plus vue"


def test_le_rapatriement_cherche_le_film_lui_aussi():
    """L'artefact téléchargé porte la MÊME nidification que le dossier de sortie : c'est le même
    `adb pull` qui l'a produit, en amont. Un chemin plat ici fait échouer `film_lisible`, le
    `continue` est pris, et la découpe du film n'a jamais lieu. C'est l'étape 3 du script."""
    code = _code(SKILL / "scripts" / "rapatrier-parcours.sh")
    pose = next(l for l in code if l.strip().startswith("film=") )
    assert "--trouver-film" in pose, "le rapatriement fige encore le chemin du film"


def test_la_passe_des_changements_de_scene_laisse_parler_showinfo():
    """Une panne MUETTE de la découpe du film, du genre que ce dépôt traque.

    `showinfo` écrit ses lignes au niveau INFO de ffmpeg. Sous `-v error`, le relevé des
    changements d'écran sortait donc TOUJOURS vide. Les images, elles, étaient bien écrites, et
    rien ne distinguait « aucun changement » de « je n'ai pas su lire ».

    Mesuré ici le 2026-09-21, sur un film à trois plans unis. Zéro correspondance `pts_time`
    avec `-v error`, deux avec `-v info`, et les mêmes deux images dans les deux cas."""
    code = _code(SKILL / "scripts" / "rapatrier-parcours.sh")
    passe = next(l for l in code if "showinfo" in l)
    assert "-v info" in passe, "showinfo est de nouveau bâillonné par -v error"
