# Le gabarit de ramasser-pr

> Ce fichier fait foi sur la forme de ce que rend [`../SKILL.md`](../SKILL.md). La phrase
> d'ouverture, la liste des demandes, le bilan posté, le rendu final et le questionnaire. Le
> fond, le lot et les interdits vivent là-bas, leur propriétaire.

## La phrase d'ouverture

Elle sort en premier, en gras, telle quelle. Rien ne la précède, pas même un mot de politesse.

**« Fuuuu....sion!!! »**

Le relevé commence juste après, visible.

## La liste des demandes

Elle sort à la fin du relevé, avant la première demande menée. Un titre, puis une ligne par
demande ouverte, dans l'ordre du lot. Une ligne en italique dit dessous ce que le run prend.

**🗂️ Les demandes ouvertes**

- **#60** · prête · le partage du carnet passe par un lien de sept jours.
- **#61** · prête · l'export de la liste de courses sort aussi en tableur.
- **#62** · prête · le rappel du soir ne sonne plus deux fois le même jour.
- **#65** · prête · la recherche lit aussi les notes.
- **#63** · prête, relue, attend ta fusion · la liste se trie par date d'achat.
- **#64** · prête, déjà tentée, rien de neuf · l'heure des rappels suit le fuseau.
- **#66** · brouillon, pas déclarée finie · la liste partagée garde l'ordre des rayons.
- **#67** · brouillon, bloquée, attend l'admin · le thème sombre suit celui du téléphone.
- **#69** · brouillon, attend tes réponses · le panier se vide après la commande.

*Je prends #60, #61, #62 et #65. #63 attend ta fusion, et #64 n'a pas bougé depuis son bilan. #66
et #67 sont des brouillons qui n'entrent que nommés, et #69 attend tes réponses à son
questionnaire.*

**Une ligne, une phrase.** Ce que la demande change pour qui s'en sert, jamais comment. Une
phrase qui nomme un fichier ou une fonction décrit le code, pas la demande.

**Un argument change la ligne en italique, pas la liste.** Toutes les demandes restent listées.
L'italique dit alors que seules les demandes nommées sont prises.

**Aucune demande ouverte donne une seule ligne**, « aucune demande ouverte, rien à ramasser ».
Le run s'arrête là, sans rendu final.

## Le bilan posté sur une demande qui ne part pas

Un commentaire sur la demande, en cinq lignes, six quand le questionnaire la porte. Le run
suivant le lit, l'admin aussi.

```
Bilan de ramasser-pr, tête 3f2a9c1, branche principale 8d41e07.
Cause : revue. Elle revient quand sa tête bouge.
Repasse en brouillon : un constat survit à sa correction, la date du rappel décalée d'un jour.
Fait : la correction de l'affichage. Reste : le fuseau horaire.
Revues passées : 3. Vérification : contrôles locaux, verts.
```

**Une demande qui reste prête change la troisième ligne**, cause approbation ou fusion à
l'admin. « Reste prête : » remplace « Repasse en brouillon : », suivi de ce qui l'arrête. Pour la fusion à l'admin,
la tête de la demande s'écrit en entier : la commande du run suivant l'épingle telle quelle.

**Une demande portée par le questionnaire gagne une sixième ligne.** Elle nomme ses questions.

```
Questionnaire : Q2 et Q3, en attente de tes réponses.
```

**Les deux têtes et la cause disent quand la demande revient.** Tant que rien ne bouge, le
run suivant ne la reprend pas. Refaire les revues sur le même constat ne fermerait rien.

## Le rendu final

Six blocs au plus, dans cet ordre, après le run. Un bloc vide saute.

1. Le bilan, en une ligne. Combien de demandes fusionnées sur combien de demandes menées.
2. Les demandes, une ligne chacune, dans l'ordre où elles ont été menées.
3. Les demandes laissées, chacune avec sa raison.
4. Ce qui a été rangé, et la demande de rangement qui le porte.
5. Les commandes de fusion à lancer, s'il y en a.
6. Le questionnaire, son lien et ce qu'il porte.

**🌳 FUSION — 2 fusionnées sur 3**

**Les demandes**

- **#60** fusionnée. Première revue propre, sans CI, contrôles locaux verts.
- **#61** fusionnée. Deux revues, trois constats corrigés, CI verte.
  Symptôme si la prémisse est fausse, l'export sort vide. Passe parcours à lancer.
- **#62** repasse en brouillon. Un constat survit à sa correction, la date du rappel décalée
  d'un jour. Fait, la correction de l'affichage. Reste, le fuseau horaire. Bilan posté.

**Laissées**

- **#63**, relue, attend ta fusion, ni sa tête ni la principale n'ont bougé depuis son bilan.
- **#64**, déjà tentée, sa tête n'a pas bougé depuis son bilan.
- **#65**, prise au lot puis laissée, une autre session y a poussé pendant le run. Elle garde
  la fusion de la branche principale que le run y avait poussée. Aucun bilan.
- **#66**, brouillon, pas déclarée finie.
- **#67**, brouillon, bloquée, sa note de décision porte un abandon.

**Rangé en chemin**

