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
- **Des coordonnées dans le repère de la capture.** Le testeur vise ce qu'il voit, et le pilote
  convertit vers l'écran réel. Sans ça, il viserait à côté sur chaque écran haute définition.
  Côté Android, ce script convertit. Côté web, le pilote Node mesure l'échelle sur la page.

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
    ./piloter relancer -- "L'app s'est fermée, je la rouvre depuis son icône."
"""
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

ICI = Path.cwd()
CAPTURES = ICI / "captures"
JOURNAL = ICI / "journal.jsonl"
# Le temps laissé à l'écran pour réagir avant la photo. En dessous, une capture sur trois
# montrait encore l'écran d'avant, donc un geste « sans effet » qui en avait un.
REPOS_APRES_GESTE = 1.5
ATTENTE_MAX = 10

AIDE = """Usage : ./piloter <geste> [arguments] -- "ton commentaire"
Gestes :
  voir                      photographier l'écran sans rien toucher
  toucher X Y               toucher le point (X, Y) de la dernière capture
  glisser X1 Y1 X2 Y2       glisser du premier point au second
  taper "texte"             écrire dans le champ qui a la main
  retour                    le bouton retour du téléphone, ou la page précédente
  attendre S                patienter S secondes, 10 au plus
  relancer                  rouvrir l'app depuis son icône
Le commentaire est obligatoire. Dis ce que tu vois, ce que tu cherches, et pourquoi ce geste."""

# Le nombre d'arguments de chaque geste. Un geste absent de la table est refusé.
ARITE = {"voir": 0, "toucher": 2, "glisser": 4, "taper": 1, "retour": 0, "attendre": 1,
         "relancer": 0}


def refuser(message):
    """Arrête sur un message que le testeur peut comprendre, sans chemin ni nom de projet."""
    print(f"piloter : {message}\n\n{AIDE}", file=sys.stderr)
    sys.exit(2)


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
    if geste in ("toucher", "glisser", "attendre"):
        try:
            valeurs = [float(v) for v in valeurs]
        except ValueError:
            refuser(f"« {geste} » attend des nombres")
    return geste, valeurs, commentaire


def lire_configuration():
    chemin = os.environ.get("F5_PILOTE")
    if not chemin or not Path(chemin).is_file():
        refuser("le pilote n'est pas branché, préviens la personne qui t'a lancé")
    return json.loads(Path(chemin).read_text(encoding="utf-8"))


# ── Android, par adb ─────────────────────────────────────────────────────────────────────────


def adb(conf, *arguments, sortie_binaire=False):
    commande = [conf["adb"], "-s", conf["serie"], *arguments]
    resultat = subprocess.run(commande, capture_output=True, timeout=60)
    if resultat.returncode != 0:
        raise RuntimeError(resultat.stderr.decode(errors="replace").strip() or "adb a échoué")
    return resultat.stdout if sortie_binaire else resultat.stdout.decode(errors="replace")


# La largeur réelle de la dernière capture. Un écran tourné en paysage change de largeur, et
# le facteur mesuré au démarrage ne vaut plus.
LARGEUR_ECRAN = ICI / ".largeur-ecran"


def vers_ecran(conf, valeurs):
    """Convertit des coordonnées de capture dans le repère où le geste se joue."""
    facteur = conf["facteur"]
    if LARGEUR_ECRAN.is_file():
        facteur = int(LARGEUR_ECRAN.read_text()) / conf["largeur_capture"]
    return [str(round(v * facteur)) for v in valeurs]


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
        "relancer": lambda: adb(conf, "shell", "monkey", "-p", conf["paquet"], "-c",
                                "android.intent.category.LAUNCHER", "1"),
    }
    if geste in gestes:
        gestes[geste]()


def photographier_android(conf, destination):
    brute = destination.with_suffix(".brute.png")
    png = adb(conf, "exec-out", "screencap", "-p", sortie_binaire=True)
    brute.write_bytes(png)
    # La largeur d'un PNG se lit dans son en-tête, aux octets 16 à 19.
    LARGEUR_ECRAN.write_text(str(int.from_bytes(png[16:20], "big")))
    reduire(brute, destination, conf["largeur_capture"])
    brute.unlink()


def remarques_android(conf):
    """Ce qu'un humain verrait sans le dire : l'app n'est plus à l'écran."""
    activite = adb(conf, "shell", "dumpsys", "activity", "activities")
    premier_plan = [l for l in activite.splitlines() if "topResumedActivity" in l
                    or "mResumedActivity" in l]
    if premier_plan and conf["paquet"] not in premier_plan[0]:
        return ["L'app n'est plus au premier plan. « relancer » la rouvre depuis son icône."]
    return []


def reduire(source, destination, largeur):
    """Ramène la photo à la largeur de travail, en JPEG pour alléger la lecture d'images."""
    commande = ["ffmpeg", "-loglevel", "error", "-y", "-i", str(source), "-vf",
                f"scale={largeur}:-2", "-q:v", "4", str(destination)]
    subprocess.run(commande, check=True, timeout=60)


