#!/usr/bin/env python3
"""Le seul geste permis à un testeur de la passe parcours : agir sur l'écran, puis le photographier.

POURQUOI CE FICHIER EXISTE
--------------------------
La règle F5 du noyau veut une passe parcours après chaque lot visible. Son testeur doit
découvrir l'app comme un inconnu. Un sous-agent ordinaire reçoit pourtant le chemin du projet,
son `git status` et ses derniers commits. Mesuré le 2026-11-16 : il lisait le nom du projet et
l'historique avant son premier clic.

Le testeur tourne donc dans un dossier neutre, et ce script est sa seule commande autorisée. Il
voit l'écran, il agit, il commente. Il ne lit rien d'autre.

CE QU'IL GARANTIT
-----------------
- **Un commentaire par geste.** Un geste sans commentaire est refusé. Le parcours commenté est
  ce que la synthèse lit, et un trou dans le récit ne se rattrape pas après coup.
- **Une capture par geste**, numérotée, et une ligne de journal qui la nomme.
- **Un coup d'œil, pas une lecture.** Le testeur lisait chaque mot de chaque capture, là où un
  humain survole. Il reçoit donc une capture floue, où se voient les titres et les gros
  boutons. Lire un passage net est un geste à part, `lire`, qui compte dans le plafond. La
  capture nette s'écrit hors de son dossier, sinon il la lirait. Décidé par l'admin le
  2026-11-18, au niveau de flou qu'il a choisi sur un écran réel.
- **Un doigt, pas un pointeur.** Chaque `toucher` et chaque `glisser` se décalent au hasard autour
  du point visé, de 2 mm d'écart type. Un testeur qui touchait au point près ne ratait jamais un
  bouton trop petit. Décidé par l'admin le 2026-11-19.
- **La durée qu'un humain sent.** Après un geste qui change l'écran, le pilote le photographie
  jusqu'à ce qu'il ne bouge plus. Il dit au testeur combien de temps l'écran a mis. Décidé par
  l'admin le 2026-11-19, à la place d'une attente fixe d'une seconde et demie.
- **Des coordonnées dans le repère de la capture.** Le testeur vise ce qu'il voit, et le pilote
  convertit vers l'écran réel. Sans ça, il viserait à côté sur chaque écran haute définition.
  Côté Android, ce script convertit. Côté web, le pilote Node mesure l'échelle sur la page.
- **Des réglages par run.** Chaque comportement ci-dessus s'éteint ou se règle par la clé
  `options` de la configuration, que la fenêtre de réglages remplit. Quatre autres s'y ajoutent,
  éteints par défaut. Le double toucher d'un humain impatient, les fautes de frappe, la mémoire
  courte, et une interruption au milieu du test. Décidé par l'admin le 2026-11-27.

SA CONFIGURATION VIT HORS DU DOSSIER DU TESTEUR. La variable `F5_PILOTE` la désigne. Le testeur
ne peut lire que son dossier, et la configuration porte des chemins qui nomment le projet.

COMMENT ON S'EN SERT
--------------------
    ./piloter voir -- "J'arrive sur l'app, je regarde ce qu'elle propose."
    ./piloter toucher 270 880 -- "Je touche Jouer, c'est le plus gros bouton."
    ./piloter glisser 270 900 270 300 -- "Je fais défiler pour voir la suite."
    ./piloter taper "bonjour" -- "Je remplis le champ du pseudo."
    ./piloter retour -- "Je reviens en arrière, cet écran ne m'apprend rien."
    ./piloter attendre 3 -- "Ça charge, je patiente."
    ./piloter lire 20 480 520 680 -- "Je lis ce que propose la mesure avant de voter."
    ./piloter relancer -- "L'app s'est fermée, je la rouvre depuis son icône."
"""
import json
import math
import os
import random
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime
from pathlib import Path

ICI = Path.cwd()
CAPTURES = ICI / "captures"
JOURNAL = ICI / "journal.jsonl"
ATTENTE_MAX = 10
# L'attente que l'écran se pose. Le pilote le photographie en boucle, et s'arrête après une
# seconde sans changement, ou à dix secondes. Une attente fixe d'une seconde et demie la
# précédait. En dessous, une capture sur trois montrait encore l'écran d'avant.

# Deux photos sont pareilles quand moins de 1 % des points d'une image grise de 64 sur 64
# changent de plus de 24 niveaux. Un curseur qui clignote ou l'heure qui change restent dessous.

# Un écran presque uni, vide, ne se pose jamais : c'est l'allure d'un chargement. Mesuré le
# 2026-11-19 sur une page blanche de deux secondes, que l'attente prenait pour l'écran posé.
# Presque uni veut dire 99 % des points à 8 niveaux au plus de la valeur médiane.

# À 98 %, un écran de réglages blanc à trois lignes passait pour vide. Une roue de chargement
# seule reste au-dessus de 99 %. Mesuré sur des écrans dessinés, revue de la 114, 2026-11-19.

# Entre deux photos, le pilote laisse un dixième de seconde. Sans pause, la boucle saturait le
# processeur et adb, une photo derrière l'autre.
POSE = {"calme": 1.0, "max": 10, "seuil": 0.01, "ecart": 24, "cote": 64,
        "uni_part": 0.99, "uni_ecart": 8, "pas": 0.1, "bande": 4}
