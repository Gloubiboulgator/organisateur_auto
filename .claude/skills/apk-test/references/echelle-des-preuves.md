# L'échelle des preuves d'un parcours

> Ce fichier fait foi sur ce qu'un run vert prouve, et sur ce qu'il ne prouve pas. Il vient du
> cadrage d'un projet équipé, où chaque niveau a été payé par un run déclaré vert à tort.

Sans cette échelle, « publier si tout est vert » ne veut rien dire. Les preuves se rangent par
ce qu'elles couvrent réellement. Une règle les traverse toutes : **le doute vaut échec**.

## Niveau 0, la pastille du job. Elle ne prouve rien.

Le projet d'origine en a deux démonstrations. Au run 31431701893, le jeton de test manquait et
Android a refusé la commande. Aucun test n'a tourné. Le contrôle ne cherchait que des marques
d'échec, il a donc conclu au succès.

Au run 31471955570, JUnit affichait `OK (n tests)` et les
images étaient là. L'app n'avait jamais pris l'écran.

## Niveau 1, la preuve positive mécanique

C'est `verdict()` dans `scripts/parcours-emulateur.sh`. Quatre exigences, dans l'ordre.

- Une sortie non vide.
- L'absence de marques d'échec, `FAILURES!!!`, `Process crashed`, `INSTRUMENTATION_CODE: 0`.
- La présence du résumé `OK (n tests)`.
- La ligne `Displayed <paquet>/<activité>` du journal système, écrite par Android et pas par
  nous. C'est la preuve la plus directe que l'app a pris l'écran.

S'y ajoutent trois contrôles de la même nature.

- **Chaque nom photographié a son fichier.** Les noms se dérivent du fichier Kotlin du parcours
  par `scripts/captures-attendues.py`, boucles dépliées. Aucun nombre ne s'écrit à la main : il
  se périmerait au premier écran ajouté. Un test ignoré, ou sauté faute de jeton, n'exige rien.
  Une extraction muette fait échouer, jamais passer.
- **Le film se décode.** `film_lisible()` lit sa durée par `ffprobe`. Un film absent ne rougit
  qu'avec un jeton de test, seul cas où le parcours devait tourner. `ffprobe` absent rougit
  aussi : un contrôle qui saute en silence est un contrôle qu'on croit avoir.
- **Chaque écran modifié est photographié.** `scripts/verifier-captures.sh` compare les écrans
  touchés depuis le dernier build publié aux captures produites.

## Niveau 1 bis, la machine qui a produit les images était-elle vivante

C'est `sante_machine()` dans le même script. Le run 31967863064 a montré le trou. Toutes les
preuves ci-dessus passaient. Pendant ce temps, l'Android sous l'app se faisait tuer deux fois.

Le journal l'écrit noir sur blanc : `ANR in com.android.systemui`, une charge de 45,83 sur deux
cœurs, la mort des fenêtres `StatusBar` et `NavigationBar`.

Les images en portent la marque. Plus aucune barre d'état, une bande noire en haut d'un écran,
une autre en bas du film, un bandeau « Viewing full screen ». Autant de défauts d'interface
**qui ne sont pas ceux de l'app**. Une session d'analyse allait pourtant les lui imputer.

La mort d'une fenêtre système fait donc rougir, un ANR aussi, le nôtre comme celui de SystemUI.
Une machine seulement lente avertit : ses images restent vraies, elles partent seulement trop
tôt. Le seuil de l'avertissement est un réglage, posé faute d'observation de ce qui est normal.

**Le juge lit ce niveau avant les images.** Sinon il juge l'app sur des écrans qu'un Android
agonisant a dessinés. L'ordre n'est pas cosmétique : une bande noire se raconte aussi bien
comme un défaut de mise en page que comme une barre système morte.

## Niveau 2, ce qui a réellement été exécuté

Un vert doit déclarer ce qu'il n'a pas fait. Une suite qui saute des fichiers faute d'un outil
peut n'avoir jamais testé ce qu'elle prétend couvrir. Le skill ne mécanise pas ce niveau. Le
relevé de `scripts/rapatrier-parcours.sh` en tient lieu, en nommant ce qui a été rejoué et ce
qui a été sauté.

## Niveau 3, le jugement sur ce qui est montré

Aucune preuve ci-dessus ne regarde le contenu d'une image, ni le film. Le run 31471955570 les
passait toutes. Ce niveau demande un lecteur, et c'est l'objet de
[`grille-de-jugement.md`](grille-de-jugement.md).

Il s'exerce sur les captures, puis sur les
images tirées du film. Le bandeau système du run 31509968766 vivait entre deux captures,
invisible sur toutes les photos et visible sur le film seul.

## Ce que chaque script prouve, et ne prouve pas

| Script | Prouve | Ne prouve pas |
|---|---|---|
| `parcours-emulateur.sh --verdict` | des tests ont tourné et fini, l'activité a été affichée | que l'écran affiché est le bon |
| `parcours-emulateur.sh --sante` | aucune fenêtre système morte, aucun ANR | que les images sont lisibles |
| `parcours-emulateur.sh --film` | le film a une durée décodable | que le film montre l'app |
| `captures-attendues.py` | chaque nom attendu a un fichier | que le fichier montre l'écran nommé |
| `verifier-captures.sh` | chaque écran modifié a une capture portant son nom | que la capture est juste |
| `rapatrier-parcours.sh` | les trois contrôles rejoués sur l'artefact, le film découpé | rien de plus, il prépare le jugement |
