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

Sur commande explicite seule. `/passe-parcours 4` règle la fenêtre sur quatre testeurs par
plateforme. Sans nombre, elle en propose trois.

Quatre phases, et deux arrêts qui attendent l'admin.

1. La modélisation du parcours, puis **l'arrêt de validation**.
2. La fiche, puis la fenêtre de réglages, dont le bouton « Lancer » vaut **le go**.
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

**La plateforme suit le projet.** Une app Android se teste sur émulateur. Un site se teste
dans les navigateurs cochés, chaque plateforme avec son lot de testeurs. Par défaut, Android
et Chrome. Les neuf plateformes sont décrites dans
[`references/reglages-du-run.md`](references/reglages-du-run.md).

Les testeurs Android passent un par un, et ceux d'un navigateur trois à la fois. Trois émulateurs ensemble ont saturé le PC de l'admin le 2026-11-16. Les testeurs ont pris
les fenêtres système et les lenteurs pour des défauts de l'app.

### La fenêtre de réglages

**Chaque run se règle dans une fenêtre**, demandée par l'admin le 2026-11-27 sur une maquette
qu'il a validée. Une fois la fiche obtenue, **lancer en arrière-plan**
[`scripts/regler.py`](scripts/regler.py), avec `--sortie <resultats>/reglages.json`. Il ouvre
la page dans le navigateur et dit son adresse. La session attend sa fin, sans sonder.

**La page montre chaque réglage**, avec sa valeur par défaut et une ligne qui l'explique. Un
point marque ce qui s'écarte du défaut. Le pied calcule la dépense maximale, nombre de testeurs
fois plafond par testeur.

- Le run. Les plateformes, les testeurs par plateforme, et combien tournent en parallèle.
- Chaque testeur. Le modèle et sa réflexion, les gestes et la dépense au plus, et s'il s'arrête
  une fois servi ou fait le tour de l'app.
- Les tempéraments, aucun, au hasard, ou un par testeur. Ils viennent de
  [`references/temperaments.txt`](references/temperaments.txt), où une ligne de plus fait un
  choix de plus. Ils varient la façon d'essayer, jamais ce que le testeur sait.
- Ce que le testeur perçoit. Le coup d'œil flou et la part lisible, le doigt imprécis, la
  mesure du chargement. Chacun s'éteint ou se règle.
- Comment il se comporte. Les quatre comportements de la section plus bas.

**Les défauts vivent dans `DEFAUTS`**, en tête de
[`scripts/lancer_testeurs.py`](scripts/lancer_testeurs.py), leur seule source. La page les
reçoit de là, avec les bornes de chaque nombre.

Ce sont les réglages d'avant la fenêtre, sauf Chrome à la place de Chromium. `sonnet` en effort
`medium`, quarante gestes et deux dollars au plus. Les trois appuis humains allumés, ni tempérament ni comportement ajouté.

**Un réglage hors bornes se refuse**, dans la page avec sa raison, puis à nouveau par le
lanceur. Le nombre de l'argument `/passe-parcours 4` se reporte dans la page avant qu'elle
parte.

**Si la page ne s'ouvre pas**, la session donne son adresse à l'admin. Sans réponse en une heure,
`regler.py` s'arrête sans rien écrire.

**Nommer l'outillage**, sans l'installer. Un outil absent arrête le lanceur, qui le nomme.

- Toujours, `ffmpeg` avec son `ffprobe`, et le binaire `claude`. Celui de l'appli de bureau se
  trouve seul. Un autre se désigne par `PASSE_PARCOURS_CLAUDE`.
- Pour Android et Chrome Android, le SDK avec `adb`, l'émulateur et un téléphone virtuel.
  Chrome Android veut Chrome installé dans ce téléphone, sinon le lanceur le dit. `ANDROID_HOME` le
  désigne s'il n'est pas sous `~/Android/Sdk`.
- Pour le web, Node et le paquet `playwright`, que `--node-path` désigne. Puis chaque
  navigateur coché, ouvert une fois pour essai. Un absent se nomme avec sa commande, comme
  `npx playwright install firefox`.

**Le go**, c'est le bouton « Lancer » de la fenêtre. Rien ne part avant. Après lui, plus
aucune question jusqu'au rendu.

## Phase 3. Les testeurs

**Écrire la fiche** dans le dossier de résultats, puis **lancer**
[`scripts/lancer_testeurs.py`](scripts/lancer_testeurs.py) en arrière-plan. Il part une fois par
plateforme cochée, chacune dans son sous-dossier neuf, comme `android/` ou `firefox/`.