GESTES_MESURES = ("toucher", "glisser", "taper", "retour", "relancer")
# Le doigt : un écart type de 2 mm autour du point visé, borné à trois écarts types.
DOIGT_MM = 2.0
DOIGT_BORNE = 3
# Le niveau moyen du coup d'œil : la capture se réduit à 80 pixels de large pour 540, puis se
# ré-agrandit. Les titres et les gros boutons s'y lisent, le texte courant non. Choisi par l'admin
# le 2026-11-18, entre trois niveaux montrés sur un écran réel.
FLOU = 80 / 540
# Une lecture rend au plus le quart de l'écran. Sans borne, un seul geste rendrait tout l'écran.
LECTURE_MAX = 0.25
# Les deux autres niveaux du coup d'œil, ajoutés le 2026-11-27 pour la fenêtre de réglages. Ils
# n'ont pas été jugés sur un écran réel, contrairement au niveau moyen.
NIVEAUX_FLOU = {"léger": 120 / 540, "moyen": FLOU, "fort": 55 / 540}
# Sans la mesure de la pose, l'attente fixe d'avant le 2026-11-19.
ATTENTE_FIXE = 1.5

# Les réglages d'un run, quand la configuration n'en dit rien. Ce sont ceux d'avant la fenêtre
# de réglages : les trois appuis humains allumés, les quatre ajoutés le 2026-11-27 éteints.
OPTIONS = {"flou": True, "flou_niveau": "moyen", "lecture_max": LECTURE_MAX,
           "doigt": True, "doigt_mm": DOIGT_MM, "pose": True, "pose_max": POSE["max"],
           "double_toucher": False, "double_seuil": 1.0,
           "fautes": False, "fautes_taux": 0.05,
           "memoire_courte": False, "memoire_ecrans": 3,
           "interruption": False, "interruption_geste": None, "interruption_duree": 10}
# Les touches voisines sur un clavier AZERTY de téléphone. La faute la plus courante est le doigt
# qui tombe sur la lettre d'à côté.
RANGEES_AZERTY = ("azertyuiop", "qsdfghjklm", "wxcvbn")

AIDE = """Usage : ./piloter <geste> [arguments] -- "ton commentaire"
Gestes :
  voir                      photographier l'écran sans rien toucher
  toucher X Y               toucher le point (X, Y) du dernier coup d'œil
  glisser X1 Y1 X2 Y2       glisser du premier point au second
  taper "texte"             écrire dans le champ qui a la main
  retour                    le bouton retour du téléphone, ou la page précédente
  attendre S                patienter S secondes, 10 au plus
  relancer                  rouvrir l'app depuis son icône
  lire X1 Y1 X2 Y2          lire, net, le rectangle entre deux coins du dernier coup d'œil
Chaque capture est un coup d'œil : le petit texte n'y est pas lisible. « lire » compte comme un
geste, et rend au plus un quart de l'écran.
Le commentaire est obligatoire. Dis ce que tu vois, ce que tu cherches, et pourquoi ce geste."""

# Le nombre d'arguments de chaque geste. Un geste absent de la table est refusé.
ARITE = {"voir": 0, "toucher": 2, "glisser": 4, "taper": 1, "retour": 0, "attendre": 1,
         "relancer": 0, "lire": 4}


# Sans coup d'œil flou, l'aide ne parle plus de flou. `principal` la règle une fois la
# configuration lue.
AIDE_NETTE = AIDE.replace("""Chaque capture est un coup d'œil : le petit texte n'y est pas lisible. « lire » compte comme un
geste, et rend au plus un quart de l'écran.
""", "")
aide_courante = AIDE


def refuser(message):
    """Arrête sur un message que le testeur peut comprendre, sans chemin ni nom de projet."""
    print(f"piloter : {message}\n\n{aide_courante}", file=sys.stderr)
    sys.exit(2)


def options(conf):
    """Les réglages du run, ceux de la configuration complétés par les défauts."""
    return {**OPTIONS, **conf.get("options", {})}


def lire_appel(arguments):
    """Sépare le geste, ses arguments et le commentaire, ou refuse."""
    if "--" not in arguments:
        refuser("il manque le commentaire, après --")
    coupure = arguments.index("--")
    avant, commentaire = arguments[:coupure], " ".join(arguments[coupure + 1:]).strip()
    if not avant or avant[0] not in ARITE:
        refuser("geste inconnu")
    geste, valeurs = avant[0], avant[1:]
    if len(valeurs) != ARITE[geste]:
        refuser(f"« {geste} » attend {ARITE[geste]} argument(s)")
    if len(commentaire) < 10:
        refuser("le commentaire est trop court pour être lu par quelqu'un d'autre")
    if geste in ("toucher", "glisser", "attendre", "lire"):
        try:
            valeurs = [float(v) for v in valeurs]
        except ValueError:
            refuser(f"« {geste} » attend des nombres")
    return geste, valeurs, commentaire


def lire_configuration():
    chemin = os.environ.get("F5_PILOTE")
    if not chemin or not Path(chemin).is_file():
        refuser("le pilote n'est pas branché, préviens la personne qui t'a lancé")
    conf = json.loads(Path(chemin).read_text(encoding="utf-8"))
    if not conf.get("dossier_net"):
        refuser("le pilote n'est pas branché, préviens la personne qui t'a lancé")
    return conf


def hasard_du_geste(conf, numero, sorte):
    """Un tirage propre au geste et à son usage. Une graine dans la configuration le rend
    rejouable, pour les essais."""
    graine = conf.get("graine")
    return random.Random(f"{graine}-{numero}-{sorte}") if graine is not None else random.Random()


def tirer_doigt(conf, numero):
    """L'écart du doigt pour ce geste, en millimètres, sur chaque axe. Nul si le doigt est exact."""
    reglages = options(conf)
    if not reglages["doigt"]:
        return [0, 0]
    hasard = hasard_du_geste(conf, numero, "doigt")
    ecart_type = reglages["doigt_mm"]
    borne = ecart_type * DOIGT_BORNE
    return [max(-borne, min(borne, hasard.gauss(0, ecart_type))) for _ in range(2)]


