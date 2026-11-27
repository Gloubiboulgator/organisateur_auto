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
1. Prépare un appareil neuf, un émulateur en lecture seule ou un navigateur au profil vide.
2. Pose `./piloter` dans le dossier neutre, et hors de ce dossier sa configuration et le dossier
   de ses captures nettes. Le testeur ne reçoit que des coups d'œil flous.
3. Lance la session du testeur, avec la consigne et la forme du rapport.
4. Rapatrie captures, journal et rapport dans le dossier de sortie, puis rend l'appareil.

COMMENT ON S'EN SERT
--------------------
    python3 lancer_testeurs.py android --reglages <resultats>/reglages.json --fiche fiche.txt \\
        --sortie <resultats>/android --apk app.apk --paquet org.exemple.app --avd Mon_telephone
    python3 lancer_testeurs.py firefox --reglages <resultats>/reglages.json --fiche fiche.txt \\
        --sortie <resultats>/firefox --url http://127.0.0.1:8000/ --node-path <dossier>/node_modules
    python3 lancer_testeurs.py chrome_android --reglages <resultats>/reglages.json \\
        --fiche fiche.txt --sortie <resultats>/chrome_android --avd Mon_telephone \\
        --url http://10.0.2.2:8000/
Un navigateur se nomme comme dans NAVIGATEURS, par exemple firefox ou safari_mobile.