# ── Web, par le pilote Playwright ────────────────────────────────────────────────────────────


def agir_web(conf, geste, valeurs, destination):
    """Délègue au pilote Node, qui agit, photographie et liste les éléments visibles.

    Il relit la même configuration, par la variable d'environnement héritée.
    """
    commande = ["node", conf["pilote_web"], geste, *map(str, valeurs), str(destination)]
    resultat = subprocess.run(commande, capture_output=True, text=True, timeout=90,
                              env={**os.environ, "NODE_PATH": conf.get("node_path", "")})
    if resultat.returncode != 0:
        raise RuntimeError(resultat.stderr.strip() or "le navigateur n'a pas répondu")
    return json.loads(resultat.stdout)


# ── Le geste ─────────────────────────────────────────────────────────────────────────────────


def numero_suivant():
    CAPTURES.mkdir(exist_ok=True)
    return len(list(CAPTURES.glob("*.jpg"))) + 1


def jouer(conf, geste, valeurs, destination):
    """Joue le geste, photographie, et rend ce que le testeur doit savoir de plus."""
    if geste == "attendre":
        time.sleep(min(valeurs[0], ATTENTE_MAX))
    if conf["plateforme"] == "web":
        retour = agir_web(conf, "voir" if geste == "attendre" else geste, valeurs, destination)
        return retour["largeur"], retour.get("remarques", []), retour.get("elements", [])
    if geste in ("toucher", "glisser"):
        valeurs = vers_ecran(conf, valeurs)
    agir_android(conf, geste, valeurs)
    if geste != "voir":
        time.sleep(REPOS_APRES_GESTE)
    photographier_android(conf, destination)
    return conf["largeur_capture"], remarques_android(conf), []


def consigner(numero, geste, valeurs, commentaire, capture, erreur):
    ligne = {"n": numero, "heure": datetime.now().isoformat(timespec="seconds"),
             "geste": geste, "valeurs": valeurs, "commentaire": commentaire,
             "capture": capture, "erreur": erreur}
    with JOURNAL.open("a", encoding="utf-8") as journal:
        journal.write(json.dumps(ligne, ensure_ascii=False) + "\n")


def principal():
    geste, valeurs, commentaire = lire_appel(sys.argv[1:])
    conf = lire_configuration()
    if conf["plateforme"] == "android" and geste == "taper" and not valeurs[0].isascii():
        # `input text` d'Android ne sait pas taper une lettre accentuée.
        refuser("« taper » n'écrit ici que des lettres sans accent. C'est une limite du pilote, "
                "pas de l'app")
    numero = numero_suivant()
    if numero > conf.get("actions_max", numero):
        refuser(f"tu as fait tes {conf['actions_max']} gestes. Rends ton rapport maintenant")
    capture = f"captures/{numero:03d}.jpg"
    try:
        largeur, remarques, elements = jouer(conf, geste, valeurs, ICI / capture)
    except (RuntimeError, subprocess.SubprocessError, OSError) as panne:
        # La panne entre au journal : un geste qui n'a rien fait reste un fait du parcours.
        consigner(numero, geste, valeurs, commentaire, None, str(panne))
        print(f"Le geste n'a pas pu se faire : {panne}")
        return 1
    consigner(numero, geste, valeurs, commentaire, capture, None)
    print(f"Geste {numero} fait. Capture : {capture} ({largeur} px de large).")
    print("Ouvre-la avant le geste suivant, tes coordonnées se lisent sur elle.")
    for remarque in remarques:
        print(f"Remarque : {remarque}")
    if elements:
        print("Éléments qu'on peut toucher, avec leur centre :")
        for element in elements:
            print(f"  ({element['x']}, {element['y']}) {element['texte']}")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
