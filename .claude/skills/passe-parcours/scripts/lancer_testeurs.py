#!/usr/bin/env python3
"""Lance les testeurs de la passe parcours, chacun enfermé avec son appareil.

POURQUOI CE FICHIER EXISTE
--------------------------
Un sous-agent de la session voit le projet avant son premier geste. Mesuré le 2026-11-16 : il
reçoit le chemin du dépôt, son `git status`, ses derniers commits et ses fichiers d'instructions.
Un testeur qui doit découvrir l'app ne peut pas naître là.

Chaque testeur est donc une session `claude -p` à part, née dans un dossier neutre. Elle ne
charge aucun réglage, aucun serveur d'outils, aucune mémoire. Elle n'a que deux droits.

- Lancer `./piloter`, qui agit sur son appareil et le photographie.
- Lire les fichiers de son propre dossier, donc ses coups d'œil et ce qu'il a lu.

Tout le reste est refusé par le mode `dontAsk`. Vérifié le même jour : lire un fichier du
projet, lancer `ls /`, ou enchaîner une commande après `./piloter`, tout part en refus.

Refait le 2026-11-19 pour le dossier des captures nettes, voisin de celui du testeur. Le lire
par `Read`, en chemin relatif ou absolu, part en refus. Par `cat`, ou caché dans un appel à
`./piloter`, aussi.

CE QU'IL FAIT, pour chaque testeur
----------------------------------
1. Prépare un appareil neuf, un émulateur en lecture seule ou un Chromium au profil vide.
2. Pose `./piloter` dans le dossier neutre, et hors de ce dossier sa configuration et le dossier
   de ses captures nettes. Le testeur ne reçoit que des coups d'œil flous.
3. Lance la session du testeur, avec la consigne et la forme du rapport.
4. Rapatrie captures, journal et rapport dans le dossier de sortie, puis rend l'appareil.

COMMENT ON S'EN SERT
--------------------
    python3 lancer_testeurs.py android --nombre 3 --fiche fiche.txt --sortie <resultats>/android \\
        --apk app.apk --paquet org.exemple.app --avd Mon_telephone
    python3 lancer_testeurs.py web --nombre 3 --fiche fiche.txt --sortie <resultats>/web \\
        --url http://127.0.0.1:8000/ --node-path <dossier>/node_modules
Le dossier de sortie doit être neuf. Un dossier existant se refuse, pour ne jamais écraser un run
payé.
"""
import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ICI = Path(__file__).resolve().parent
REFERENCES = ICI.parent / "references"
# La largeur de travail des captures Android. Assez pour lire un texte courant, assez peu pour
# qu'une quarantaine d'images tienne dans le contexte d'un testeur.
LARGEUR_CAPTURE = 540
# Le démarrage d'un émulateur à froid a pris une minute sur la machine de l'admin.
DEMARRAGE_MAX = 300
SESSION_MAX = 45 * 60
PORT_EMULATEUR, PORT_CDP = 5560, 9320


def dire(message):
    print(f"passe-parcours : {message}", flush=True)


def echouer(message):
    print(f"passe-parcours : {message}", file=sys.stderr)
    sys.exit(1)


# ── Les outils ──────────────────────────────────────────────────────────────────────────────


def trouver_claude():
    """Le binaire `claude`, réglé, installé, ou celui que l'appli de bureau embarque."""
    candidats = [os.environ.get("PASSE_PARCOURS_CLAUDE"), shutil.which("claude")]
    embarques = glob.glob(os.path.expanduser("~/.config/Claude/claude-code/*/*/claude"))
    candidats += sorted(embarques, key=lambda c: [int(p) if p.isdigit() else 0
                                                  for p in Path(c).parts[-3].split(".")])[::-1]
    for candidat in candidats:
        if candidat and os.access(candidat, os.X_OK):
            return candidat
    echouer("le binaire claude est introuvable. Le désigner par PASSE_PARCOURS_CLAUDE.")


def verifier_outils(args):
    """Un outil absent se signale et arrête tout, il ne se contourne pas."""
    manquants = [o for o in ("ffmpeg", "ffprobe") if not shutil.which(o)]
    if args.plateforme == "android":
        manquants += [o for o in (args.adb, args.emulateur) if not os.access(o, os.X_OK)]
    else:
        essai = subprocess.run(["node", "-e", "require('playwright')"], capture_output=True,
                               env={**os.environ, "NODE_PATH": args.node_path})
        if essai.returncode != 0:
            manquants.append("playwright pour Node (npm install --prefix <dossier> playwright)")
    if manquants:
        echouer("outils absents, rien n'a été lancé : " + ", ".join(manquants))


