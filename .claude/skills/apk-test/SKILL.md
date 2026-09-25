---
name: apk-test
description: >
  Pose dans un projet Android le test de l'app par émulateur, tel qu'un projet équipé l'a
  durci en une vingtaine de runs perdus. Un parcours filmé dans un téléphone virtuel de la CI,
  une capture par écran, et une échelle de preuves qui refuse tout vert sans preuve positive.
  Six étapes. Préparer le projet, écrire le parcours, brancher le job, rapatrier un run, juger
  le parcours sur ses images, et éprouver le juge sur deux runs connus. Le jugement se rend en
  session, sur les captures et sur les images tirées du film.
  S'invoque UNIQUEMENT sur commande explicite `/apk-test`. Ne se déclenche jamais tout seul.
---

# Apk-test

## But

Donner l'app à voir avant de la livrer. Des tests qui lisent l'app comme du texte vérifient
qu'une ligne est écrite, jamais qu'elle produit son effet. Chez le projet d'origine, un
correctif clavier est parti vert et inerte, et des cafouillages de navigation n'ont été vus
qu'une fois l'app installée.

Le skill pose trois choses, et une méthode pour les lire.

- Un **parcours** UiAutomator qui filme la navigation et photographie chaque écran.
- Un **job** de CI qui joue ce parcours dans un Android virtuel et publie l'artefact.
- Des **scripts** qui refusent un run sans preuve positive, et préparent le jugement.

La règle qui traverse tout : **le doute vaut échec**. Un run vert qui ne prouve rien vaut
moins qu'un run rouge. Le projet d'origine en a payé trois, dont l'échelle de
[`references/echelle-des-preuves.md`](references/echelle-des-preuves.md) garde la trace.

## Quand il s'exécute

Sur commande explicite seule. Trois usages, selon l'état du projet.

- **Le projet n'a rien.** Les étapes 1 à 3 posent le dispositif. Puis l'étape 6, une fois.
- **Le projet a un run à lire.** Les étapes 4 et 5, sur le numéro du run.
- **Le projet doute de son juge.** L'étape 6 seule.

Chaque étape dit ce qu'elle attend de l'admin avant de commencer. Un jeton de test, un numéro
de run, une maquette. Rien ne se devine.

## Ce qu'il n'est pas

**Il ne compile pas l'app.** Le job attend un artefact produit par un job de compilation du
projet, avec l'app et son robot de test. Ce job-là appartient au projet.

**Il ne lance pas d'émulateur sur la machine locale.** Tout tourne dans la CI. La machine
locale télécharge l'artefact, et juge.

**Il ne rejoue pas le réseau.** Une app qui parle à un site qui bloque les machines de CI
verra ce mur sur ses captures. C'est un fait à lire, pas à contourner ici.

**Il n'écrit rien dans le projet de lui-même aux étapes 4, 5 et 6.** Le rapport se rend en
session. Les étapes 1 à 3 écrivent, et disent chaque fichier qu'elles touchent.

## Étape 1. Préparer le projet

**Demander d'abord** ce que le skill ne peut pas deviner, en questions courtes.

- Le paquet de l'app.
- Le nom de son activité principale, dans la forme d'Android, `.MainActivity`.
- Le chemin du dossier `androidTest`.
- Les motifs des fichiers d'écran.
- Le nom de l'artefact que le job publiera.

**Écrire `apk-test.env`** à la racine du projet, avec les clés requises et celles que l'admin
a nommées. La table des clés et leurs défauts vit dans
[`references/reglages-et-fiches.md`](references/reglages-et-fiches.md). Aucune valeur par
défaut ne désigne un projet réel, et une clé requise absente arrête les scripts en la nommant.

**Dicter la fiche d'observation.** Le script du parcours repose sur une supposition, l'atome
`moov` écrit à la fermeture de l'enregistreur. Le noyau ne peut pas la ficher lui-même. La
fiche, prête à coller, est dans la même référence. Elle va dans le fichier d'observations du
projet, sous sa clé, avec son canari.

**Nommer l'outillage attendu**, sans l'installer. La CI aura besoin de Java 17, du SDK
Android et de `ffmpeg`, que le gabarit du job installe. La machine locale aura besoin de `gh`
et de `ffmpeg` pour l'étape 4. Un outil absent se signale, il ne se contourne pas.

## Étape 2. Écrire le parcours

**Copier** [`references/ParcoursVisuelTest.kt`](references/ParcoursVisuelTest.kt) dans le
dossier `androidTest` du projet, sous le paquet de l'app.

**Adapter** ce que [`references/gabarit-parcours-kotlin.md`](references/gabarit-parcours-kotlin.md)
liste comme adaptable, et rien d'autre. Le paquet, la ligne qui écrit le jeton, les activités,
les identifiants de vues, les libellés des boîtes à écarter, les noms de captures.

**Respecter le contrat du DSL.** `photographier("littéral")`, `repeat(n)` déplié, `${i}` dans
un littéral. Toute autre forme fait rougir la chaîne. Le seuil de captures se dérive de ce
fichier, et deviner rouvrirait le plancher à zéro.