def faire_des_fautes(conf, numero, texte):
    """Le texte tel que le pouce l'a tapé. Une lettre sur vingt par défaut est fautive.

    La faute est l'une des trois d'un pouce pressé. La lettre voisine sur le clavier, une lettre
    oubliée, ou une lettre doublée. Seules les lettres sans accent fautent, pour qu'Android sache
    encore taper le résultat."""
    reglages = options(conf)
    if not reglages["fautes"]:
        return texte
    hasard = hasard_du_geste(conf, numero, "fautes")
    tape = []
    for lettre in texte:
        bas = lettre.lower()
        rangee = next((r for r in RANGEES_AZERTY if bas in r), None)
        if rangee is None or hasard.random() >= reglages["fautes_taux"]:
            tape.append(lettre)
            continue
        sorte = hasard.choice(("voisine", "oubliee", "doublee"))
        if sorte == "voisine":
            i = rangee.index(bas)
            voisines = [rangee[j] for j in (i - 1, i + 1) if 0 <= j < len(rangee)]
            voisine = hasard.choice(voisines)
            tape.append(voisine.upper() if lettre.isupper() else voisine)
        elif sorte == "doublee":
            tape.append(lettre * 2)
    # Un texte d'une lettre oubliée ne partirait pas du tout. Revue de la 121.
    return "".join(tape) or texte


def empreinte(png):
    """La photo réduite en gris, de quoi dire si l'écran a bougé entre deux photos."""
    cote = POSE["cote"]
    commande = ["ffmpeg", "-loglevel", "error", "-i", "pipe:0", "-vf",
                f"scale={cote}:{cote},format=gray", "-f", "rawvideo", "pipe:1"]
    return subprocess.run(commande, input=png, capture_output=True, check=True, timeout=60).stdout


def a_bouge(avant, apres):
    if len(avant) != len(apres):
        return True
    changes = sum(1 for a, b in zip(avant, apres) if abs(a - b) > POSE["ecart"])
    return changes > POSE["seuil"] * len(avant)


def est_vide(gris):
    """L'écran est presque uni, barres du système exclues.

    Les quatre rangées du haut et du bas tombent. Une barre d'état colorée faisait 2,6 % des
    points, et un chargement blanc dessous ne passait plus pour vide. Relevé par la revue de la
    114."""
    bande = POSE["bande"] * POSE["cote"]
    corps = gris[bande:len(gris) - bande] if len(gris) > 2 * bande else gris
    mediane = sorted(corps)[len(corps) // 2]
    proches = sum(1 for v in corps if abs(v - mediane) <= POSE["uni_ecart"])
    return proches >= POSE["uni_part"] * len(corps)


def attendre_la_pose(photographier, double=None):
    """Photographie jusqu'à ce que l'écran ne bouge plus. Rend la dernière photo et la durée.

    `double` porte le toucher impatient : l'empreinte de l'écran d'avant le geste, le délai, et
    le geste à rejouer. Si l'écran n'a toujours pas bougé au bout du délai, le geste se rejoue
    une fois, comme un humain qui retouche. `double` dit alors s'il a servi, par sa clé "fait".

    Le dernier changement a eu lieu entre la photo d'avant et celle qui le montre. La durée court
    jusqu'au milieu des deux demandes. Une capture prend une seconde sur un vrai téléphone, et
    chaque borne fausserait d'autant. Relevé par les revues de la 114.

    La durée se tronque au dixième, pour qu'une durée sous la demi-seconde reste « aussitôt ».
    Au bout du temps permis, elle vaut "vide" si l'écran est resté vide, "bouge" s'il bougeait."""
    depart = time.monotonic()
    photo = photographier()
    precedente, changement, avant = empreinte(photo), depart, depart
    vide = est_vide(precedente)
    duree = 0.0
    # L'écran a réagi au geste dès la première photo, ou pas encore.
    reagi = double is None or a_bouge(double["avant"], precedente)
    while time.monotonic() - changement < POSE["calme"] or vide or not reagi:
        if not reagi and time.monotonic() - depart >= double["seuil"]:
            double["rejouer"]()
            double["fait"], reagi = True, True
            # Le calme se compte depuis le second toucher. Sinon, la photo d'après partait
            # avant que l'écran n'y ait répondu. Relevé par la revue de la 121.
            changement = avant = time.monotonic()
        if time.monotonic() - depart >= POSE["max"]:
            return photo, "vide" if vide else "bouge"
        time.sleep(POSE["pas"])
        demande = time.monotonic()
        photo = photographier()
        actuelle = empreinte(photo)
        if a_bouge(precedente, actuelle):
            changement, duree = demande, (avant + demande) / 2 - depart
            precedente, vide, reagi = actuelle, est_vide(actuelle), True
        avant = demande
    return photo, math.floor(duree * 10) / 10


def attente_fixe(photographier, double=None):
    """Sans la mesure de la pose : une photo après 1,5 s, sans durée à dire.

    Le toucher impatient y garde sa place. Une photo au bout du délai dit si l'écran a réagi, et
    le geste se rejoue sinon, avant le reste de l'attente."""
    if double is not None:
        time.sleep(double["seuil"])
        if not a_bouge(double["avant"], empreinte(photographier())):
            double["rejouer"]()
            double["fait"] = True
        # Après un second toucher, l'attente repart en entier. Revue de la 121.
        time.sleep(ATTENTE_FIXE if double["fait"] else max(0.0, ATTENTE_FIXE - double["seuil"]))
    else:
        time.sleep(ATTENTE_FIXE)
    return photographier(), None


def phrase_de_pose(duree):
    if duree == "vide":
        return f"L'écran est resté vide {POSE['max']} s."
    if duree == "bouge":
        return f"L'écran bouge encore après {POSE['max']} s."
    if duree < 0.5:
        return "L'écran s'est posé aussitôt."
    return f"L'écran a mis {duree:.1f} s à se poser.".replace(".", ",", 1)


def taille_image(chemin):
    """La largeur et la hauteur d'une image, lues par ffprobe.

    Un lecteur de JPEG écrit à la main ratait les octets de remplissage et des marqueurs rares.
    ffprobe vient avec ffmpeg, déjà requis. Relevé par la revue de la 113, le 2026-11-19."""
    resultat = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                               "stream=width,height", "-of", "csv=p=0", str(chemin)],
                              capture_output=True, text=True, timeout=30)
    try:
        largeur, hauteur = (int(v) for v in resultat.stdout.strip().split(","))
    except ValueError:
        raise RuntimeError("la capture est illisible") from None
    return largeur, hauteur


