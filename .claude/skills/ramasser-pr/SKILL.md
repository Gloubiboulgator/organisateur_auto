---
name: ramasser-pr
description: >
  Ramasse les demandes de fusion ouvertes, prêtes puis en brouillon, les passe en revue, corrige
  ce que la revue trouve, puis les fusionne dans la branche principale. Une demande à la fois,
  de la plus ancienne à la plus récente. Seules les demandes au repos sont prises, sans commit
  depuis deux heures. Les autres appartiennent peut-être à une session encore active, et
  restent. Le run ouvre par la liste de toutes les demandes ouvertes, une phrase chacune. La
  revue suit la règle de grand pas, deux revues au plus et une correction entre elles. Un
  constat hors du changement se range dans la roadmap ou le backlog, par une demande à part. Une
  demande qui ne part pas repasse en brouillon, avec un commentaire qui dit pourquoi. Taper la
  commande vaut le geste de fusion de l'admin. Un argument libre nomme les numéros des demandes
  visées. S'invoque UNIQUEMENT sur commande explicite `/ramasser-pr`, avec ou sans argument. Ne
  se déclenche jamais tout seul.
---

# Ramasser les PR

## But

On l'appelle quand des demandes de fusion attendent, en brouillon ou prêtes. Il les amène une
par une jusqu'à la branche principale, revue comprise, sans repasser par l'admin.

**Le `CLAUDE.md` pose déjà la règle, ramasser passe avant d'ouvrir un chantier.** Une branche
finie qui attend pourrit. Ce skill en fait un geste, au lieu d'une intention qu'on remet à
plus tard.

**Il n'a pas d'incident fondateur à lui.** Il est né d'une demande de l'admin, le 2026-10-14.
Ses règles viennent toutes d'écrits du noyau, et chacune nomme le sien.

## Quand il s'exécute

Sur commande explicite seule, avec ou sans argument.

```
/ramasser-pr          toutes les demandes au repos
/ramasser-pr 61 64    ces deux demandes seulement, au repos ou non
```

**La phrase d'ouverture sort avant tout le reste**, en gras, telle quelle. Le gabarit la
possède.

**Aucune question pendant le run.** La commande est le seul feu vert. Ce qui bloque se consigne,
et le run passe à la demande suivante.

## Ce qu'il prend en charge à la place de l'admin

Grand pas s'arrête à « prête », parce que la fusion est un geste de l'admin. **Taper
`/ramasser-pr` est ce geste.** Le skill fusionne donc seul ce qui sort propre de la revue et de la
CI, et cela seulement.

**La délégation s'arrête là.** Tout le reste du `CLAUDE.md` tient tel quel. Un seul chantier à
la fois, la provenance nommée, l'anonymat, et les gardes d'agent.

**Il ne pousse jamais la branche principale.** La fusion passe par la demande de fusion, en
commit de fusion, comme l'historique du dépôt. Aucune fusion locale poussée, aucune avance
rapide.

**Le `CLAUDE.md` ne mentionne pas ce skill, et c'est voulu.** La délégation vit chez celui
qui la demande, comme pour grand pas.

## Ce qu'il n'est pas

**Ce n'est pas un grand pas.** Il n'avance pas le produit et n'ouvre aucun chantier. Il ferme
ceux qui sont faits.

**Ce n'est pas un contournement du harnais.** Un garde qui refuse est un bord du run. Une
permission demandée ou une protection de branche aussi. Le refus se consigne, et la demande
reste où elle est.

**Ce n'est pas une réécriture.** Il ne rebase rien, ne force aucune poussée, ne réécrit aucun
historique. Une branche jetable reçoit des commits de fusion, jamais une histoire refaite.

## Étape 1. Le relevé

**Sans `/code-review` dans la session, le run s'arrête ici.** Aucune demande n'est touchée, et
le rendu le dit. Le vérifier plus tard ferait toucher tout le lot pour rien.

Lister les demandes de fusion ouvertes, par les outils GitHub de la session. Pour chacune, sa
branche visée, son état, son activité récente, son dernier bilan, et ce qui la bloque.

**Seules entrent les demandes qui visent la branche principale.** Une demande empilée se
fusionnerait dans une autre branche de travail. Elle va au rendu, « vise une autre branche ».

**Au repos veut dire rien de neuf depuis deux heures.** Ni commit, ni poussée sur la branche.
La poussée attrape un commit ancien poussé tard. Un commentaire ou un changement d'état ne
comptent pas, les bilans de ce skill en font.