Les réglages viennent de la fenêtre de `regler.py`. Sans `--reglages`, ce sont ceux de DEFAUTS.
Le dossier de sortie doit être neuf. Un dossier existant se refuse, pour ne jamais écraser un run
payé.
"""
import argparse
import glob
import json
import os
import random
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
import time
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
PORT_EMULATEUR, PORT_WEB = 5560, 9320

# Les navigateurs que Playwright sait piloter, par leur nom de plateforme. Chacun porte son moteur,
# son canal pour une version de marque, et la commande qui l'installe. Tous demandés en option
# par l'admin le 2026-11-27. Chrome et Edge sont des Chromium de marque, installés à part.

# WebKit s'affiche « Safari », le nom que l'admin connaît. C'est le moteur de Safari, pas un
# vrai Safari d'iPhone.
NAVIGATEURS = {
    "chromium": {"moteur": "chromium", "canal": None, "nom": "Chromium",
                 "installer": "npx playwright install chromium"},
    "firefox": {"moteur": "firefox", "canal": None, "nom": "Firefox",
                "installer": "npx playwright install firefox"},
    "webkit": {"moteur": "webkit", "canal": None, "nom": "Safari",
               "installer": "npx playwright install --with-deps webkit"},
    "chrome": {"moteur": "chromium", "canal": "chrome", "nom": "Chrome",
               "installer": "npx playwright install chrome"},
    "msedge": {"moteur": "chromium", "canal": "msedge", "nom": "Edge",
               "installer": "npx playwright install msedge"},
    # Deux téléphones imités, les profils « Mobile Chrome » et « Mobile Safari » de la page
    # https://playwright.dev/docs/browsers, lue le 2026-11-27. Le site les voit tactiles, à
    # l'identité d'un navigateur mobile. Le moteur reste celui d'un ordinateur.
    "chrome_mobile": {"moteur": "chromium", "canal": None, "nom": "Chrome mobile (imité)",
                      "appareil": "Pixel 5", "installer": "npx playwright install chromium"},
    "safari_mobile": {"moteur": "webkit", "canal": None, "nom": "Safari mobile (imité)",
                      "appareil": "iPhone 12",
                      "installer": "npx playwright install --with-deps webkit"},
}
# Le vrai Chrome d'un téléphone Android, dans l'émulateur. Il se pilote comme l'app Android, par
# `adb`, Chrome tenant le rôle de l'app.
CHROME_ANDROID = "com.android.chrome"
PLATEFORMES = ["android", "chrome_android", *NAVIGATEURS]
NOMS = {"android": "Android (app)", "chrome_android": "Chrome Android",
        **{cle: n["nom"] for cle, n in NAVIGATEURS.items()}}

# Les réglages d'un run quand l'admin n'y touche pas. La fenêtre de `regler.py` les montre, et
# ce dictionnaire est leur seule source. Les valeurs reprennent celles d'avant la fenêtre.

# Un émulateur à la fois. Trois en même temps ont saturé le PC de l'admin le 2026-11-16. Les
# testeurs ont pris ses fenêtres système et ses lenteurs pour des défauts de l'app. Les
# navigateurs, plus légers, tournent à trois.

# Chaque plateforme a son propre réglage, demandé par l'admin le 2026-11-27. Par défaut, Android
# et Chrome, choisis par l'admin le même jour.

# Un plafond de dépense par testeur : un testeur qui tourne en rond ne doit pas coûter le run
# entier. Les quatre comportements ajoutés le 2026-11-27 partent éteints, pour qu'un run sans
# réglage reste celui d'avant.
DEFAUTS = {
    "plateformes": ["android", "chrome"],
    "nombre": 3,
    "paralleles": {"android": 1, "chrome_android": 1, **{n: 3 for n in NAVIGATEURS}},
    "modele": "sonnet", "effort": "medium",
    "actions_max": 40, "budget_max": 2.0,
    "envie": True,
    "temperaments": {"mode": "aucun", "choix": {}},
    "flou": {"actif": True, "niveau": "moyen", "lecture_max": 25},
    "doigt": {"actif": True, "mm": 2.0},
    "pose": {"actif": True, "max": 10},
    "double_toucher": {"actif": False, "seuil": 1.0},
    "fautes": {"actif": False, "taux": 5},
    "memoire_courte": {"actif": False, "ecrans": 3},
    "interruption": {"actif": False, "duree": 10},
}
# Les bornes de chaque nombre. Une valeur hors bornes se refuse avant tout lancement.
BORNES = {
    "nombre": (1, 10), "paralleles.android": (1, 3), "paralleles.chrome_android": (1, 3),
    **{f"paralleles.{n}": (1, 6) for n in NAVIGATEURS},
    "actions_max": (5, 200), "budget_max": (0.5, 20),
    "flou.lecture_max": (5, 100), "doigt.mm": (0.5, 6), "pose.max": (3, 30),
    "double_toucher.seuil": (0.5, 5), "fautes.taux": (1, 30), "memoire_courte.ecrans": (1, 10),
    "interruption.duree": (3, 60),
}
# Les nombres qui comptent des testeurs, des gestes ou des écrans. Ils se refusent décimaux.
ENTIERS = {"nombre", "actions_max", "memoire_courte.ecrans",
           *(c for c in BORNES if c.startswith("paralleles."))}
# Les interrupteurs, vrais ou faux. Une chaîne comme "false" s'y lirait comme allumée.
INTERRUPTEURS = ("envie", "flou.actif", "doigt.actif", "pose.actif", "double_toucher.actif",
                 "fautes.actif", "memoire_courte.actif", "interruption.actif")
CHOIX = {"modele": ("sonnet", "opus", "haiku"), "effort": ("low", "medium", "high"),
         "flou.niveau": ("léger", "moyen", "fort")}


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
    if args.plateforme in ("android", "chrome_android"):
        manquants += [o for o in (args.adb, args.emulateur) if not os.access(o, os.X_OK)]
    else:
        manquants += verifier_navigateur(args)
    if manquants:
        echouer("outils absents, rien n'a été lancé : " + ", ".join(manquants))


def verifier_navigateur(args):
    """Playwright pour Node, puis le navigateur lui-même, ouvert et refermé une fois. Un essai
    réel, car Playwright ne dit pas d'avance si une version de marque est installée."""
    navigateur = NAVIGATEURS[args.plateforme]
    env = {**os.environ, "NODE_PATH": args.node_path}
    essai = subprocess.run(["node", "-e", "require('playwright')"], capture_output=True, env=env)
    if essai.returncode != 0:
        return ["playwright pour Node (npm install --prefix <dossier> playwright)"]
    ouverture = ("require('playwright')[process.argv[1]]"
                 ".launch({headless: true, channel: process.argv[2] || undefined})"
                 ".then((b) => b.close()).catch(() => process.exit(1))")
    try:
        essai = subprocess.run(["node", "-e", ouverture, navigateur["moteur"],
                                navigateur["canal"] or ""], capture_output=True, env=env,
                               timeout=120)
    except subprocess.TimeoutExpired:
        return [f"{navigateur['nom']} pour Playwright, ne s'ouvre pas en 120 s "
                f"({navigateur['installer']})"]
    if essai.returncode != 0:
        return [f"{navigateur['nom']} pour Playwright ({navigateur['installer']})"]
    return []