def filtre_flou(largeur, hauteur, niveau=FLOU):
    """Le coup d'œil : réduire, puis ré-agrandir à la taille de la capture nette."""
    petite = max(1, round(largeur * niveau))
    return f"scale={petite}:-1:flags=area,scale={largeur}:{hauteur}:flags=bicubic"


def flouter(nette, destination, niveau=FLOU):
    """Le coup d'œil tiré de la capture nette. Rend sa largeur et sa hauteur.

    Sans niveau, le flou est éteint, et le testeur reçoit la capture nette elle-même."""
    largeur, hauteur = taille_image(nette)
    if niveau is None:
        shutil.copyfile(nette, destination)
        return largeur, hauteur
    commande = ["ffmpeg", "-loglevel", "error", "-y", "-i", str(nette), "-vf",
                filtre_flou(largeur, hauteur, niveau), "-q:v", "4", str(destination)]
    subprocess.run(commande, check=True, timeout=60)
    return largeur, hauteur


def niveau_de_flou(conf):
    """La part de la largeur que garde le coup d'œil, ou None si le flou est éteint."""
    reglages = options(conf)
    return NIVEAUX_FLOU[reglages["flou_niveau"]] if reglages["flou"] else None


def dernier_coup_d_oeil(conf):
    """La taille du dernier coup d'œil, ou None s'il n'y en a pas encore."""
    dernier = Path(conf["dossier_net"]) / ".coup-d-oeil"
    if not dernier.is_file():
        return None
    largeur, hauteur = (int(v) for v in dernier.read_text().split())
    return largeur, hauteur


def zone_lisible(conf, valeurs):
    """Le rectangle à lire, dans le repère du dernier coup d'œil, ou un refus."""
    taille = dernier_coup_d_oeil(conf)
    if taille is None:
        refuser("« lire » se vise sur un coup d'œil. Commence par ./piloter voir")
    largeur, hauteur = taille
    # Un coin infini ferait échouer l'arrondi, et « nan » déjoue le rognage.
    if not all(math.isfinite(v) for v in valeurs):
        refuser("la zone à lire est vide ou hors de l'écran")
    # Les coins se donnent dans n'importe quel ordre, et ce qui déborde de l'écran se rogne. Ils
    # s'arrondissent avant le contrôle : une zone d'un pixel pouvait s'arrondir à zéro.
    x1, x2 = sorted(valeurs[0::2])
    y1, y2 = sorted(valeurs[1::2])
    x1, y1 = round(max(0, x1)), round(max(0, y1))
    x2, y2 = round(min(largeur, x2)), round(min(hauteur, y2))
    if x2 - x1 < 1 or y2 - y1 < 1:
        refuser("la zone à lire est vide ou hors de l'écran")
    part = options(conf)["lecture_max"]
    if (x2 - x1) * (y2 - y1) > part * largeur * hauteur:
        refuser(f"tu ne peux lire {que(texte_de_part(part))} de l'écran à la fois")
    return [x1, y1, x2, y2]


def texte_de_part(part):
    """« un quart », « la moitié », ou un pourcentage, pour le message de refus."""
    mots = {0.25: "un quart", 0.5: "la moitié", 1.0: "la totalité"}
    return mots.get(round(part, 2), f"{round(part * 100)} %")


def que(suite):
    """« qu'un quart », « que la moitié » : l'élision devant une voyelle."""
    return f"qu'{suite}" if suite[:1] in "aeiouy" else f"que {suite}"


def decouper(nette, taille_nette, zone, destination, coup_d_oeil):
    """La zone lue, nette, rognée sur la capture prise au moment de lire. Rend sa largeur.

    La zone se vise sur le dernier coup d'œil. Un écran qui a changé de taille depuis, tourné en
    paysage par exemple, rendrait une bande sans rapport. Relevé par la revue de la 113."""
    if taille_nette != coup_d_oeil:
        raise RuntimeError("l'écran a changé de forme depuis ton dernier coup d'œil. "
                           "Regarde-le à nouveau par ./piloter voir, puis vise ta lecture dessus")
    l, h = zone[2] - zone[0], zone[3] - zone[1]
    commande = ["ffmpeg", "-loglevel", "error", "-y", "-i", str(nette), "-vf",
                f"crop={l}:{h}:{zone[0]}:{zone[1]}", "-q:v", "3", str(destination)]
    subprocess.run(commande, check=True, timeout=60)
    return l


# ── Android, par adb ─────────────────────────────────────────────────────────────────────────


def adb(conf, *arguments, sortie_binaire=False):
    commande = [conf["adb"], "-s", conf["serie"], *arguments]
    resultat = subprocess.run(commande, capture_output=True, timeout=60)
    if resultat.returncode != 0:
        raise RuntimeError(resultat.stderr.decode(errors="replace").strip() or "adb a échoué")
    return resultat.stdout if sortie_binaire else resultat.stdout.decode(errors="replace")


# La largeur et la hauteur réelles de la dernière capture. Un écran tourné en paysage change de
# largeur, et le facteur mesuré au démarrage ne vaut plus.
LARGEUR_ECRAN = ICI / ".largeur-ecran"


def facteur_actuel(conf):
    if LARGEUR_ECRAN.is_file():
        return int(LARGEUR_ECRAN.read_text().split()[0]) / conf["largeur_capture"]
    return conf["facteur"]


def vers_ecran(conf, valeurs):
    """Convertit des coordonnées de capture dans le repère où le geste se joue."""
    facteur = facteur_actuel(conf)
    return [str(round(v * facteur)) for v in valeurs]