**Poser l'étiquette** `@suppose` suivie de la clé de la fiche, au-dessus de l'arrêt de
l'enregistreur dans le `finally`. C'est un fichier du projet, son contrôle des étiquettes la
rapprochera de la fiche dictée à l'étape 1.

**Déclarer les dépendances** de test dans le Gradle du projet : `uiautomator`, `runner`,
`rules` d'AndroidX Test, et le `testInstrumentationRunner`. Le skill nomme les trois, le
projet choisit les versions.

**Le geste qui exerce ce point** : le run de l'étape 3, dont l'artefact porte une capture par
nom du parcours. Sans run, le parcours n'est pas livré.

## Étape 3. Brancher le job

**Copier** le bloc de [`references/job-tester.yml`](references/job-tester.yml) sous `jobs:` du
workflow, en suivant [`references/gabarit-job-workflow.md`](references/gabarit-job-workflow.md).
Adapter `needs`, le nom de l'artefact des paquets, le nom de l'artefact publié.

**Ne pas toucher** à ce que le gabarit marque comme payé par un run. Le bloc `script:` sur une
ligne, `fetch-depth: 0`, la cible `default`, la place disque, l'étape `ffmpeg` séparée. Le
pourquoi de chacun vit dans
[`references/pieges-emulateur-ci.md`](references/pieges-emulateur-ci.md).

**Demander le secret** `TEST_APP_TOKEN` à l'admin, le jeton d'un compte de test dédié, jamais le
sien. Sans lui, l'app reste à l'écran d'accueil et l'artefact ne porte qu'une image. Le skill
ne pose jamais un secret lui-même.

**Annoncer le symptôme.** À la livraison, une ligne : si ma prémisse est fausse, voilà ce que
tu verras. Par exemple, un artefact d'une seule image alors que le jeton est posé.

## Étape 4. Rapatrier un run

**Demander le numéro du run**, identifiant ou compteur affiché, et le dossier de destination
si l'admin en veut un autre que `./parcours-<run>`. **Demander aussi si ce run portait le jeton
de test.** L'artefact ne le dit pas. Le journal du jeton est celui du job, pas celui de
l'appareil. Sans jeton, `Assume` a sauté le parcours filmé, et l'absence de film est normale.

**Lancer** `scripts/rapatrier-parcours.sh <run>`, avec `--sans-jeton` si le run n'en avait pas.
Il télécharge l'artefact, rejoue les trois contrôles sur les fichiers rapatriés, santé de la
machine, verdict, film, dans cet ordre. Puis il découpe le film en images fixes, une par
changement d'écran plus une toutes les cinq secondes, et imprime un relevé.

**Lire le relevé avant tout.** Une machine malade arrête l'étape 5, et le rapport dira « non
jugé ». La réponse est alors de relancer le run, pas de corriger l'app. Un verdict rouge se
rapporte en premier.

## Étape 5. Juger le parcours

**Suivre** [`references/grille-de-jugement.md`](references/grille-de-jugement.md), dans son
ordre.

- D'abord le relevé.
- Puis chaque capture nommée, avec l'outil de lecture d'images de la session.
- Puis les images du film, dans l'ordre du temps.
- Enfin la maquette, si le projet en a une.

**Chercher ce qui vit entre deux captures.** Au run 31509968766, un bandeau système a couvert
le tiers haut de l'écran pendant quinze secondes. Invisible sur toutes les photos, visible sur
le film seul. C'est pour lui que le film est découpé.

**Rendre le rapport** de
[`references/gabarit-rapport-parcours.md`](references/gabarit-rapport-parcours.md), en six
blocs.

- Le verdict en une ligne.
- La santé.
- Les trois verdicts mécaniques.
- Les défauts écran par écran, avec le nom du fichier.
- Ce qui n'a pas pu être jugé.
- Le symptôme si la lecture est fausse.

**Une image que le juge ne sait pas lire se rapporte comme telle.** Jamais comme un succès.

## Étape 6. Éprouver le juge

Un juge qui accepte tout ne sert à rien. Un juge qui refuse tout finit contourné. Avant de lui
faire confiance, une fois par projet, on lui soumet des runs de réponse connue.

1. **Rapatrier un run mauvais connu** et le juger. Il doit être refusé, pour le bon motif.
2. **Rapatrier un run bon connu** et le juger. Il doit être accepté.
3. **Abîmer le bon exprès.** Retirer une capture du dossier, rejuger. Le juge doit le voir.
4. **Noter les trois résultats** dans le journal du projet, avec les numéros de run.

Le projet d'origine a ses deux runs : le 31471955570, mauvais, l'app n'a jamais pris l'écran,
et le 31509968766, bon. Un projet neuf n'a pas de run connu au départ. Son premier run réel,
relu à la main par l'admin, en devient un.

Cette étape se joue sur la machine de l'admin, celle qui a `gh` et l'accès au dépôt. Une
session sans ces outils la décrit, et s'arrête là.