# ── Les appareils ───────────────────────────────────────────────────────────────────────────


def adb(args, serie, *arguments, delai=120):
    return subprocess.run([args.adb, "-s", serie, *arguments], capture_output=True, text=True,
                          timeout=delai)


def preparer_android(args, rang, racine, demarrer=None, premier_port=PORT_EMULATEUR):
    """Un émulateur en lecture seule, l'app installée, ses données effacées, l'app ouverte.

    La lecture seule permet plusieurs émulateurs du même téléphone virtuel. Elle garde pourtant
    les données de l'app d'une session passée : vu le 2026-11-16, trois votes déjà joués à
    l'accueil. D'où l'effacement, sans lequel le testeur ne découvrirait rien.
    """
    port = premier_port + 2 * rang
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
        return (demarrer or demarrer_android)(args, rang, serie), rendre
    except Exception:
        # Un émulateur à moitié prêt se rend aussi, sinon il garde sa mémoire jusqu'au reboot.
        rendre()
        raise


def attendre_le_demarrage(args, serie):
    attente = "while [ \"$(getprop sys.boot_completed)\" != 1 ]; do sleep 2; done"
    adb(args, serie, "wait-for-device", "shell", attente, delai=DEMARRAGE_MAX)


def demarrer_android(args, rang, serie):
    attendre_le_demarrage(args, serie)
    for etape in (["install", "-r", args.apk], ["shell", "pm", "clear", args.paquet],
                  ["shell", "monkey", "-p", args.paquet, "-c",
                   "android.intent.category.LAUNCHER", "1"]):
        resultat = adb(args, serie, *etape)
        if resultat.returncode != 0:
            raise RuntimeError(f"émulateur {rang} : {' '.join(etape[:2])} a échoué")
    return conf_android(args, rang, serie, args.paquet)


def conf_android(args, rang, serie, paquet):
    """La configuration du pilote Android, mesurée sur l'écran de l'émulateur."""
    taille = adb(args, serie, "shell", "wm", "size").stdout.split()
    if not taille or not taille[-1].split("x")[0].isdigit():
        raise RuntimeError(f"émulateur {rang} : taille d'écran illisible, « {' '.join(taille)} »")
    largeur = int(taille[-1].split("x")[0])
    return {"plateforme": "android", "adb": args.adb, "serie": serie, "paquet": paquet,
            "facteur": largeur / LARGEUR_CAPTURE, "largeur_capture": LARGEUR_CAPTURE}


def preparer_chrome_android(args, rang, racine):
    """Le vrai Chrome d'un téléphone Android, dans l'émulateur, ouvert sur l'adresse de départ.

    Ses émulateurs prennent une autre plage de ports que ceux de l'app, pour que les deux lots
    tournent ensemble sans se croiser."""
    return preparer_android(args, rang, racine, demarrer_chrome_android, PORT_EMULATEUR + 40)


