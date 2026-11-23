# Du besoin à la spec

Le propriétaire de cette règle est [`../../docs/du-besoin-a-la-spec.md`](../../docs/du-besoin-a-la-spec.md).
Le bloc ci-dessous en est la part opérationnelle, partagée et vérifiée identique.

<!-- sync:du-besoin-a-la-spec -->
**Un produit part du besoin, jamais de l'outil.** La méthode a deux étages et neuf marches. Une
marche ne s'ouvre que si la précédente a sa sortie, validée par l'admin.

**Étage 1, le produit.** Il se fait une fois et produit la roadmap.

| Marche | Ce qu'on fait | Ce qui en sort |
|---|---|---|
| 1. Le besoin | On part de situations vécues, pas de fonctions réclamées. On écrit une à trois phrases « Quand…, je veux…, pour… ». | Les phrases de besoin |
| 2. Le cadre | On dit ce que le produit est, et ce qu'il n'est pas. | Une courte liste de bornes |
| 3. Le parcours | On pose de gauche à droite ce que l'utilisateur fait. Les étapes viennent sous chaque activité. | La carte du parcours |
| 4. Les tranches | La première tranche traverse tout le parcours, au plus mince. Les suivantes l'épaississent. Une tranche porte trois fonctions au plus. Au moins une est peu incertaine, une au plus est très incertaine. Ce qui ne sert aucun besoin sort. | La roadmap |

**Étage 2, la brique.** Il se rejoue à chaque étape de la roadmap.

| Marche | Ce qu'on fait | Ce qui en sort |
|---|---|---|
| 5. Le problème | On resserre ce qui ne va pas. On fixe un budget de temps, et ce qu'on exclut. | Un problème borné |
| 6. L'essai à la main | L'agent fait le travail de la brique dans l'échange, sur un cas réel de l'admin. L'admin corrige. | Des corrections concrètes |
| 7. Les règles | Chaque correction devient une règle, avec ses exemples. Ce que personne ne sait trancher devient une question. | Règles, exemples, questions |
| 8. La spec | Elle dit le quoi et le pourquoi, jamais le comment. Chaque flou porte une marque. Elle est finie sans marque. | La spec |
| 9. La forme et les outils | Maquette, canal, technique. Seulement maintenant. | Maquette validée, puis code |

**Ce qui tient l'ensemble.**

- **Les questions avant la spec**. La page à choix n'arrive pas avant la marche 8, et ne porte
  que les marques restantes. Avant, l'agent montre la sortie de la marche et ses hypothèses sur
  ce qui lui manque, à valider ou à reprendre. Dès deux textes à valider, ils partent ensemble
  dans une page, selon la règle des questionnaires. Aucune question de forme, de canal ou d'outil
  avant la marche 9.
- **Un projet déjà lancé**. Un projet lancé fait valider sa roadmap une fois, comme sortie de la
  marche 4. Une brique déjà commencée repasse le problème, validé avant de reprendre, même après
  un go. Sa spec se relit contre lui, et ce qui ne le sert pas ne sort qu'avec l'accord de
  l'admin. Elle reprend à la première marche dont la sortie manque. Cela précise la règle
  « Avant de coder » du fichier d'instructions, qui vise aussi la brique reprise.
- **Les messages exacts**. À la marche 9, une fois le canal choisi, les messages exacts et ce qui
  dépend du canal entrent dans la spec. Ils se valident avant le code. Cela précise la même règle
  « Avant de coder », qui les exige.
- **Après un go**. Pour une brique, après un go, l'agent s'arrête au problème, à l'essai, à la
  spec et à la maquette. Par exception à l'ouverture des marches, la spec s'ouvre sans attendre
  la validation des règles. L'agent les montre à l'arrêt de la spec, où l'admin les valide avec
  elle. Ces arrêts priment sur la règle du go du fichier d'instructions.
- **Les signaux de la marche 7 renvoient en arrière.** Beaucoup de questions, on refait un essai.
  Beaucoup de règles, la brique est trop grosse, on la coupe.
- **Les sources de l'étage 1 sont écrites pour des équipes**. Leur tenue pour une personne seule
  avec un agent est un pari, à revoir après le premier projet mené ainsi.
<!-- /sync:du-besoin-a-la-spec -->