Il reçoit `--reglages <resultats>/reglages.json`, et son en-tête donne la commande exacte. La
session attend la notification de fin, sans sonder. Chaque sous-dossier garde ses réglages,
tempérament de chaque testeur compris.

Chaque testeur vit ainsi.

- Un appareil neuf. Un émulateur en lecture seule, l'app installée et ses données effacées. Ou
  un navigateur au profil vide, qu'un serveur Node garde ouvert tout le test.
- Une session `claude -p` née dans un dossier neutre, sans réglages, sans mémoire, sans
  serveurs d'outils. Le mode `dontAsk` refuse tout ce qui n'est pas permis.
- Deux droits. Lancer `./piloter`, et lire son propre dossier, donc ses coups d'œil et ses
  lectures.
- La consigne de [`references/consigne-testeur.md`](references/consigne-testeur.md) et la fiche,
  rien d'autre.

[`scripts/piloter.py`](scripts/piloter.py) refuse un geste sans commentaire, et photographie
après chaque geste. Le testeur rend son rapport dans la forme de
[`references/rapport-testeur.schema.json`](references/rapport-testeur.schema.json).

### Le coup d'œil, et lire qui coûte un geste

**Le testeur survole, comme un humain.** Il lisait chaque mot de chaque capture. Une vraie
personne voit les titres, les gros boutons et les couleurs, et ne lit un passage que si elle le
choisit. Décidé par l'admin le 2026-11-18, entre trois façons de le faire.

**Après chaque geste, le testeur reçoit un coup d'œil.** C'est la capture, réduite puis
ré-agrandie à sa taille, donc floue. Les titres, les gros boutons et la forme de l'écran s'y
voient. Le texte courant ne s'y lit pas.

Ses dimensions restent celles d'aujourd'hui, et le testeur y vise comme avant. Le flou est le
niveau moyen, choisi par l'admin le 2026-11-18 sur un écran réel. La capture se réduit à 80 pixels
de large pour 540, puis se ré-agrandit.

**Lire est un geste.** `./piloter lire X1 Y1 X2 Y2 -- "…"` photographie l'écran tel qu'il est,
sans rien toucher. Il rend, nette, la zone entre les deux coins, lus sur le dernier coup d'œil.
Ce geste compte dans le plafond de gestes, a son numéro, sa capture et sa ligne de journal.

- Une zone de plus d'un quart de l'écran se refuse. Le message dit « tu ne peux lire qu'un
  quart de l'écran à la fois ». Sans cette borne, un seul geste rendrait l'écran entier. La
  fenêtre de réglages change cette part, et le message la suit.
- Une zone hors de l'écran, ou vide, se refuse aussi, avec le message d'aide.
- La réponse du pilote dit, après chaque coup d'œil, que le petit texte ne s'y lit pas, et
  rappelle la commande `lire`.

**Les captures nettes restent hors de la portée du testeur.** Le testeur lit tout son dossier.
Les captures nettes s'écrivent donc dans un dossier voisin, que la configuration du pilote
nomme. Le lanceur les rapatrie avec le reste. La synthèse montre à l'admin les captures nettes.

**Côté web, la liste des éléments à toucher disparaît.** Elle donnait le texte de chaque bouton
et de chaque lien, et défaisait le coup d'œil. Le testeur web vise sur l'image, comme
sur une webview Android.

**La synthèse dit ce qui a été lu.** Le fil de chaque testeur marque ses lectures. Un problème
dit si le testeur avait lu la zone qui l'explique.

**Lire la sortie du lanceur avant tout.** Un testeur sans rapport se rapporte comme tel, avec
sa panne. Il ne se relance pas en silence.

### Le doigt, le temps et l'envie

Trois autres écarts entre un testeur et une vraie personne, tranchés par l'admin le 2026-11-19
dans un questionnaire. Chacun des trois a suivi la réponse recommandée.

**Le doigt du testeur n'est plus exact.** Un vrai pouce rate parfois un petit bouton. Un testeur
qui touchait au point près ne voyait donc jamais un bouton trop petit.

- Chaque `toucher` se décale au hasard autour du point visé. L'écart suit une loi normale de
  2 mm d'écart type, bornée à trois écarts types.
- Un `glisser` se décale tout entier, du même écart pour ses deux points. `lire` ne se décale
  jamais.
- Le millimètre se convertit par la densité de l'écran. Sur Android, la densité physique que
  rend `wm density`, jamais une densité forcée. Sur le web, 160 pixels CSS par pouce, la
  densité de référence d'Android. Le décalage se calcule dans `piloter.py` pour les deux.