**Les autres sont peut-être le chantier d'une session encore active.** Une demande qui porte un
bilan se trie d'abord par son bilan, avant le repos.

**Un brouillon qui attend l'admin reste.** Le `CLAUDE.md` le dit, ce qui attend une décision,
une maquette ou une vérification reste sur sa branche. Le corps, les commentaires ou une note
de décision le disent. Il va au rendu, « bloquée, attend l'admin ».

**Un brouillon laissé par grand pas est bloqué exprès.** Son diff porte la note de grand pas.
Grand pas ne laisse en brouillon que ce que sa revue n'a pas fermé. Une demande prête n'est jamais
bloquée par sa note.

**Le bilan est un commentaire laissé sur une demande non partie.** Il porte deux têtes, puis la
cause. La tête de la demande est sa tête distante au moment du bilan, poussées du run comprises. La cause dit ce qui doit
bouger pour que la demande revienne au lot.

- **Revue**, un constat a survécu. Elle revient quand sa tête bouge.
- **Conflit ou vérification**, la cause peut venir de la branche principale. Elle revient quand
  l'une des deux têtes bouge.
- **Approbation**, une protection de branche l'exige. Elle revient quand l'approbation arrive.

Une demande dont rien n'a bougé va au rendu, « déjà tentée, rien de neuf ».

- **Sans argument**, le lot est fait des demandes au repos, prêtes d'abord, brouillons ensuite.
- **Avec des numéros**, le lot est fait de ces demandes, au repos ou non, bloquées ou non. L'admin
  les a nommées, et cela vaut sa décision. Seule la branche visée reste exigée.
- Les demandes laissées vont au rendu, avec leur raison.

**Les prêtes passent d'abord**, parce que le `CLAUDE.md` veut qu'on traite d'abord les
demandes prêtes. Dans chaque groupe, la plus ancienne ouvre la marche. Elle a le plus de
chances de diverger de la branche principale.

**Une source illisible se nomme.** Des outils GitHub absents ou refusés valent « inconnu »,
jamais « rien à ramasser ». Le run s'arrête alors, et le rendu le dit.

**La liste des demandes sort avant le run**, dans la forme du gabarit. Toutes les demandes
ouvertes y figurent, une ligne chacune. La ligne donne le numéro, l'état, une phrase sur ce que
la demande change, et si elle entre dans le lot.

**La phrase se tire du titre, du corps et du diff.** Le nom de branche seul ne suffit
jamais. Elle dit ce que la demande change pour qui s'en sert, pas comment.

**La liste n'est pas un menu.** Elle informe l'admin et n'attend aucune réponse. Le run part
juste après.

Une étape 1 sans cette liste est invalide et se refait.

## Étape 2. Une demande à la fois

Une demande se mène jusqu'à sa fusion ou jusqu'à son abandon. La suivante ne s'ouvre pas avant.
C'est la règle du `CLAUDE.md`, « Un seul chantier à la fois ».

**Sur sa branche, fusionner d'abord la branche principale à jour.** La revue voit alors ce
qui vient d'être fusionné.

**Un conflit se résout quand un seul côté change la logique.** Un fichier généré se
régénère par l'outil du dépôt. Quand les deux côtés changent la même logique, choisir perdrait
un comportement. La demande s'abandonne alors, cause conflit.

**Avant chaque geste sur la demande, sa tête distante doit être celle du relevé**, ou celle
qu'on vient de pousser. Le geste est une poussée, un changement d'état ou un bilan. Sinon une
autre session y travaille encore, et la demande s'arrête là.

**Une demande active n'est plus touchée du tout.** Ni poussée, ni changement d'état, ni bilan.
Elle va au rendu comme active, et son état reste celui que l'autre session lui donne.

**Le délai ne voit pas une session suspendue**, par exemple sur une permission en attente. Ce
contrôle de la tête est le seul filet contre ce cas. Il ne rattrape pas une session qui pousse
après la fusion.

## Étape 3. La revue et ses corrections

La boucle est celle de grand pas, étape 6 de
[`../grand-pas/SKILL.md`](../grand-pas/SKILL.md). Deux revues au plus, une correction entre
elles. Ce skill y ajoute seulement le tri des constats et ce que « propre » veut dire.

**Un constat se trie avant de se corriger.** Seul ce qui touche le changement de la demande se
corrige. C'est la règle du `CLAUDE.md`, « Un changement ne contient que la demande ».