# ── Les appareils ───────────────────────────────────────────────────────────────────────────


def adb(args, serie, *arguments, delai=120):
    return subprocess.run([args.adb, "-s", serie, *arguments], capture_output=True, text=True,
                          timeout=delai)


def preparer_android(args, rang, racine):
    """Un émulateur en lecture seule, l'app installée, ses données effacées, l'app ouverte.

    La lecture seule permet plusieurs émulateurs du même téléphone virtuel. Elle garde pourtant
    les données de l'app d'une session passée : vu le 2026-11-16, trois votes déjà joués à
    l'accueil. D'où l'effacement, sans lequel le testeur ne découvrirait rien.
    """
    port = PORT_EMULATEUR + 2 * rang
    serie = f"emulator-{port}"
    journal = open(racine / f"emulateur-{rang}.log", "w")
    processus = subprocess.Popen([args.emulateur, "-avd", args.avd, "-read-only", "-no-window",
                                  "-no-audio", "-no-boot-anim", "-no-snapshot-save",
                                  "-port", str(port)], stdout=journal, stderr=journal)
    def rendre():
        try:
            adb(args, serie, "emu", "kill")
            processus.wait(timeout=60)
        except subprocess.SubprocessError:
            # Un émulateur saturé ne répond plus à `emu kill`. Il se tue alors de force.
            processus.kill()

    try:
        return demarrer_android(args, rang, serie), rendre
    except Exception:
        # Un émulateur à moitié prêt se rend aussi, sinon il garde sa mémoire jusqu'au reboot.
        rendre()
        raise


def demarrer_android(args, rang, serie):
    attente = "while [ \"$(getprop sys.boot_completed)\" != 1 ]; do sleep 2; done"
    adb(args, serie, "wait-for-device", "shell", attente, delai=DEMARRAGE_MAX)
    for etape in (["install", "-r", args.apk], ["shell", "pm", "clear", args.paquet],
                  ["shell", "monkey", "-p", args.paquet, "-c",
                   "android.intent.category.LAUNCHER", "1"]):
        resultat = adb(args, serie, *etape)
        if resultat.returncode != 0:
            raise RuntimeError(f"émulateur {rang} : {' '.join(etape[:2])} a échoué")
    taille = adb(args, serie, "shell", "wm", "size").stdout.split()
    if not taille or not taille[-1].split("x")[0].isdigit():
        raise RuntimeError(f"émulateur {rang} : taille d'écran illisible, « {' '.join(taille)} »")
    largeur = int(taille[-1].split("x")[0])
    return {"plateforme": "android", "adb": args.adb, "serie": serie, "paquet": args.paquet,
            "facteur": largeur / LARGEUR_CAPTURE, "largeur_capture": LARGEUR_CAPTURE}


def preparer_web(args, rang, racine):
    """Un Chromium au profil vide, ouvert sur l'adresse de départ."""
    conf = {"plateforme": "web", "pilote_web": str(ICI / "pilote-web.cjs"),
            "node_path": args.node_path, "port": PORT_CDP + rang, "url": args.url,
            "profil": str(racine / f"profil-{rang}"), "largeur_css": 412, "hauteur_css": 915,
            "echelle": 1.5}
    chemin = racine / f"pilote-{rang}.json"
    chemin.write_text(json.dumps(conf), encoding="utf-8")
    env = {**os.environ, "F5_PILOTE": str(chemin), "NODE_PATH": args.node_path}
    pilote = ["node", conf["pilote_web"]]
    rendre = lambda: subprocess.run([*pilote, "arreter"], env=env, capture_output=True)
    subprocess.run([*pilote, "demarrer"], env=env, check=True, capture_output=True)
    for _ in range(60):
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{conf['port']}/json/version", timeout=1)
            break
        except OSError:
            time.sleep(0.5)
    else:
        # Sans navigateur, le testeur rendrait quand même un rapport, fait de pannes du pilote.
        rendre()
        raise RuntimeError(f"navigateur {rang} : Chromium ne répond pas sur son port")
    time.sleep(2)
    return conf, rendre


