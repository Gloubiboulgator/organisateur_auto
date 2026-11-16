# Le gabarit du rapport

> Ce fichier fait foi sur la forme du rapport rendu par [`../SKILL.md`](../SKILL.md). Le fond,
> ce qui se cherche et ce qui ne se supprime jamais, vit là-bas, leur propriétaire.

## La suite, dans l'ordre

Trois départs, chacun en une ligne suivie de son tableau, puis la ligne de choix.

1. 🌿 **A · les branches**, puis le tableau des branches.
2. 🗑️ **B · les fichiers jamais utilisés**, puis le tableau des fichiers.
3. 📐 **C · la spec périmée**, puis le tableau des documents.

Un trait horizontal sépare les départs de la ligne de choix, écrite en italique. *Combine-les,
par exemple « A+C » ou « tout ». Ou dis « détaille B ».*

**La ligne de départ donne les chiffres.** Ce qui part, ce qui change, et ce qui attend un
regard. Elle tient en une ou deux phrases.

**Rien ne s'écrit sous un tableau.** Ni commentaire, ni rappel de ce qu'il montre.

## Les gestes

La dernière colonne de chaque tableau porte un geste, et un seul.

- 🗑️ **supprimer**. Part avec un oui groupé.
- ✏️ **corriger**, ou retirer une section. Part avec un oui groupé.
- 👀 **à regarder**. Demande son propre oui, ligne par ligne.

## Les exemples, et ce qu'ils ne sont pas

Les cas qui suivent montrent une **forme**, sur un projet inventé, une appli de recettes. Leurs
branches, leurs fichiers et leurs chiffres ne décrivent aucun dépôt réel. Ils ne se recopient
jamais dans un rapport.

## Le cas courant

🌿 **A · les branches** : je supprime 4 branches fusionnées et 2 worktrees orphelins. La
branche fermée sans fusion reste là tant que tu ne l'as pas regardée.

| Branche | Où | État | Geste |
|---|---|---|---|
| ajout-minuteur | locale + GitHub | fusionnée il y a 3 semaines | 🗑️ supprimer |
| correctif-photo | locale | fusionnée il y a 2 mois | 🗑️ supprimer |
| essai-theme-sombre | locale | fusionnée il y a 2 mois | 🗑️ supprimer |
| liste-courses | GitHub | fusionnée il y a 5 semaines | 🗑️ supprimer |
| import-recettes | GitHub | fermée sans fusion, 4 commits | 👀 à regarder |
| worktree `ajout-minuteur` | disque | branche fusionnée | 🗑️ supprimer |
| worktree `correctif-photo` | disque | branche fusionnée | 🗑️ supprimer |

🗑️ **B · les fichiers jamais utilisés** : je supprime 3 fichiers que rien n'appelle et 1 dossier
généré commité par erreur.

| Fichier | Ce que c'est | Pourquoi il traîne | Geste |
|---|---|---|---|
| `scripts/migrer-v1.py` | script | rien ne l'appelle depuis la v2 | 🗑️ supprimer |
| `src/ancien-panier.ts` | module | aucun import | 🗑️ supprimer |
| `public/logo-2024.png` | image | aucune page ne la cite | 🗑️ supprimer |
| `src/__pycache__/` | fichiers générés | commités par erreur | 🗑️ supprimer et ignorer |

📐 **C · la spec périmée** : 2 specs et 1 commande du README ne disent plus ce que fait le code.
Je les corrige.

| Document | Ce qu'il dit | Ce que fait le code | Geste |
|---|---|---|---|
| spec des portions | 4 personnes par défaut | 2 personnes, décidé au journal en juin | ✏️ corriger |
| spec du partage | partage par lien | fonction retirée en septembre | ✏️ retirer la section |
| README | `npm install` | le projet utilise `pnpm` | ✏️ corriger |

---

*Combine-les, par exemple « A+C » ou « tout ». Ou dis « détaille B ».*

## Le cas vide

Rien n'est connu nulle part. Les trois lignes sortent quand même, sans tableau.

🌿 **A · les branches** : rien de connu, j'en cherche.

🗑️ **B · les fichiers jamais utilisés** : rien de connu, j'en cherche.

📐 **C · la spec périmée** : rien de connu, j'en cherche.

---

*Combine-les, par exemple « A+C » ou « tout ». Ou dis « détaille B ».*

## Le cas d'une source muette

`gh` ne répond pas. La ligne A le dit, et le tableau ne montre que ce que git a vu seul.

🌿 **A · les branches** : 2 branches locales que git voit fusionnées, à regarder une par une.
Branches distantes et demandes de fusion non lues, `gh` indisponible.

Son tableau suit. Les lignes B et C sortent ensuite comme dans le cas courant, puis la ligne de
choix.

## Les pièges de mise en forme

**Les trois lettres sortent à chaque rapport.** Un menu qui rétrécit ne s'apprend pas, et une
lettre absente laisse croire que l'agent n'a pas regardé.

**Un tableau ne liste que ce qui appelle un geste.** Ce qui a été regardé et va bien ne s'écrit
pas.

**Un bug croisé en route ne va dans aucun tableau.** Une ligne sous le trait le nomme. Elle
renvoie au départ de `/lakitu` qui répare les bugs.