- ⚠️ le calcul du total arrondit deux fois, registre Maintenant, puis plan
- 🧹 un import mort dans le module des rappels, backlog
- les deux dans la demande de rangement **#68**, fusionnée sans revue

**À fusionner par toi**

```bash
gh pr merge 63 --repo exemple/carnet --merge --match-head-commit 5b0e2d4a91c7f38e6d20b1a9c4f7e83d2a6b10c5 --delete-branch
```

**La commande ne commence par aucun `cd`.** `--repo` la détache du dossier, et le chemin du
clone de l'admin n'est jamais vu par le skill.

**Deux commandes et plus tiennent sur une seule ligne**, liées pour que la chaîne s'arrête au
premier échec. Une ligne en italique les suit.

```bash
gh pr merge 63 --repo exemple/carnet --merge --match-head-commit 5b0e2d4a91c7f38e6d20b1a9c4f7e83d2a6b10c5 --delete-branch && gh pr merge 71 --repo exemple/carnet --merge --match-head-commit 9c3f7a1e0b6d42f8a5e1c7b3d9f2068e4a1c5b7d --delete-branch
```

*Leur combinaison n'est pas vérifiée. Chaque commande épingle sa demande, pas la branche
principale.*

**Tes décisions**

- 🗳️ Une question sur **#62**, et deux points que je règle seul, dans « Demandes à l'arrêt ».
- Écris « c'est rempli » quand tu as fini. Je fusionne alors sans autre question.

**Le projet de cet exemple est inventé.** Ses numéros, ses constats et ses symptômes ne
décrivent aucun dépôt. Ils ne se recopient jamais dans un rendu réel.

## Le questionnaire

Il suit le modèle `modeles/questionnaire.html` et les règles de tout questionnaire. Ce qui suit
est propre à celui de ce skill.

**En tête, une ligne par demande à l'arrêt.** Son numéro, ce qu'elle change, et combien de
décisions elle attend. Le chapeau dit que les réponses suffisent à fusionner.

**Le lexique glose les mots du ramassage.** Demande de fusion, revue, contrôles, garde de
session. Il relie aussi les noms internes des notes de revue aux noms que l'admin voit.

**L'ordre des parties.** Une par demande, puis « Ce que je règle seul », puis « Après tes
réponses ». La carte des points réglés seuls dit que, laissée telle quelle, elle vaut « Validé ».

**Le bloc « Après tes réponses » tient en étapes numérotées.** Exemple, pour le projet inventé
plus haut.

1. Quand tu as fini, écris « c'est rempli » dans la conversation. Je lis tes réponses ici, sans
   rien te redemander. Une question laissée telle quelle vaut sa réponse recommandée.
2. J'applique tes réponses et les points que tu n'as pas contestés, puis les contrôles repassent.
   S'ils échouent deux fois, la demande s'arrête, et le bilan dit pourquoi.
3. Une revue courte relit mes corrections seules. Un défaut qu'elles introduisent, ou un constat
   qui montre qu'un choix ne marche pas, arrête la demande. Un constat de forme sur elles, ou sur
   du texte qu'elles ne touchent pas, part au backlog.
4. Je fusionne. Tes réponses ne valent pas approbation sur GitHub : si le harnais bloque, tu
   reçois la ligne à coller.
5. Le bilan, dans la conversation, dit pour chaque demande où elle en est.

**Un travail lancé par une réponse s'y dit.** Le bloc nomme qui le lance, et si la fusion
l'attend.

## Les pièges de mise en forme

**Une ligne de demande dit l'état, puis la raison.** « Repasse en brouillon » sans le constat qui
résiste oblige l'admin à rouvrir la revue.

**Une demande menée que le harnais retient va au deuxième bloc.** Sa ligne dit qu'elle reste
prête, relue, et attend ta fusion. Sa commande va au dernier bloc. Parmi les demandes qui
attendent ta fusion, « Laissées » ne prend que celle d'un run passé.

**« Reste » porte l'état, pas l'excuse.** Ce qui est fait, ce qui reste, où ça vit. C'est la
règle du chantier interrompu du `CLAUDE.md`.

**Le symptôme et la passe parcours ne vont qu'aux fusions visibles.** Une demande qui ne change
rien de ce qu'on voit n'en porte pas. Les ajouter partout les rendrait illisibles.

**Le rendu nomme les branches, la doc jamais.** Une branche fusionnée est supprimée, et une
mention dans un fichier suivi deviendrait un renvoi mort.

**Le rendu ne suffit pas à garder l'état.** Il vit dans la conversation, qui disparaît. Ce qui
reste d'une demande non partie vit dans son bilan posté.

**Une chose garde un seul nom dans toute la page.** Une présentation, un écran, un outil. Deux
noms pour la même chose, et le lecteur à froid croit à deux choses.

**Une carte ne promet pas que rien ne change pour l'admin.** « Ce que je règle seul » dit ce qui
change, même peu. Une promesse fausse se voit à la première lecture à froid.

**Un relevé du run qui nuance une revue le dit dans le contexte.** La revue reste citée en source,
mot pour mot. Le contexte réconcilie les deux, sinon le lecteur ne sait lequel croire.

**Aucune demande du lot ne manque au rendu.** Une demande absente a été perdue en route.
L'admin ne le verrait pas seul.