def demarrer_chrome_android(args, rang, serie):
    """Chrome vidé de ses données, puis ouvert sur le site, comme un lien suivi.

    Le fichier de lignes de commande demande à Chrome de sauter ses écrans d'accueil. Chrome ne
    le lit que si le téléphone le permet, d'après la documentation de Playwright. Non observé
    sur un émulateur, rangé dans la roadmap. Sans lui, le testeur passe d'abord l'accueil de
    Chrome, comme un humain sur un téléphone neuf."""
    attendre_le_demarrage(args, serie)
    if "package:" not in adb(args, serie, "shell", "pm", "path", CHROME_ANDROID).stdout:
        raise RuntimeError(f"émulateur {rang} : Chrome n'est pas installé sur le téléphone "
                           f"virtuel {args.avd}")
    lignes = "_ --disable-fre --no-default-browser-check --no-first-run"
    for etape in (["shell", "pm", "clear", CHROME_ANDROID],
                  ["shell", f"echo '{lignes}' > /data/local/tmp/chrome-command-line"],
                  ["shell", "am", "start", "-a", "android.intent.action.VIEW", "-d",
                   shlex.quote(args.url), "-p", CHROME_ANDROID]):
        resultat = adb(args, serie, *etape)
        if resultat.returncode != 0:
            raise RuntimeError(f"émulateur {rang} : {' '.join(etape[1:3])} a échoué")
    return {**conf_android(args, rang, serie, CHROME_ANDROID), "url": args.url}


def preparer_web(args, rang, racine):
    """Un navigateur au profil vide, ouvert sur l'adresse de départ.

    Chaque navigateur a sa dizaine de ports, pour que deux lots lancés ensemble ne se croisent
    pas. Le pilote reste `web` pour `piloter.py`, qui ne voit pas le moteur."""
    navigateur = NAVIGATEURS[args.plateforme]
    port = PORT_WEB + 10 * list(NAVIGATEURS).index(args.plateforme) + rang
    conf = {"plateforme": "web", "pilote_web": str(ICI / "pilote-web.cjs"),
            "moteur": navigateur["moteur"], "canal": navigateur["canal"],
            "appareil": navigateur.get("appareil"),
            "node_path": args.node_path, "port": port, "url": args.url,
            "profil": str(racine / f"profil-{rang}"), "largeur_css": 412, "hauteur_css": 915,
            "echelle": 1.5}
    chemin = racine / f"pilote-{rang}.json"
    chemin.write_text(json.dumps(conf), encoding="utf-8")
    env = {**os.environ, "F5_PILOTE": str(chemin), "NODE_PATH": args.node_path}
    pilote = ["node", conf["pilote_web"]]
    rendre = lambda: subprocess.run([*pilote, "arreter"], env=env, capture_output=True)
    # Un pilote resté d'un run interrompu tiendrait le port, et le testeur piloterait son vieux
    # navigateur. Relevé par la revue de la 121.
    try:
        socket.create_connection(("127.0.0.1", port), timeout=1).close()
    except OSError:
        pass
    else:
        raise RuntimeError(f"navigateur {rang} : le port {port} est déjà pris, sans doute par le "
                           f"pilote d'un run interrompu. L'arrêter : F5_PILOTE=<son fichier> "
                           f"node {conf['pilote_web']} arreter")
    Path(f"{chemin}.erreur").unlink(missing_ok=True)
    subprocess.run([*pilote, "demarrer"], env=env, check=True, capture_output=True)
    # Le serveur du pilote n'écoute qu'une fois la page ouverte sur l'adresse de départ.
    for _ in range(120):
        try:
            socket.create_connection(("127.0.0.1", port), timeout=1).close()
            break
        except OSError:
            time.sleep(0.5)
    else:
        # Sans navigateur, le testeur rendrait quand même un rapport, fait de pannes du pilote.
        rendre()
        erreur = Path(f"{chemin}.erreur")
        detail = f" ({erreur.read_text(encoding='utf-8')})" if erreur.exists() else ""
        raise RuntimeError(f"navigateur {rang} : {navigateur['nom']} ne répond pas{detail}")
    time.sleep(2)
    return conf, rendre


PREPARER = {"android": preparer_android, "chrome_android": preparer_chrome_android,
            **{n: preparer_web for n in NAVIGATEURS}}


# ── Un testeur ──────────────────────────────────────────────────────────────────────────────