def densite_android(conf):
    """Les points par pouce de l'écran, que `wm density` rend. Lus une fois par testeur.

    La densité physique gagne. Une densité forcée agrandit l'affichage, pas le pouce, et elle
    élargissait le doigt d'un tiers. Relevé par la revue de la 114."""
    cache = Path(conf["dossier_net"]) / ".densite"
    if cache.is_file():
        return int(cache.read_text())
    lignes = adb(conf, "shell", "wm", "density").splitlines()
    lignes = sorted(lignes, key=lambda l: "Physical" not in l)
    nombres = [l.split(":")[-1].strip() for l in lignes]
    nombres = [int(n) for n in nombres if n.isdigit()]
    if not nombres:
        raise RuntimeError("la densité de l'écran est illisible")
    cache.write_text(str(nombres[0]))
    return nombres[0]


def decaler(valeurs, ecart, largeur, hauteur):
    """Décale tous les points du même écart, réduit pour qu'aucun ne sorte de l'écran.

    Borner chaque point seul raccourcissait un glisser près d'un bord. Relevé par la revue de la
    114. Un point visé hors de l'écran s'y ramène ensuite."""
    touche = list(valeurs)
    for axe, borne in ((0, largeur), (1, hauteur)):
        points = valeurs[axe::2]
        bas, haut = max(-v for v in points), min(borne - 1 - v for v in points)
        e = max(bas, min(haut, ecart[axe])) if bas <= haut else 0
        touche[axe::2] = [max(0, min(borne - 1, v + e)) for v in points]
    return touche


def taille_png(png):
    """La largeur et la hauteur d'un PNG, lues dans son en-tête, aux octets 16 à 23."""
    largeur, hauteur = int.from_bytes(png[16:20], "big"), int.from_bytes(png[20:24], "big")
    if len(png) < 24 or not largeur or not hauteur:
        raise RuntimeError("la capture est illisible")
    return largeur, hauteur


def taille_ecran_android(conf):
    """La largeur et la hauteur réelles de l'écran, celles de la dernière capture.

    Sans capture lisible, ancien format ou toucher avant tout voir, une photo la donne."""
    try:
        largeur, hauteur = (int(v) for v in LARGEUR_ECRAN.read_text().split())
        return largeur, hauteur
    except (OSError, ValueError):
        largeur, hauteur = taille_png(photo_android(conf))
        LARGEUR_ECRAN.write_text(f"{largeur} {hauteur}")
        return largeur, hauteur


def decaler_android(conf, valeurs, ecart_mm):
    """Le point touché, dans le repère de la capture, et resté dans l'écran."""
    largeur, hauteur = taille_ecran_android(conf)
    facteur = facteur_actuel(conf)
    par_mm = densite_android(conf) / 25.4 / facteur
    ecart = [e * par_mm for e in ecart_mm]
    return [round(v) for v in decaler(valeurs, ecart, largeur / facteur, hauteur / facteur)]


def texte_pour_adb(texte):
    """`input text` coupe aux espaces et lit le shell du téléphone, d'où l'échappement.

    Il ne lit que la séquence `%s`, pour une espace. Un `%` seul passe donc tel quel.
    """
    return "'" + texte.replace(" ", "%s").replace("'", "'\\''") + "'"


def agir_android(conf, geste, valeurs):
    gestes = {
        "toucher": lambda: adb(conf, "shell", "input", "tap", *valeurs),
        "glisser": lambda: adb(conf, "shell", "input", "swipe", *valeurs, "400"),
        "taper": lambda: adb(conf, "shell", "input", "text", texte_pour_adb(valeurs[0])),
        "retour": lambda: adb(conf, "shell", "input", "keyevent", "4"),
        "relancer": lambda: relancer_android(conf),
    }
    if geste in gestes:
        gestes[geste]()


def relancer_android(conf):
    """Rouvre l'app. Pour Chrome sur Android, rouvre le site, comme un lien suivi à nouveau."""
    if conf.get("url"):
        # `adb shell` relit sa ligne dans le shell du téléphone. Une esperluette y couperait
        # l'adresse. Relevé par la revue de la 121.
        adb(conf, "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d",
            shlex.quote(conf["url"]), "-p", conf["paquet"])
    else:
        adb(conf, "shell", "monkey", "-p", conf["paquet"], "-c",
            "android.intent.category.LAUNCHER", "1")


def photo_android(conf):
    return adb(conf, "exec-out", "screencap", "-p", sortie_binaire=True)


def photographier_android(conf, nette, floue=None, png=None, niveau=FLOU):
    """La capture nette, ramenée à la largeur de travail en JPEG, et son coup d'œil si demandé.

    Les deux sortent d'un seul ffmpeg, tirés de la photo brute. Le flou se calculait sur le JPEG
    déjà compressé, par un second ffmpeg. Relevé par la revue de la 113, le 2026-11-19.

    Une photo déjà prise, pendant l'attente de la pose, sert sans en reprendre une.
    Rend la largeur et la hauteur de la capture nette."""
    brute = nette.with_suffix(".brute.png")
    png = png or photo_android(conf)
    brute.write_bytes(png)
    largeur_ecran, hauteur_ecran = taille_png(png)
    LARGEUR_ECRAN.write_text(f"{largeur_ecran} {hauteur_ecran}")
    largeur = conf["largeur_capture"]
    hauteur = max(2, 2 * round(hauteur_ecran * largeur / largeur_ecran / 2))
    reduite = f"scale={largeur}:{hauteur}"
    if floue is None or niveau is None:
        sorties = ["-vf", reduite, "-q:v", "4", str(nette)]
    else:
        sorties = ["-filter_complex",
                   f"[0]{reduite},split[n][f];[f]{filtre_flou(largeur, hauteur, niveau)}[o]",
                   "-map", "[n]", "-q:v", "4", str(nette), "-map", "[o]", "-q:v", "4", str(floue)]
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(brute), *sorties],
                   check=True, timeout=60)
    brute.unlink()
    if floue is not None and niveau is None:
        # Flou éteint : le testeur reçoit la capture nette elle-même.
        shutil.copyfile(nette, floue)
    return largeur, hauteur