- **Le constat porte sur une ligne que la demande change**, ou qu'elle casse. Il se corrige.
- **Le constat porte sur du code que la demande ne touche pas.** Il se note pour le rangement de
  fin de run. Il ne se corrige pas ici.

**Une revue est propre quand elle ne rend aucun constat du premier genre.** Les constats notés
pour le rangement ne comptent pas. Un constat neuf de la seconde revue compte comme un constat
qui survit.

**Avant chaque commit de correction**, l'impact-grep du `CLAUDE.md` sur les termes changés.
Les hooks du projet tournent au commit. Le message suit l'usage du dépôt, « Traiter la revue de
la NN ».

**La poussée passe par `scripts/pousser.sh`** quand le projet en a un. Il lance les contrôles
du noyau et du projet avant d'ouvrir la connexion.

## Étape 4. Vérifier, puis fusionner

1. Passer la demande en **prête**, si elle ne l'est pas.
2. Obtenir la vérification du dernier commit poussé.
3. Vérifier que la branche principale n'a pas bougé depuis sa fusion dans la branche.
4. Fusionner par un commit de fusion, en exigeant la tête vérifiée.
5. Supprimer la branche distante, que le `CLAUDE.md` veut supprimée après fusion.

**La vérification, c'est la CI du dépôt sur ses demandes.** Sans aucun check, les contrôles
du projet la remplacent, sur la branche à jour.

```
scripts/verifier-noyau.sh
scripts/doc-lint.sh
scripts/code-lint.sh
scripts/pousser-local.sh      s'il existe
```

**Une absence de check n'est jamais un vert.** Le rendu dit laquelle des deux vérifications a
tranché.

**La branche principale a bougé avant la fusion.** On la refusionne une fois dans la branche, et
la vérification repasse. Un conflit à cette refusion passe la revue, dans la limite des deux.
Si la branche principale bouge encore, la demande ne part pas, cause vérification.

**Un écart reste entre le contrôle et la fusion.** La fusion épingle la tête de la demande,
pas celle de la branche principale. Seule une protection qui exige une branche à jour le ferme.
Le rendu dit si le dépôt n'en a pas.

**Une vérification rouge reçoit une correction, une seule.** Cette correction passe la revue
comme les autres, dans la limite des deux revues. Revue épuisée ou second rouge, la demande ne
part pas.

**Rien ne se force pour passer au vert.** Aucun test désactivé, aucun commit vide pour relancer
la CI, aucune fermeture suivie d'une réouverture.

**Une approbation humaine exigée n'est pas un défaut à corriger.** Une protection de branche
qui l'exige est un bord. La demande reste prête, cause approbation.

**Toute demande menée qui ne part pas reçoit son bilan**, avec la cause, ce qui est fait et ce
qui reste. Elle repasse en brouillon, sauf celle qui attend une approbation, qui reste prête.
Une demande devenue active en route n'est pas menée, et ne reçoit rien.

## Étape 4 bis. Le rangement de fin de run

Les constats notés hors du changement d'une demande vont dans la roadmap ou le backlog, selon
l'étape 4 de grand pas. Le rangement se fait une fois, après la dernière demande.

```
specs/roadmap-developpement.md
specs/roadmap-backlog.md
```

**Ces deux chemins vivent dans un bloc de code**, pour la raison que grand pas donne.

**Le rangement a sa propre branche jetable**, et sa propre demande de fusion en brouillon. Il
ne se mêle à aucune demande ramassée. Il survit ainsi à une demande abandonnée, et le prochain
run le ramasse.

## Étape 5. Le rendu

Le rendu final suit le gabarit de [`references/gabarit.md`](references/gabarit.md). Il dit,
pour chaque demande, où elle en est et pourquoi.

- Les demandes fusionnées, avec le nombre de revues et de constats corrigés.
- Celles qui ne sont pas parties, avec ce qui les retient.
- La demande de rangement, si le run en a ouvert une.
- Celles laissées parce qu'actives ailleurs.
- Ce qui a été rangé, et où.

**Une fusion visible porte deux lignes de plus.** Le symptôme à surveiller si sa prémisse est
fausse. Et le rappel de la passe parcours, la règle F5 du `CLAUDE.md`, à lancer à la main.

**Avant de dire « c'est fait », recroiser le lot.** Chaque demande du lot apparaît dans le
rendu, fusionnée ou non. Une demande absente du rendu est une demande perdue.

Une étape 5 qui annonce une fusion sans revue propre ni vérification verte est invalide.
