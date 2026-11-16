---
name: passe-parcours
description: >
  Mène la passe parcours de la règle F5 avec des testeurs qui ne savent rien du projet. Un
  agent Opus modélise d'abord tout le parcours utilisateur, en un logigramme publié que l'admin
  valide. Sur son go, des testeurs neufs utilisent l'app sur un téléphone virtuel ou dans un
  navigateur. Chacun ne connaît que la fiche de l'app, commente chaque geste et le photographie.
  Il dit ce qu'il comprend, et ce qui est mal expliqué, mal fait ou pas logique. La session
  rend une synthèse publiée, posée sur le logigramme. Argument, le nombre de testeurs.
  S'invoque UNIQUEMENT sur commande explicite `/passe-parcours`. Ne se déclenche jamais tout seul.
---

# Passe parcours

## But

Voir l'app avec les yeux de quelqu'un qui la découvre. Les tests disent que l'app marche. Ils ne
disent jamais qu'elle se comprend, ni qu'on trouve le bouton qui mène à la suite.

La règle F5 du noyau veut cette passe après chaque lot visible, à la main. Ce skill la mène
sans l'admin, avec plusieurs testeurs à la fois. Il ne remplace pas un humain, il le précède.

> Incident fondateur. Un sous-agent ordinaire, sondé le 2026-11-16, recevait le chemin du dépôt,
> son `git status`, ses derniers commits et ses fichiers d'instructions. Lancé dans le dossier du
> jeu, il aurait lu le nom du projet et l'historique avant son premier geste. Un testeur qui
> connaît le projet ne découvre rien. Les testeurs naissent donc hors de la session, enfermés.

## Quand il s'exécute

Sur commande explicite seule. `/passe-parcours 4` lance quatre testeurs par plateforme. Sans
nombre, il en lance trois.

Quatre phases, et deux arrêts qui attendent l'admin.

1. La modélisation du parcours, puis **l'arrêt de validation**.
2. Les réglages et la fiche, puis **le go**.
3. Les testeurs.
4. La synthèse. Plus aucun arrêt entre le go et le rendu.

## Ce qu'il n'est pas

**Il ne compile pas l'app.** Il prend l'APK que le projet a construit, ou l'adresse d'un site
qui tourne déjà. Les construire appartient au projet.

**Il ne teste jamais la production.** Un testeur vote, s'inscrit, signale, efface. Ses gestes
partent vers un serveur local ou de recette, avec des comptes de test. Une adresse de
production se refuse, même si l'admin la donne par mégarde.

**Il n'écrit rien dans le projet**, sauf son dossier de résultats `passe-parcours/<horodatage>/`.
Il dit à l'admin de l'ignorer dans git s'il ne l'est pas.

**Il ne juge pas à la place d'un humain.** Un modèle lit tout, ne se lasse jamais et devine
bien. Il sous-estime donc la confusion d'une vraie personne pressée. Le rendu le rappelle.

## Phase 1. Modéliser le parcours

**Lancer un sous-agent** de type `general-purpose`, modèle `opus`, effort `medium`. Ce réglage
est la demande de l'admin qui a fait naître le skill. Sa consigne est
[`references/consigne-modelisation.md`](references/consigne-modelisation.md), tout entière.

Il lit le projet, specs et code des écrans. Il rend le parcours complet, dans la forme que fixe
sa consigne. Chaque écran, chaque geste qui en sort, chaque branche, premier lancement, retour,
erreur, réglages.

**Rendre la page** par [`scripts/rendre_parcours.py`](scripts/rendre_parcours.py), puis la
publier en artefact. Elle ouvre sur le logigramme d'un seul tenant. Par défaut, il montre le
chemin le plus court vers chaque écran, avec son geste.

Des filtres montrent tous les liens, masquent des sections, ou isolent les voisins d'un écran.
Plus bas, chaque section a son logigramme et le tableau de ses gestes. Les écarts ferment la
page, rangés par sorte.

> Incident fondateur. Le 2026-11-16, le premier rendu dessinait deux cent cinquante gestes
> d'un coup, libellés compris. L'admin l'a jugé illisible, deux fois. Un dessin de cette taille
> ne se démêle pas, il se filtre.

**Garder le parcours** dans `passe-parcours/<horodatage>/parcours.json`. La synthèse posera les
chemins des testeurs dessus.

**Arrêt.** L'admin corrige le parcours, ou le valide. Une correction repasse par le sous-agent,
puis par une nouvelle publication au même lien.

## Phase 2. Les réglages et la fiche

**La fiche est le seul savoir du testeur.** Une vraie personne la lit avant d'installer.
C'est la fiche du magasin d'applis, ou la page d'accueil d'un site. Le skill la demande à
l'admin, telle quelle.

Il peut proposer un texte que le projet possède déjà. Il ne l'écrit jamais lui-même, car une
fiche tirée du code apprendrait au testeur ce qu'un inconnu ignore.

