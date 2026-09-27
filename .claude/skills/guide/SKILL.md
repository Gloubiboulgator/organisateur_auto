---
name: guide
description: >
  Crée le guide HTML du projet, une page qui apprend comment il fonctionne à qui le découvre.
  Chaque mécanique y est expliquée, puis montrée, avec des interactions qui répondent au
  lecteur. Les explications sont rédigées à part, les faits sont lus dans le code à chaque
  génération. Pose aussi le backlog du guide, où se notent les relectures à faire, jamais
  urgentes. S'invoque UNIQUEMENT sur commande explicite `/guide`, en général quand l'item de
  roadmap « Créer le guide HTML du projet » arrive en tête. Ne se déclenche jamais tout seul.
---

# /guide, le guide HTML qui apprend le projet

## Pourquoi ce skill existe

Le premier guide de ce genre est né dans structure_projet. Trois versions ont été refusées avant
la bonne. La première empilait des fichiers en vrac, la deuxième les rangeait mieux, la
troisième animait tout sans rien expliquer. Le verdict de l'admin tenait en une phrase : « je
comprends rien du tout au site ».

Ce qui a marché ensuite tient en trois idées. Le guide **apprend** au lieu d'afficher. Ce qu'il
**raconte** est rédigé, ce qu'il **affirme** est lu dans le code. Et rien n'y bouge sans un
geste du lecteur.

## Ce que le skill produit

- Un **générateur**, qui écrit `guide-apercu.html` par défaut, fichier ignoré par git.
- Un fichier d'**explications rédigées**, sous `guide/`.
- Le **backlog du guide**, `guide/backlog.md`, posé depuis
  [`references/gabarit-backlog.md`](references/gabarit-backlog.md).
- Une entrée au journal, et l'item de roadmap retiré.

## Les étapes

### 1. L'inventaire

Lister ce qu'un nouveau venu doit comprendre, produit et méthode. Pour chaque mécanique, noter
à quoi elle sert, quand elle agit, ce qu'elle arrête et pourquoi elle existe. L'inventaire se
montre à l'admin avant la suite.

### 2. La maquette

`CLAUDE.md` l'exige pour tout changement visible. Une maquette des deux premiers chapitres se
valide avant le générateur. Elle montre des cas réels, dont une mécanique sans explication.

### 3. Le partage entre rédigé et lu

- **Rédigé**, dans `guide/` : ce que la mécanique repère, son incident, son pourquoi.
- **Lu dans le dépôt** à chaque génération : déclencheurs, seuils, commandes, effectifs,
  titres de sections. Jamais recopié dans le rédigé.
- **Une citation** du rédigé se vérifie dans son fichier source. Introuvable, elle est écartée.
- **Une mécanique sans explication** s'affiche quand même, avec son en-tête et l'étiquette
  « pas encore expliqué ». Le générateur le dit, sans échouer.

### 4. La page

- Chaque mécanique est **expliquée, puis montrée** : une démonstration qu'on manipule, un pas à
  pas qu'on clique, un simulateur. Jamais un fichier brut affiché en bloc.
- **Rien ne bouge tout seul.** Une animation répond au défilement, au survol ou au clic.
- La page tient à 400 pixels de large, en clair comme en sombre, et sans script.

### 5. Le backlog et son rappel

Poser `guide/backlog.md` depuis le gabarit. Remplir sa section « Ce que le guide explique »,
un motif de chemin par ligne. `scripts/rappel-guide.py` la lit au commit. Il nomme alors ce que
le commit touche et que le guide explique, sans rien bloquer.

### 6. La livraison

Une branche de travail ne commite jamais le guide généré, seulement l'aperçu ignoré. Deux
branches qui le régénèrent se heurteraient à chaque fusion. Le projet choisit ensuite qui le
publie. Un workflow sur la branche principale, ou personne.

## La règle de mise à jour

Elle vit dans [`docs/systeme-documentaire.md`](../../../docs/systeme-documentaire.md), section
« Le guide HTML et sa relecture ». En bref, une relecture après chaque changement touché, une
ligne au backlog si besoin, et jamais d'urgence.

## L'exemple de référence

Le guide de structure_projet applique tout ce qui précède. Son générateur est `generer-guide.py`,
à la racine du dépôt du noyau, avec `guide/contenu.py` pour le rédigé. Si ce dépôt est
voisin du projet, s'en inspirer vaut mieux que repartir de zéro.