def lire_temperaments():
    """Les tempéraments, par leur nom court, dans l'ordre du fichier."""
    temperaments = {}
    for ligne in (REFERENCES / "temperaments.txt").read_text(encoding="utf-8").splitlines():
        if ligne.strip() and not ligne.startswith("#"):
            nom, texte = (morceau.strip() for morceau in ligne.split("|", 1))
            temperaments[nom] = texte
    return temperaments


def attribuer_temperaments(reglages, plateforme, nombre):
    """Le tempérament de chaque rang, ou "" pour aucun.

    Au hasard, chacun sort une fois avant qu'un autre ne se répète. Sinon, l'admin les a choisis
    dans la fenêtre pour chaque testeur, et un rang qu'elle ne nomme pas n'en a aucun."""
    temperaments = lire_temperaments()
    mode = reglages["temperaments"]["mode"]
    if mode == "aucun":
        return [""] * nombre
    if mode == "hasard":
        tirage = []
        while len(tirage) < nombre:
            tirage += random.sample(list(temperaments.values()), len(temperaments))
        return tirage[:nombre]
    choix = reglages["temperaments"]["choix"]
    return [temperaments.get(choix.get(f"{plateforme}-{rang}", ""), "")
            for rang in range(1, nombre + 1)]


def lire_consigne():
    """La consigne et ses blocs. Les blocs suivent la ligne `<!-- blocs -->`, chacun sous son
    titre `### nom`."""
    texte = (REFERENCES / "consigne-testeur.md").read_text(encoding="utf-8")
    texte = texte.split("\n---\n", 1)[1]
    corps, suite = texte.split("\n<!-- blocs -->\n", 1)
    blocs = {}
    for morceau in suite.split("\n### ")[1:]:
        nom, _, contenu = morceau.partition("\n")
        blocs[nom.strip()] = contenu.strip()
    return corps.strip(), blocs


def consigne(args, rang):
    corps, blocs = lire_consigne()
    reglages = args.reglages
    envie = "envie" if reglages["envie"] else "exploration"
    choisis = {
        "{but}": blocs[f"but-{envie}"],
        "{arret}": blocs[f"arret-{envie}"],
        "{captures}": blocs["coup-d-oeil" if reglages["flou"]["actif"] else "capture-nette"],
        "{pose}": blocs["pose"] if reglages["pose"]["actif"] else "",
        "{memoire}": blocs["memoire-courte"] if reglages["memoire_courte"]["actif"] else "",
    }
    for champ, valeur in choisis.items():
        if not valeur:
            # Un bloc éteint emporte la ligne vide qui le suivait, pour ne pas trouer le texte.
            corps = corps.replace(champ + "\n\n", "")
        corps = corps.replace(champ, valeur)
    appareil = {"android": "cette app sur ton téléphone",
                "chrome_android": "ce site sur ton téléphone"}.get(args.plateforme, "ce site")
    temperament = args.temperaments_par_rang[rang - 1]
    remplacements = {"{appareil}": appareil, "{temperament}": temperament,
                     "{actions_max}": str(reglages["actions_max"]),
                     "{lecture_part}": texte_de_part(reglages["flou"]["lecture_max"]),
                     "{fiche}": args.texte_fiche.replace("\n", "\n> ")}
    for champ, valeur in remplacements.items():
        corps = corps.replace(champ, valeur)
    return corps


def texte_de_part(pourcent):
    """« un quart », « la moitié », ou un pourcentage. Même formule que le refus de `piloter.py`."""
    mots = {25: "un quart", 50: "la moitié", 100: "la totalité"}
    return mots.get(round(pourcent), f"{round(pourcent)} %")