PREPARER = {"android": preparer_android, "web": preparer_web}


# ── Un testeur ──────────────────────────────────────────────────────────────────────────────


def consigne(args, rang):
    texte = (REFERENCES / "consigne-testeur.md").read_text(encoding="utf-8")
    texte = texte.split("\n---\n", 1)[1].strip()
    temperament = ""
    if args.temperaments:
        lignes = [l for l in (REFERENCES / "temperaments.txt").read_text(encoding="utf-8")
                  .splitlines() if l.strip() and not l.startswith("#")]
        temperament = lignes[(rang - 1) % len(lignes)]
    appareil = "cette app sur ton téléphone" if args.plateforme == "android" else "ce site"
    remplacements = {"{appareil}": appareil, "{fiche}": args.texte_fiche.replace("\n", "\n> "),
                     "{temperament}": temperament, "{actions_max}": str(args.actions_max)}
    for champ, valeur in remplacements.items():
        texte = texte.replace(champ, valeur)
    return texte


def lancer_session(args, rang, dossier, chemin_conf):
    """La session du testeur. Sa sortie JSON porte le rapport, le coût et les refus."""
    schema = (REFERENCES / "rapport-testeur.schema.json").read_text(encoding="utf-8")
    commande = [args.claude, "-p", "--model", args.modele, "--effort", args.effort,
                "--max-budget-usd", str(args.budget_max),
                "--tools", "Bash,Read", "--permission-mode", "dontAsk",
                "--allowedTools", "Bash(./piloter:*)", "Read(./**)",
                "--setting-sources", "", "--strict-mcp-config", "--no-session-persistence",
                "--append-system-prompt", consigne(args, rang), "--json-schema", schema,
                "--output-format", "json",
                "Commence ton essai. Ton premier geste est ./piloter voir, avec ton commentaire."]
    env = {**os.environ, "F5_PILOTE": str(chemin_conf)}
    resultat = subprocess.run(commande, cwd=dossier, env=env, capture_output=True, text=True,
                              timeout=SESSION_MAX)
    return resultat.stdout, resultat.stderr


def tester(args, rang, racine, sortie):
    """Un testeur de bout en bout. Une panne se rapporte, elle n'arrête pas les autres."""
    dossier = racine / f"testeur-{rang}"
    dossier.mkdir()
    # Les captures nettes vivent hors du dossier du testeur : il lirait sinon ce que le coup
    # d'œil lui cache.
    nettes = racine / f"nettes-{rang}"
    nettes.mkdir()
    shutil.copy(ICI / "piloter.py", dossier / "piloter")
    (dossier / "piloter").chmod(0o755)
    rendre = None
    try:
        conf, rendre = PREPARER[args.plateforme](args, rang, racine)
        conf["actions_max"] = args.actions_max
        conf["dossier_net"] = str(nettes)
        chemin_conf = racine / f"pilote-{rang}.json"
        chemin_conf.write_text(json.dumps(conf), encoding="utf-8")
        dire(f"testeur {rang} : appareil prêt, la session commence")
        brut, erreurs = lancer_session(args, rang, dossier, chemin_conf)
    except Exception as panne:
        brut, erreurs = "", f"panne avant ou pendant la session : {panne!r}"
    finally:
        if rendre:
            try:
                rendre()
            except Exception as panne:
                dire(f"testeur {rang} : l'appareil n'a pas pu être rendu ({panne!r})")
    return rapatrier(rang, dossier, sortie, brut, erreurs, nettes)