- Le point touché reste dans l'écran. Le journal porte le point visé et le point touché, dans
  le repère de la capture.
- Le testeur n'en est pas averti. Il voit le résultat sur le coup d'œil suivant.

**Le testeur sait combien de temps l'écran a mis à se poser.** Une vraie personne sent un écran
vide qui dure. Le testeur, lui, réfléchit entre deux gestes, et l'app a toujours fini quand il
regarde.

- Après `toucher`, `glisser`, `taper`, `retour` et `relancer`, le pilote photographie l'écran en
  boucle. Il s'arrête quand l'écran n'a plus bougé depuis une seconde, ou à dix secondes par
  défaut, le réglage `pose.max`.
- Deux photos sont pareilles quand moins de 1 % de leurs points diffèrent, sur une image
  réduite en gris. Un curseur qui clignote ou l'heure qui change ne comptent donc pas.
- La durée court jusqu'au milieu de deux demandes de photo, celle d'avant le dernier
  changement et celle qui le montre. Elle vaut à une demi-seconde près. Le pilote la dit en une
  phrase, « L'écran a mis 2,4 s à se poser. ».
- Sous une demi-seconde, la phrase devient « L'écran s'est posé aussitôt. ». Un écran qui bouge
  encore à dix secondes donne « L'écran bouge encore après 10 s. ».
- Un écran presque uni ne se pose jamais, car c'est l'allure d'un chargement. Presque uni veut
  dire 99 % des points proches de la valeur médiane. Resté tel dix secondes, il donne
  « L'écran est resté vide 10 s. ». Un écran blanc à trois lignes de texte reste sous ce seuil.
  Les quatre rangées du haut et du bas de l'image réduite ne comptent pas, celles des barres
  du système.
- L'attente tourne dans `piloter.py` pour les deux plateformes. Côté web, le pilote Node agit,
  puis rend les photos qu'on lui demande. `retour` et `relancer` n'y attendent pas le
  chargement de la page, que l'attente mesure alors.
- La durée entre au journal, en secondes, ou `"vide"` et `"bouge"` au bout de l'attente.
  `voir`, `lire` et `attendre` photographient sans attendre ni mesurer. Le coup d'œil vient de
  la dernière photo.

> Incident fondateur de la règle de l'écran vide. Le 2026-11-19, une page blanche de deux
> secondes suivait un toucher. L'attente la voyait immobile une seconde, et la disait posée
> « aussitôt ». Avec la règle, la même page mesure 2,2 s pour un chargement de 2 s.

Une app qui ne réagit qu'après plus d'une seconde, sans écran vide entre deux, trompe encore
cette mesure. L'écran d'avant paraît posé « aussitôt ». L'ancienne attente fixe d'une seconde
et demie avait la même limite.

La règle de l'écran vide a une limite de l'autre côté. Un écran posé presque nu, un état vide
avec une icône et une ligne, ressemble à une roue de chargement. Il donne « L'écran est resté
vide 10 s. ». La synthèse le vérifie sur la capture nette avant d'y voir une lenteur.

**Le testeur vient pour ce que promet la fiche.** Une vraie personne arrive avec une envie,
pas pour explorer. Sa consigne lui dit qu'il a installé l'app pour ce que la fiche promet. Il
s'arrête quand il l'a obtenu, ou quand il en a assez.

La consigne n'ajoute rien à la fiche. Un testeur comblé s'arrête donc plus tôt, et voit moins
d'écrans.

**Le pilote ne souffle plus quoi faire.** Sorti de l'app, le testeur lit le constat, sans la
commande qui le ramène. Côté Android, « L'app n'est plus au premier plan. ». Côté web, « Tu as
quitté le site de départ. ». Il connaît `relancer` par l'aide, comme une personne connaît
l'icône de son téléphone.

### Quatre comportements de plus, éteints par défaut

Le testeur peut retoucher un écran qui tarde, faire des fautes de frappe, avoir la mémoire
courte, et être interrompu une fois. Retenus par l'admin le 2026-11-27, chacun s'allume dans la
fenêtre. Leur mécanique et leurs limites vivent dans
[`references/reglages-du-run.md`](references/reglages-du-run.md).

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

**Le testeur vise sur l'image, partout.** Une app faite d'une page web dans Android n'expose rien
à `uiautomator`. Côté web, la liste des éléments à toucher a disparu avec le coup d'œil. Le
testeur vise donc sur la capture, comme un humain.
