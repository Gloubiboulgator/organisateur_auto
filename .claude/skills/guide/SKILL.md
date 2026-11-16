---
name: guide
description: >
  Crée le guide HTML du projet, une page qui l'apprend à un débutant complet, en un quart
  d'heure environ. Chaque mécanique y est expliquée avec un exemple concret, puis montrée, avec
  des interactions qui répondent au lecteur. Les explications sont rédigées à part, les faits
  sont lus dans le code à chaque génération. Pose aussi le backlog du guide, où se notent les
  relectures à faire, jamais urgentes. S'invoque UNIQUEMENT sur commande explicite `/guide`, en
  général quand l'item de roadmap « Créer le guide HTML du projet » arrive en tête. Ne se
  déclenche jamais tout seul.
---

# /guide, le guide HTML qui apprend le projet

## Pourquoi ce skill existe

Le premier guide de ce genre est né dans structure_projet. Trois versions ont été refusées avant
la bonne. La première empilait des fichiers en vrac, la deuxième les rangeait mieux, la
troisième animait tout sans rien expliquer. Le verdict de l'admin tenait en une phrase : « je
comprends rien du tout au site ».

La quatrième a tenu un mois, puis l'admin l'a jugée trop abscone, le 2026-10-21. Elle parlait à
qui connaît déjà le métier, et recopiait des textes entiers. Le guide a été réécrit pour un
débutant complet, en six étapes.

Ce qui marche tient en quatre idées. Le guide **apprend** au lieu d'afficher, à quelqu'un qui
part de **zéro**. Ce qu'il **raconte** est rédigé, ce qu'il **affirme** est lu dans le code.
Et rien n'y bouge sans un geste du lecteur.

## Le lecteur

Un débutant complet. Il ne connaît ni le projet, ni son métier, ni son vocabulaire. Il doit
comprendre le projet à la grosse maille en un quart d'heure environ.

## Ce que le skill produit

- Un **générateur**, qui écrit `guide.html` à la racine du dépôt.
- Le **guide généré**, `guide.html`, commité à sa première génération.
- Un fichier d'**explications rédigées**, sous `guide/`.
- Le **backlog du guide**, `guide/backlog.md`, posé depuis
  [`references/gabarit-backlog.md`](references/gabarit-backlog.md).
- Une entrée au journal, et l'item de roadmap retiré.

## Les étapes

### 1. L'inventaire

Lister ce qu'un débutant doit comprendre, produit et méthode. Pour chaque mécanique, noter à
quoi elle sert, quand elle agit, ce qu'elle arrête et pourquoi elle existe. Noter aussi
l'exemple concret qui la fait comprendre, et l'incident réel qui l'illustre. L'inventaire se
montre à l'admin avant la suite.

### 2. La structure

Le skill propose six étapes, qu'un projet peut renommer.

1. **Le problème** que le projet résout, raconté par un incident réel.
2. **L'idée** qui le résout, en quelques principes.
3. **Les pièces** qui la mettent en œuvre, chacune avec son moment et un exemple.
4. **Une journée type**, une demande suivie de bout en bout, où chaque pièce intervient.
5. **L'installation**, la commande et ce qu'elle fait.
6. **Une annexe à la carte**, avec les listes complètes, repliées.

### 3. La maquette

`CLAUDE.md` l'exige pour tout changement visible. Une maquette des deux premières étapes, déjà
habillée, se valide sur le ton avant le générateur. Elle montre des cas réels, dont une
mécanique sans explication.

### 4. Le partage entre rédigé et lu

- **Rédigé**, dans `guide/` : les textes des étapes, les gloses, les exemples, les incidents.
- **Lu dans le dépôt** à chaque génération : déclencheurs, seuils, commandes, effectifs,
  titres de sections. Jamais recopié dans le rédigé.
- **Une citation** du rédigé se vérifie dans son fichier source. Introuvable, elle est écartée.
- **Une mécanique sans explication** s'affiche quand même, avec son en-tête et l'étiquette
  « pas encore expliqué ». Le générateur le dit, sans échouer.

### 5. L'écriture

- **Chaque mot technique** porte une glose courte à sa première apparition.
- **Chaque idée** porte un exemple concret.
- **Les listes complètes** vont dans l'annexe, repliées. Le fil de lecture n'en montre aucune.
- **Aucun texte du dépôt n'est recopié en entier.** Un lien le remplace.

### 6. La page

- Chaque mécanique est **expliquée, puis montrée** : une démonstration qu'on manipule, un pas à
  pas qu'on clique, un simulateur. Jamais un fichier brut affiché en bloc.
- **Rien ne bouge tout seul.** Une animation répond au défilement, au survol ou au clic. Le
  texte sous la souris ne bouge jamais.
- La page tient à 400 pixels de large, en clair comme en sombre, et sans script.
- **Une seule présentation**, au choix du projet. Les dix présentations du guide de
  structure_projet lui sont propres.

### 7. Le backlog et son rappel

Poser `guide/backlog.md` depuis le gabarit. Remplir sa section « Ce que le guide explique »,
un motif de chemin par ligne. `scripts/rappel-guide.py` la lit au commit. Il nomme alors ce que
le commit touche et que le guide explique, sans rien bloquer.

### 8. La livraison

Le skill génère le guide une première fois et le commite, `guide.html` à la racine. Ensuite,
rien ne le régénère tout seul, ni workflow ni hook.

Un changement qui touche une mécanique expliquée atterrit dans le backlog du guide. Le guide se
régénère et se recommite quand on traite une ligne du backlog, dans le même commit. Un conflit
de fusion sur `guide.html` se résout en le régénérant, jamais à la main.

## La règle de mise à jour

Elle vit dans [`docs/systeme-documentaire.md`](../../../docs/systeme-documentaire.md), section
« Le guide HTML et sa relecture ». En bref, une relecture après chaque changement touché, une
ligne au backlog si besoin, et jamais d'urgence.

## L'exemple de référence

Le guide de structure_projet applique les étapes 1 à 7. Son générateur est `generer-guide.py`,
à la racine du dépôt du noyau, avec `guide/contenu.py` pour le rédigé. Sa spécification vit
dans ce même dépôt, au dossier des specs. Si ce dépôt est voisin du projet, s'en inspirer vaut
mieux que repartir de zéro.

Son rédigé ne cite aucun fichier mot pour mot. La vérification des citations de l'étape 4 n'y a
donc rien à lire, et son générateur vérifie seulement que chaque fichier source nommé existe
encore.

Sa livraison ne suit pas l'étape 8. Un workflow le régénère sur la branche principale, et sa
sortie par défaut est un aperçu ignoré. Un projet n'en reprend pas ce point.