def interrompre_android(conf, duree):
    """L'app passe en arrière-plan, comme pour un appel, puis revient là où elle était."""
    adb(conf, "shell", "input", "keyevent", "3")
    time.sleep(duree)
    adb(conf, "shell", "monkey", "-p", conf["paquet"], "-c",
        "android.intent.category.LAUNCHER", "1")


def remarques_android(conf):
    """Ce qu'un humain verrait sans le dire : l'app n'est plus à l'écran."""
    activite = adb(conf, "shell", "dumpsys", "activity", "activities")
    premier_plan = [l for l in activite.splitlines() if "topResumedActivity" in l
                    or "mResumedActivity" in l]
    if premier_plan and conf["paquet"] not in premier_plan[0]:
        # Le constat seul, sans la commande qui ramène : un humain n'a personne pour la lui
        # souffler. Décidé le 2026-11-19. Chrome Android teste un site. Revue de la 121.
        if conf.get("url"):
            return ["Le navigateur n'est plus au premier plan."]
        return ["L'app n'est plus au premier plan."]
    return []


# ── Web, par le pilote Playwright ────────────────────────────────────────────────────────────


def panne_node(node):
    """Arrête le pilote Node, et rend l'erreur qu'il a dite."""
    node.kill()
    node.wait()
    node.erreurs.seek(0)
    erreur = node.erreurs.read().decode(errors="replace").strip()
    return RuntimeError(erreur or "le navigateur n'a pas répondu")


def ecrire_a_node(node, ligne, fermer=False):
    try:
        node.stdin.write(ligne)
        node.stdin.flush()
        if fermer:
            node.stdin.close()
    except OSError:
        raise panne_node(node) from None


def photo_node(node):
    """Une photo PNG demandée au pilote Node, qui la rend précédée de sa taille."""
    ecrire_a_node(node, b"photo\n")
    entete = node.stdout.readline().strip()
    if not entete.isdigit():
        raise panne_node(node)
    photo = node.stdout.read(int(entete))
    if len(photo) != int(entete):
        raise panne_node(node)
    return photo


def valeurs_web(node, geste, valeurs, ecart_mm):
    """Les valeurs du geste, doigt décalé dans la page que Node décrit, et le point touché.

    Le web n'a pas de densité d'écran : le pixel CSS vaut le point de densité d'Android, 160 par
    pouce. 2 mm font donc environ 12,6 pixels CSS."""
    entete = node.stdout.readline().split()
    if len(entete) not in (4, 5) or entete[0] != b"taille":
        raise panne_node(node)
    try:
        echelle, largeur, hauteur = (float(v) for v in entete[1:4])
        # Les pixels de capture par pixel d'écran. Ils diffèrent de l'échelle des gestes sur une
        # page dézoomée, où le doigt garde pourtant sa taille réelle. 2026-11-27.
        densite = float(entete[4]) if len(entete) == 5 else echelle
    except ValueError:
        raise panne_node(node) from None
    if geste not in ("toucher", "glisser"):
        return valeurs, None
    ecart = [mm * 160 / 25.4 * densite for mm in ecart_mm]
    touche = decaler(valeurs, ecart, largeur * echelle, hauteur * echelle)
    return touche, [round(v) for v in touche]


def agir_web(conf, geste, valeurs, ecart_mm, mesurer, impatient=False, interruption=None):
    """Fait agir le pilote Node, puis lui demande des photos. Rend la dernière, la pose et sa sortie.

    Il relit la même configuration, par la variable d'environnement héritée. L'écart du doigt
    lui arrive par l'environnement, tiré ici seulement.

    L'attente de la pose tourne ici, pour les deux plateformes. Le pilote Node en portait une
    copie, qui divergeait déjà. Relevé par la revue de la 114.

    Il donne d'abord la taille de la page, et reçoit les valeurs du geste, doigt décalé. Il dit
    « fait » après le geste, puis rend une photo par ligne « photo ». La ligne « fin » le fait
    conclure en JSON. Attendre « fait » garde son lancement hors de la durée mesurée.

    Son erreur s'écrit dans un fichier, qu'aucun tuyau plein ne bloque. Rend aussi le point
    touché, ou None.

    Un toucher impatient demande une photo avant le geste, puis « retoucher » si l'écran tarde.
    Une interruption s'envoie par « interrompre S », après l'attente. Node répond « fait » aux
    deux. Rend aussi, dans le JSON, si le toucher a été rejoué."""
    env = {**os.environ, "NODE_PATH": conf.get("node_path", "")}
    erreurs = tempfile.TemporaryFile()
    node = subprocess.Popen(["node", conf["pilote_web"], geste], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=erreurs, env=env)
    node.erreurs = erreurs
    # Un navigateur figé ne bloque pas le testeur plus de 90 s, en plus des attentes que les
    # réglages permettent dans le geste. Sans elles, une interruption longue tuait chaque geste.
    # Relevé par la revue de la 121.
    reglages = options(conf)
    garde = threading.Timer(90 + reglages["pose_max"] + reglages["double_seuil"]
                            + (interruption or 0), node.kill)
    garde.start()
    try:
        valeurs, touche = valeurs_web(node, geste, valeurs, ecart_mm)
        double = None
        if impatient and geste == "toucher":
            double = {"avant": empreinte(photo_node(node)), "seuil": options(conf)["double_seuil"],
                      "rejouer": lambda: attendre_fait(node, b"retoucher\n"), "fait": False}
        ecrire_a_node(node, json.dumps(valeurs).encode() + b"\n")
        if node.stdout.readline().strip() != b"fait":
            raise panne_node(node)
        if mesurer and options(conf)["pose"]:
            photo, pose = attendre_la_pose(lambda: photo_node(node), double)
        elif mesurer:
            photo, pose = attente_fixe(lambda: photo_node(node), double)
        else:
            photo, pose = photo_node(node), None
        if interruption is not None:
            attendre_fait(node, f"interrompre {interruption}\n".encode())
            marquer_l_interruption(conf)
            photo = photo_node(node)
        ecrire_a_node(node, b"fin\n", fermer=True)
        sortie = node.stdout.read()
        if node.wait() != 0:
            raise panne_node(node)
        try:
            retour = json.loads(sortie)
        except ValueError:
            raise RuntimeError("le navigateur a rendu une réponse illisible") from None
        retour["double"] = bool(double and double["fait"])
        return photo, pose, touche, retour
    finally:
        garde.cancel()
        node.kill()
        node.wait()
        erreurs.close()