def options_du_pilote(reglages):
    """Les réglages que `piloter.py` lit dans sa configuration, sous la clé `options`.

    L'interruption tombe une fois, à un geste tiré entre le quart et la moitié du plafond. Assez
    tard, le testeur est pris dans quelque chose. Assez tôt, il ne s'est pas encore arrêté."""
    plafond = reglages["actions_max"]
    geste = random.randint(max(2, round(plafond / 4)), max(2, round(plafond / 2)))
    return {"flou": reglages["flou"]["actif"], "flou_niveau": reglages["flou"]["niveau"],
            "lecture_max": reglages["flou"]["lecture_max"] / 100,
            "doigt": reglages["doigt"]["actif"], "doigt_mm": reglages["doigt"]["mm"],
            "pose": reglages["pose"]["actif"], "pose_max": reglages["pose"]["max"],
            "double_toucher": reglages["double_toucher"]["actif"],
            "double_seuil": reglages["double_toucher"]["seuil"],
            "fautes": reglages["fautes"]["actif"], "fautes_taux": reglages["fautes"]["taux"] / 100,
            "memoire_courte": reglages["memoire_courte"]["actif"],
            "memoire_ecrans": reglages["memoire_courte"]["ecrans"],
            "interruption": reglages["interruption"]["actif"],
            "interruption_geste": geste, "interruption_duree": reglages["interruption"]["duree"]}