**Trouver soi-même les réglages techniques**, sans les demander.

- L'APK, dans les sorties de compilation du projet.
- Le nom du paquet, dans sa configuration Android.
- Le téléphone virtuel, par `emulator -list-avds`.
- L'adresse de départ, dans la configuration de lancement du projet ou son guide.

Ce qui reste introuvable se demande. Dès deux questions à l'admin, fiche comprise, elles partent
dans un questionnaire, selon
[`docs/ton-des-echanges.md`](../../../docs/ton-des-echanges.md).

**La plateforme suit le projet.** Une app Android et un site se testent tous les deux, chacun
avec son lot de testeurs. Les testeurs Android passent un par un, et ceux du web trois à la
fois. Trois émulateurs ensemble ont saturé le PC de l'admin le 2026-11-16. Les testeurs ont pris
les fenêtres système et les lenteurs pour des défauts de l'app.

**Les réglages tranchés par le skill**, que l'admin peut contester.

- Le modèle des testeurs, `sonnet`, effort `medium`. Opus coûte plusieurs fois plus par capture.
- Quarante gestes au plus par testeur, et deux dollars au plus, par `--budget-max`.
- Pas de tempéraments. L'option `--temperaments` en donne un à chaque testeur, pris dans
  [`references/temperaments.txt`](references/temperaments.txt). Elle varie la façon d'essayer,
  jamais ce que le testeur sait.

**Nommer l'outillage**, sans l'installer. Un outil absent arrête le lanceur, qui le nomme.

- Toujours, `ffmpeg` et le binaire `claude`. Celui de l'appli de bureau se trouve seul. Un autre
  se désigne par `PASSE_PARCOURS_CLAUDE`.
- Pour Android, le SDK avec `adb`, l'émulateur et un téléphone virtuel. `ANDROID_HOME` le
  désigne s'il n'est pas sous `~/Android/Sdk`.
- Pour le web, Node et le paquet `playwright`, que `--node-path` désigne.

**Le go.** Rien ne part avant. Après lui, plus aucune question jusqu'au rendu.

## Phase 3. Les testeurs

**Écrire la fiche** dans le dossier de résultats, puis **lancer**
[`scripts/lancer_testeurs.py`](scripts/lancer_testeurs.py) en arrière-plan, une fois par
plateforme, chacune dans son sous-dossier neuf, `android/` ou `web/`. Son en-tête donne la
commande exacte. La session attend la notification de fin,
sans sonder.

Chaque testeur vit ainsi.

- Un appareil neuf. Un émulateur en lecture seule, l'app installée et ses données effacées. Ou
  un Chromium au profil vide.
- Une session `claude -p` née dans un dossier neutre, sans réglages, sans mémoire, sans
  serveurs d'outils. Le mode `dontAsk` refuse tout ce qui n'est pas permis.
- Deux droits. Lancer `./piloter`, et lire son propre dossier, donc ses captures.
- La consigne de [`references/consigne-testeur.md`](references/consigne-testeur.md) et la fiche,
  rien d'autre.

[`scripts/piloter.py`](scripts/piloter.py) refuse un geste sans commentaire, et photographie
après chaque geste. Le testeur rend son rapport dans la forme de
[`references/rapport-testeur.schema.json`](references/rapport-testeur.schema.json).

**Lire la sortie du lanceur avant tout.** Un testeur sans rapport se rapporte comme tel, avec
sa panne. Il ne se relance pas en silence.

## Phase 4. La synthèse

**Suivre** [`references/grille-de-synthese.md`](references/grille-de-synthese.md), dans son
ordre. Les captures s'ouvrent avant toute conclusion, par l'outil de lecture d'images.

**Publier** l'artefact de sortie, dont la grille fixe les blocs. Le logigramme de la phase 1 y
revient, coloré par ce que les testeurs ont atteint, et marqué là où ils ont abandonné. Il se
rend par le même script, avec l'option `--couverture`.

**Rendre en conversation** le verdict en trois lignes, puis le lien. Le reste vit dans la page.

## Ce qu'il faut savoir avant d'y toucher

**L'enfermement fait la valeur du skill.** Un droit ou un mot de plus, et le testeur ne
découvre plus rien. Un nom de projet dans son chemin suffit déjà. Toute modification de
`lancer_testeurs.py` refait donc le sondage de son en-tête. Lire un fichier du projet doit
toujours partir en refus.

**Un refus de permission est un fait à lire.** Le bilan de chaque testeur les liste. Un testeur
qui a tenté de lire le code a cherché une réponse que l'app ne lui donnait pas.

**La webview ne publie aucun élément.** Une app faite d'une page web dans Android n'expose rien
à `uiautomator`. Le testeur vise alors sur la capture, comme un humain. Côté web, le pilote
liste les éléments qu'on peut toucher, y compris les blocs qui montrent le curseur « main ».