def attendre_fait(node, ligne):
    """Une demande à Node qui n'attend que son « fait »."""
    ecrire_a_node(node, ligne)
    if node.stdout.readline().strip() != b"fait":
        raise panne_node(node)


def ecrire_jpeg(png, destination):
    """La photo PNG du navigateur, écrite en JPEG comme celles d'Android."""
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", "pipe:0", "-q:v", "4",
                    str(destination)], input=png, check=True, capture_output=True, timeout=60)


# ── Le geste ─────────────────────────────────────────────────────────────────────────────────


def dossier_des_anciens(conf):
    """Où partent les captures que la mémoire courte retire au testeur, hors de son dossier."""
    return Path(conf["dossier_net"]) / "anciens"


def numero_suivant(conf):
    """Le numéro du geste, captures retirées par la mémoire courte comprises."""
    CAPTURES.mkdir(exist_ok=True)
    anciens = dossier_des_anciens(conf)
    retirees = len(list(anciens.glob("*.jpg"))) if anciens.is_dir() else 0
    return len(list(CAPTURES.glob("*.jpg"))) + retirees + 1


def oublier(conf, numero):
    """La mémoire courte : seules les dernières captures restent dans le dossier du testeur.

    Les autres partent hors de sa portée. Le lanceur les remet à leur place au rapatriement, pour
    la synthèse. Le modèle garde en tête ce qu'il a déjà ouvert. Sa consigne lui demande donc de
    faire comme une personne qui ne s'en souvient que vaguement.

    Le dernier coup d'œil reste, même ancien : les coordonnées s'y lisent, et une suite de
    lectures l'aurait sinon retiré. Relevé par la revue de la 121."""
    reglages = options(conf)
    if not reglages["memoire_courte"]:
        return
    anciens = dossier_des_anciens(conf)
    anciens.mkdir(exist_ok=True)
    garde = dernier_coup_d_oeil_numero()
    for capture in CAPTURES.glob("*.jpg"):
        if (capture.stem.isdigit() and int(capture.stem) <= numero - reglages["memoire_ecrans"]
                and int(capture.stem) != garde):
            shutil.move(str(capture), anciens / capture.name)


def dernier_coup_d_oeil_numero():
    """Le numéro du dernier geste réussi qui n'était pas une lecture, d'après le journal."""
    numero = None
    if JOURNAL.is_file():
        for ligne in JOURNAL.read_text(encoding="utf-8").splitlines():
            entree = json.loads(ligne)
            if entree.get("geste") != "lire" and not entree.get("erreur"):
                numero = entree["n"]
    return numero


def interruption_due(conf, numero, geste):
    """La durée de l'interruption si elle tombe sur ce geste, sinon None.

    Elle tombe une fois, au geste que le lanceur a tiré, ou au premier geste qui suit si celui-là
    était une lecture. Lire ne touche pas l'app, et une interruption n'y aurait pas de sens."""
    reglages = options(conf)
    fait = Path(conf["dossier_net"]) / ".interrompu"
    if (not reglages["interruption"] or reglages["interruption_geste"] is None or geste == "lire"
            or numero < reglages["interruption_geste"] or fait.exists()):
        return None
    return reglages["interruption_duree"]


def marquer_l_interruption(conf):
    """L'interruption a eu lieu. Elle ne revient pas, même si la photo d'après échoue."""
    (Path(conf["dossier_net"]) / ".interrompu").touch()