def lancer_session(args, rang, dossier, chemin_conf):
    """La session du testeur. Sa sortie JSON porte le rapport, le coût et les refus."""
    schema = (REFERENCES / "rapport-testeur.schema.json").read_text(encoding="utf-8")
    reglages = args.reglages
    commande = [args.claude, "-p", "--model", reglages["modele"], "--effort", reglages["effort"],
                "--max-budget-usd", str(reglages["budget_max"]),
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
        conf["actions_max"] = args.reglages["actions_max"]
        conf["dossier_net"] = str(nettes)
        conf["options"] = options_du_pilote(args.reglages)
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
        shutil.copytree(nettes, cible / "nettes", ignore=shutil.ignore_patterns(".*", "*.png",
                                                                                 "anciens"))
        # Les captures que la mémoire courte avait retirées au testeur reviennent à leur place.
        anciens = nettes / "anciens"
        if anciens.is_dir():
            (cible / "captures").mkdir(exist_ok=True)
            for capture in anciens.glob("*.jpg"):
                shutil.copy(capture, cible / "captures" / capture.name)
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


def completer(defauts, donnes):
    """Les réglages donnés, complétés par les défauts, clé par clé et à tous les niveaux."""
    complet = {}
    for cle, defaut in defauts.items():
        valeur = donnes.get(cle, defaut)
        if isinstance(defaut, dict) and isinstance(valeur, dict) and cle != "choix":
            valeur = completer(defaut, valeur)
        complet[cle] = valeur
    return complet


def valeur_en(reglages, chemin):
    valeur = reglages
    for cle in chemin.split("."):
        valeur = valeur[cle]
    return valeur


def verifier_reglages(reglages):
    """Rend la liste des fautes : une valeur hors bornes, hors choix, ou d'un mauvais type."""
    fautes = []
    for chemin, (bas, haut) in BORNES.items():
        valeur = valeur_en(reglages, chemin)
        if isinstance(valeur, bool) or not isinstance(valeur, (int, float)) \
                or not bas <= valeur <= haut:
            fautes.append(f"{chemin} doit valoir de {bas} à {haut}, pas {valeur!r}")
        elif chemin in ENTIERS and not isinstance(valeur, int):
            fautes.append(f"{chemin} doit être un nombre entier, pas {valeur!r}")
    for chemin in INTERRUPTEURS:
        if not isinstance(valeur_en(reglages, chemin), bool):
            fautes.append(f"{chemin} doit valoir vrai ou faux")
    # Au-delà de l'attente de la pose, le second toucher ne partirait jamais. Revue de la 121.
    if reglages["double_toucher"]["actif"] is True and reglages["pose"]["actif"] is True \
            and not fautes and reglages["double_toucher"]["seuil"] >= reglages["pose"]["max"]:
        fautes.append("double_toucher.seuil doit rester sous pose.max")
    for chemin, possibles in CHOIX.items():
        if valeur_en(reglages, chemin) not in possibles:
            fautes.append(f"{chemin} doit valoir {' ou '.join(possibles)}")
    if not set(reglages["plateformes"]) <= set(PREPARER) or not reglages["plateformes"]:
        fautes.append("plateformes doit nommer au moins une de : " + ", ".join(PLATEFORMES))
    if reglages["temperaments"]["mode"] not in ("aucun", "hasard", "choix"):
        fautes.append("temperaments.mode doit valoir aucun, hasard ou choix")
    noms = set(lire_temperaments()) | {"", "Aucun"}
    inconnus = [n for n in reglages["temperaments"]["choix"].values() if n not in noms]
    if inconnus:
        fautes.append("tempéraments inconnus : " + ", ".join(inconnus))
    return fautes


def lire_reglages(chemin):
    # Un fichier écrit à la main peut être illisible, ou mettre un nombre où un groupe est
    # attendu. Le refus le dit, comme la fenêtre. Relevé par les revues de la 121.
    try:
        donnes = json.loads(chemin.read_text(encoding="utf-8")) if chemin else {}
        reglages = completer(DEFAUTS, donnes)
        fautes = verifier_reglages(reglages)
    except (ValueError, OSError, KeyError, TypeError, AttributeError) as panne:
        fautes = [f"réglages illisibles ({panne})"]
    if fautes:
        echouer("réglages refusés, rien n'a été lancé : " + " ; ".join(fautes))
    return reglages


def lire_arguments():
    analyse = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    analyse.add_argument("plateforme", choices=sorted(PREPARER))
    analyse.add_argument("--reglages", type=Path)
    analyse.add_argument("--fiche", type=Path, required=True)
    analyse.add_argument("--sortie", type=Path, required=True)
    analyse.add_argument("--apk")
    analyse.add_argument("--paquet")
    analyse.add_argument("--avd")
    sdk = os.path.expanduser(os.environ.get("ANDROID_HOME", "~/Android/Sdk"))
    analyse.add_argument("--adb", default=f"{sdk}/platform-tools/adb")
    analyse.add_argument("--emulateur", default=f"{sdk}/emulator/emulator")
    analyse.add_argument("--url")
    analyse.add_argument("--node-path", default=os.environ.get("NODE_PATH", ""))
    args = analyse.parse_args()
    args.reglages = lire_reglages(args.reglages)
    requis = {"android": ("apk", "paquet", "avd"),
              "chrome_android": ("avd", "url")}.get(args.plateforme, ("url",))
    absents = [r for r in requis if not getattr(args, r)]
    if absents:
        echouer(f"{args.plateforme} demande : " + ", ".join(f"--{a}" for a in absents))
    return args


def principal():
    args = lire_arguments()
    args.nombre = args.reglages["nombre"]
    args.paralleles = args.reglages["paralleles"][args.plateforme]
    args.temperaments_par_rang = attribuer_temperaments(args.reglages, args.plateforme,
                                                        args.nombre)
    if args.sortie.exists():
        echouer(f"le dossier de sortie existe déjà, rien n'a été lancé : {args.sortie}. Un "
                "sous-dossier neuf par plateforme, comme android/ ou firefox/.")
    verifier_outils(args)
    args.claude = trouver_claude()
    args.texte_fiche = args.fiche.read_text(encoding="utf-8").strip()
    args.sortie.mkdir(parents=True)
    # Les réglages du run, tels qu'ils sont partis, pour la synthèse.
    (args.sortie / "reglages.json").write_text(json.dumps(
        {**args.reglages, "temperaments_par_rang": args.temperaments_par_rang},
        ensure_ascii=False, indent=2), encoding="utf-8")
    # Un nom de dossier neutre : le testeur lit son chemin, et le nom du projet n'y doit pas être.
    racine = Path(tempfile.mkdtemp(prefix="essai.", dir="/tmp"))
    dire(f"{args.nombre} testeur(s) {args.plateforme}, {args.paralleles} à la fois, "
         f"modèle {args.reglages['modele']}")
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