def rapatrier(rang, dossier, sortie, brut, erreurs, nettes=None):
    cible = sortie / f"testeur-{rang}"
    shutil.copytree(dossier, cible, ignore=shutil.ignore_patterns("piloter"))
    if nettes and nettes.is_dir():
        shutil.copytree(nettes, cible / "nettes", ignore=shutil.ignore_patterns(".*", "*.png"))
    (cible / "sortie-session.json").write_text(brut or "{}", encoding="utf-8")
    try:
        donnees = json.loads(brut)
    except json.JSONDecodeError:
        donnees = {}
    rapport = donnees.get("structured_output")
    if not rapport and donnees.get("is_error"):
        # Le plafond de dépense, par exemple, ne s'écrit que dans la sortie JSON de la session.
        erreurs = f"session close sur « {donnees.get('subtype', 'erreur')} ». {erreurs}"
    bilan = {"rang": rang, "rapport": rapport, "cout_usd": donnees.get("total_cost_usd"),
             "tours": donnees.get("num_turns"), "refus": donnees.get("permission_denials", []),
             "erreur": None if rapport else (erreurs.strip()[-800:] or "aucun rapport rendu")}
    (cible / "bilan.json").write_text(json.dumps(bilan, ensure_ascii=False, indent=2),
                                      encoding="utf-8")
    gestes = len(list((cible / "captures").glob("*.jpg"))) if (cible / "captures").exists() else 0
    dire(f"testeur {rang} : fini, {gestes} captures, "
         + ("rapport rendu" if rapport else f"SANS rapport ({bilan['erreur'][:120]})"))
    return bilan


# ── L'ensemble ──────────────────────────────────────────────────────────────────────────────


def lire_arguments():
    analyse = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    analyse.add_argument("plateforme", choices=sorted(PREPARER))
    analyse.add_argument("--nombre", type=int, required=True)
    # Un émulateur à la fois par défaut. Trois en même temps ont saturé le PC de l'admin le
    # 2026-11-16. Les testeurs ont pris ses fenêtres système et ses lenteurs pour des défauts
    # de l'app. Les navigateurs, plus légers, tournent à trois.
    analyse.add_argument("--paralleles", type=int)
    analyse.add_argument("--fiche", type=Path, required=True)
    analyse.add_argument("--sortie", type=Path, required=True)
    analyse.add_argument("--modele", default="sonnet")
    analyse.add_argument("--effort", default="medium")
    analyse.add_argument("--actions-max", type=int, default=40)
    analyse.add_argument("--temperaments", action="store_true")
    # Un plafond par testeur. Un testeur qui tourne en rond ne doit pas coûter le run entier.
    analyse.add_argument("--budget-max", type=float, default=2.0)
    analyse.add_argument("--apk")
    analyse.add_argument("--paquet")
    analyse.add_argument("--avd")
    sdk = os.path.expanduser(os.environ.get("ANDROID_HOME", "~/Android/Sdk"))
    analyse.add_argument("--adb", default=f"{sdk}/platform-tools/adb")
    analyse.add_argument("--emulateur", default=f"{sdk}/emulator/emulator")
    analyse.add_argument("--url")
    analyse.add_argument("--node-path", default=os.environ.get("NODE_PATH", ""))
    args = analyse.parse_args()
    requis = {"android": ("apk", "paquet", "avd"), "web": ("url",)}[args.plateforme]
    absents = [r for r in requis if not getattr(args, r)]
    if absents:
        echouer(f"{args.plateforme} demande : " + ", ".join(f"--{a}" for a in absents))
    return args


def principal():
    args = lire_arguments()
    if args.paralleles is None:
        args.paralleles = 1 if args.plateforme == "android" else 3
    if args.sortie.exists():
        echouer(f"le dossier de sortie existe déjà, rien n'a été lancé : {args.sortie}. Un "
                "sous-dossier neuf par plateforme, comme android/ ou web/.")
    verifier_outils(args)
    args.claude = trouver_claude()
    args.texte_fiche = args.fiche.read_text(encoding="utf-8").strip()
    args.sortie.mkdir(parents=True)
    # Un nom de dossier neutre : le testeur lit son chemin, et le nom du projet n'y doit pas être.
    racine = Path(tempfile.mkdtemp(prefix="essai.", dir="/tmp"))
    dire(f"{args.nombre} testeur(s) {args.plateforme}, {args.paralleles} à la fois, "
         f"modèle {args.modele}")
    with ThreadPoolExecutor(max_workers=args.paralleles) as groupe:
        bilans = list(groupe.map(lambda r: tester(args, r, racine, args.sortie),
                                 range(1, args.nombre + 1)))
    (args.sortie / "bilans.json").write_text(json.dumps(bilans, ensure_ascii=False, indent=2),
                                             encoding="utf-8")
    shutil.rmtree(racine, ignore_errors=True)
    rendus = sum(1 for b in bilans if b["rapport"])
    dire(f"terminé : {rendus} rapport(s) sur {args.nombre}, dans {args.sortie}")
    return 0 if rendus == args.nombre else 1


if __name__ == "__main__":
    sys.exit(principal())