def jouer(conf, geste, valeurs, destination, numero):
    """Joue le geste, photographie net hors du dossier du testeur, et lui rend un coup d'œil.

    `lire` ne touche à rien. Il photographie l'écran tel qu'il est, et rend la zone nette.
    Rend la largeur du coup d'œil, les remarques, et ce qui entre au journal en plus."""
    nette = Path(conf["dossier_net"]) / destination.name
    reglages = options(conf)
    lire = geste == "lire"
    mesurer = geste in GESTES_MESURES
    impatient = reglages["double_toucher"] and geste == "toucher"
    interruption = interruption_due(conf, numero, geste)
    niveau = niveau_de_flou(conf)
    infos = {}
    ecart_mm = tirer_doigt(conf, numero) if geste in ("toucher", "glisser") else [0, 0]
    if geste == "taper":
        tape = faire_des_fautes(conf, numero, valeurs[0])
        if tape != valeurs[0]:
            infos["voulu"], infos["tape"] = valeurs[0], tape
        valeurs = [tape]
    if geste == "attendre":
        time.sleep(min(valeurs[0], ATTENTE_MAX))
    if conf["plateforme"] == "web":
        sans_effet = geste in ("attendre", "lire")
        photo, pose, touche, retour = agir_web(conf, "voir" if sans_effet else geste,
                                               [] if sans_effet else valeurs, ecart_mm, mesurer,
                                               impatient, interruption)
        ecrire_jpeg(photo, nette)
        remarques = retour.get("remarques", [])
        if touche:
            infos["vise"], infos["touche"] = valeurs, touche
        if retour.get("double"):
            infos["double"] = True
        if mesurer and pose is not None:
            infos["pose"] = pose
        taille = taille_image(nette) if lire else flouter(nette, destination, niveau)
    else:
        if geste in ("toucher", "glisser"):
            touche = decaler_android(conf, valeurs, ecart_mm)
            infos["vise"], infos["touche"] = valeurs, touche
            valeurs = vers_ecran(conf, touche)
        double = None
        if impatient:
            double = {"avant": empreinte(photo_android(conf)), "seuil": reglages["double_seuil"],
                      "rejouer": lambda: agir_android(conf, geste, valeurs), "fait": False}
        agir_android(conf, geste, valeurs)
        png = None
        if mesurer:
            attente = attendre_la_pose if reglages["pose"] else attente_fixe
            png, pose = attente(lambda: photo_android(conf), double)
            if pose is not None:
                infos["pose"] = pose
        if double and double["fait"]:
            infos["double"] = True
        if interruption is not None:
            interrompre_android(conf, interruption)
            marquer_l_interruption(conf)
            png = None
        taille = photographier_android(conf, nette, None if lire else destination, png, niveau)
        remarques = remarques_android(conf)
    if interruption is not None:
        infos["interruption"] = interruption
        # Sur un site, c'est un onglet qui est passé derrière, pas une app.
        retour_a = "au site" if conf["plateforme"] == "web" or conf.get("url") else "à l'app"
        remarques = [f"Tu as été interrompu {interruption} s, puis tu es revenu {retour_a}.",
                     *remarques]
    if lire:
        return (decouper(nette, taille, valeurs, destination, dernier_coup_d_oeil(conf)),
                remarques, infos)
    (Path(conf["dossier_net"]) / ".coup-d-oeil").write_text(f"{taille[0]} {taille[1]}")
    return taille[0], remarques, infos


def consigner(numero, geste, valeurs, commentaire, capture, erreur, infos=None):
    """Une ligne de journal. `vise` et `touche` disent où le doigt visait et où il est tombé.

    `pose` dit en combien de secondes l'écran s'est posé. Elle vaut "vide" ou "bouge" au bout de
    l'attente maximale du run, dix secondes par défaut."""
    ligne = {"n": numero, "heure": datetime.now().isoformat(timespec="seconds"),
             "geste": geste, "valeurs": valeurs, "commentaire": commentaire,
             "capture": capture, "erreur": erreur, **(infos or {})}
    with JOURNAL.open("a", encoding="utf-8") as journal:
        journal.write(json.dumps(ligne, ensure_ascii=False) + "\n")


def principal():
    global aide_courante
    conf = lire_configuration()
    if not options(conf)["flou"]:
        aide_courante = AIDE_NETTE
    else:
        aide_courante = AIDE.replace("au plus un quart de l'écran",
                                     f"au plus {texte_de_part(options(conf)['lecture_max'])} de l'écran")
    if conf["plateforme"] == "android" and conf.get("url"):
        # Chrome Android teste un site, que `relancer` rouvre. Revue de la 121.
        aide_courante = aide_courante.replace("rouvrir l'app depuis son icône", "rouvrir le site")
    POSE["max"] = options(conf)["pose_max"]
    geste, valeurs, commentaire = lire_appel(sys.argv[1:])
    if conf["plateforme"] == "android" and geste == "taper" and not valeurs[0].isascii():
        # `input text` d'Android ne sait pas taper une lettre accentuée.
        refuser("« taper » n'écrit ici que des lettres sans accent. C'est une limite du pilote, "
                "pas de l'app")
    numero = numero_suivant(conf)
    if numero > conf.get("actions_max", numero):
        refuser(f"tu as fait tes {conf['actions_max']} gestes. Rends ton rapport maintenant")
    if geste == "lire":
        valeurs = zone_lisible(conf, valeurs)
    capture = f"captures/{numero:03d}.jpg"
    try:
        largeur, remarques, infos = jouer(conf, geste, valeurs, ICI / capture, numero)
    except (RuntimeError, subprocess.SubprocessError, OSError) as panne:
        # La panne entre au journal : un geste qui n'a rien fait reste un fait du parcours.
        consigner(numero, geste, valeurs, commentaire, None, str(panne))
        # Son numéro resservira au geste suivant. Ses deux captures partent, pour que nettes/ et
        # captures/ gardent le même écran sous le même numéro. Le dernier coup d'œil part aussi :
        # l'écran a pu changer sans qu'un coup d'œil le montre, et « lire » viserait à l'aveugle.
        # Relevé par les revues de la 113, le 2026-11-19.
        for perdu in (ICI / capture, Path(conf["dossier_net"]) / Path(capture).name,
                      Path(conf["dossier_net"]) / ".coup-d-oeil"):
            perdu.unlink(missing_ok=True)
        print(f"Le geste n'a pas pu se faire : {panne}")
        return 1
    consigner(numero, geste, valeurs, commentaire, capture, None, infos)
    oublier(conf, numero)
    if geste == "lire":
        print(f"Geste {numero} fait. Ce que tu as lu, net : {capture} ({largeur} px de large).")
        print("Ouvre-la. Tes coordonnées se lisent toujours sur le dernier coup d'œil.")
    elif not options(conf)["flou"]:
        print(f"Geste {numero} fait. Capture : {capture} ({largeur} px de large).")
        print("Ouvre-la avant le geste suivant, tes coordonnées se lisent sur elle.")
    else:
        print(f"Geste {numero} fait. Coup d'œil : {capture} ({largeur} px de large).")
        print("Ouvre-le avant le geste suivant, tes coordonnées se lisent sur lui. Le petit texte "
              "n'y est pas lisible : ./piloter lire X1 Y1 X2 Y2 en lit un passage.")
    if "pose" in infos:
        print(phrase_de_pose(infos["pose"]))
    for remarque in remarques:
        print(f"Remarque : {remarque}")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
