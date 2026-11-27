#!/usr/bin/env python3
"""Ouvre la fenêtre de réglages d'un run de la passe parcours, et en écrit le résultat.

POURQUOI CE FICHIER EXISTE
--------------------------
L'admin veut régler chaque run avant le go, sans retenir d'options en ligne de commande. Demandé
le 2026-11-27, sur une maquette qu'il a validée. Une fenêtre minimaliste s'ouvre donc au
lancement du skill, avec chaque réglage, sa valeur par défaut et une ligne qui l'explique.

CE QU'IL FAIT
-------------
1. Sert la page `references/fenetre-reglages.html` sur 127.0.0.1, à un port libre, et l'ouvre
   dans le navigateur. Les défauts, les bornes et les tempéraments y entrent depuis
   `lancer_testeurs.py`, leur seule source.
2. Attend que l'admin clique sur « Lancer ». La page envoie ses réglages, qui se vérifient comme
   le lanceur les vérifie. Un réglage refusé revient dans la page avec sa raison.
3. Écrit `reglages.json`, dit son chemin, et s'arrête. Sans réponse au bout du délai, il
   s'arrête sans rien écrire.

CE QU'IL N'EST PAS. Il ne lance aucun testeur. Le skill lit le fichier, puis lance le lanceur.

COMMENT ON S'EN SERT, en arrière-plan, la session attendant sa fin :
    python3 regler.py --sortie <resultats>/reglages.json [--nombre 4]
`--nombre` reporte l'argument de `/passe-parcours` dans la page, qui l'ouvre ainsi réglée.
"""
import argparse
import importlib.util
import json
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ICI = Path(__file__).resolve().parent
PAGE = ICI.parent / "references" / "fenetre-reglages.html"
DELAI = 60 * 60


def charger_lanceur():
    """Le lanceur, sans écrire son octet compilé. Le dossier du skill est figé chez un projet
    équipé, et un cache écrit là ferait rougir son contrôle anti-dérive."""
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("lancer_testeurs", ICI / "lancer_testeurs.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def donnees_de_la_page(lanceur, sortie, nombre=None):
    """Les défauts, ce que la page montre en s'ouvrant, les bornes, les tempéraments, et les
    plateformes avec leur nom affiché."""
    initial = dict(lanceur.DEFAUTS)
    if nombre is not None:
        initial["nombre"] = nombre
    return {"defauts": lanceur.DEFAUTS, "initial": initial, "bornes": lanceur.BORNES,
            "choix": lanceur.CHOIX, "temperaments": lanceur.lire_temperaments(),
            "plateformes": [[cle, lanceur.NOMS[cle]] for cle in lanceur.PLATEFORMES],
            "dossier": sortie.parent.name}


def servir(sortie, delai, ouvrir=True, nombre=None):
    """Sert la page jusqu'à des réglages valides. Rend True s'ils sont écrits."""
    lanceur = charger_lanceur()
    donnees = donnees_de_la_page(lanceur, sortie, nombre)
    page = PAGE.read_text(encoding="utf-8").replace(
        "/*DONNEES*/null", json.dumps(donnees, ensure_ascii=False))
    fini = threading.Event()

    class Fenetre(BaseHTTPRequestHandler):
        def log_message(self, *arguments):
            pass

        def repondre(self, code, corps, sorte="application/json"):
            octets = corps.encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", f"{sorte}; charset=utf-8")
            self.send_header("Content-Length", str(len(octets)))
            self.end_headers()
            self.wfile.write(octets)

        def do_GET(self):
            if self.path != "/":
                return self.repondre(404, "{}")
            self.repondre(200, page, "text/html")

        def do_POST(self):
            if self.path != "/enregistrer":
                return self.repondre(404, "{}")
            try:
                longueur = int(self.headers.get("Content-Length", 0))
                donnes = json.loads(self.rfile.read(longueur))
                reglages = lanceur.completer(lanceur.DEFAUTS, donnes)
                fautes = lanceur.verifier_reglages(reglages)
            except (ValueError, KeyError, TypeError, AttributeError) as panne:
                fautes = [f"réglages illisibles ({panne})"]
            if fautes:
                return self.repondre(400, json.dumps({"fautes": fautes}, ensure_ascii=False))
            sortie.parent.mkdir(parents=True, exist_ok=True)
            sortie.write_text(json.dumps(reglages, ensure_ascii=False, indent=2),
                              encoding="utf-8")
            self.repondre(200, json.dumps({"ecrit": True}))
            fini.set()

    serveur = ThreadingHTTPServer(("127.0.0.1", 0), Fenetre)
    adresse = f"http://127.0.0.1:{serveur.server_address[1]}/"
    threading.Thread(target=serveur.serve_forever, daemon=True).start()
    print(f"passe-parcours : la fenêtre de réglages est ouverte sur {adresse}", flush=True)
    if ouvrir:
        webbrowser.open(adresse)
    ecrit = fini.wait(delai)
    serveur.shutdown()
    return ecrit


def principal():
    analyse = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    analyse.add_argument("--sortie", type=Path, required=True)
    analyse.add_argument("--delai", type=int, default=DELAI)
    analyse.add_argument("--sans-navigateur", action="store_true")
    analyse.add_argument("--nombre", type=int)
    args = analyse.parse_args()
    if args.sortie.exists():
        print(f"passe-parcours : {args.sortie} existe déjà, rien n'a été ouvert.", file=sys.stderr)
        return 1
    if not servir(args.sortie, args.delai, not args.sans_navigateur, args.nombre):
        print("passe-parcours : aucun réglage reçu avant la fin du délai, rien n'est écrit.",
              file=sys.stderr)
        return 1
    print(f"passe-parcours : réglages écrits dans {args.sortie}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(principal())
