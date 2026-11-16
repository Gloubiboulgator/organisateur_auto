---
name: ramasser-pr
description: >
  Ramasse les demandes de fusion prêtes, les relit, corrige ce que la revue trouve, puis les
  fusionne. Un brouillon n'entre que si l'argument le nomme. Une demande à la fois : les prêtes de
  la plus ancienne à la plus récente, puis les brouillons nommés dans le même ordre. Le run ouvre
  par la liste des demandes ouvertes, une phrase chacune. Trois revues au plus, chacune suivie de sa
  correction. Un constat hors du changement se range à part. Une demande qui ne part pas repasse en
  brouillon avec un bilan, sauf celle qui attend une approbation ou la fusion de l'admin. Ce qui
  retient les autres finit dans un questionnaire, dont les réponses suffisent à les fusionner. Taper
  la commande vaut le geste de fusion de l'admin quand le harnais le laisse passer. Sinon le rendu
  donne la commande à lancer. Un argument libre nomme les numéros visés. S'invoque UNIQUEMENT sur
  commande explicite `/ramasser-pr`, ou quand l'admin dit avoir rempli son questionnaire. Ne se
  déclenche jamais tout seul.
---

# Ramasser les PR

## But

On l'appelle quand des demandes de fusion prêtes attendent leur revue. Il les amène une par une
jusqu'à la branche principale, revue comprise, sans repasser par l'admin.

**Il est le relecteur.** Le `CLAUDE.md` veut la revue sur une demande prête, jamais par la
session qui l'a écrite. C'est ce skill qui la fait.

**Le `CLAUDE.md` pose déjà la règle, ramasser passe avant d'ouvrir un chantier.** Une branche
finie qui attend pourrit. Ce skill en fait un geste, au lieu d'une intention qu'on remet à
plus tard.

**Il est né sans incident fondateur**, d'une demande de l'admin, le 2026-10-14. Ses premières
règles viennent d'écrits du noyau, et chacune nomme le sien. Ses incidents sont venus ensuite,
chacun sous la règle qu'il fonde.

## Quand il s'exécute

Sur commande explicite, avec ou sans argument, ou sur le questionnaire qu'il a rendu.

```
/ramasser-pr          toutes les demandes prêtes
/ramasser-pr 61 64    ces deux demandes seulement, prêtes ou en brouillon
```

**La phrase d'ouverture sort avant tout le reste**, en gras, telle quelle. Le gabarit la
possède.

**Il reprend aussi sur son questionnaire.** L'admin dit que la page est remplie, et le run des
réponses part sans nouvelle commande. Elles valent le feu vert de chaque demande portée.

**Aucune question pendant le run.** La commande est le seul feu vert. Ce qui bloque se consigne,
et le run passe à la demande suivante. Ce qui attend une décision de l'admin part dans le
questionnaire de fin de run, jamais en cours de route.

## Ce qu'il prend en charge à la place de l'admin

Grand pas s'arrête à « prête », parce que la fusion est un geste de l'admin. **Taper
`/ramasser-pr` est ce geste.** Le skill fusionne donc seul ce qui sort propre de la revue et de la
CI. Il y ajoute son rangement, rien d'autre. La session fusionne, le run part dans un [sous-agent](references/sous-agent.md).

**Le harnais peut refuser cette délégation.** Vu de GitHub, une revue par `/code-review` n'est
pas une approbation. Le garde d'une session refuse alors une fusion qu'aucun humain n'a
approuvée. Ce refus est un bord, et la fusion revient à l'admin, par une commande prête.

> Incident fondateur. Le 2026-10-20, deux demandes sorties propres de la revue et de la
> vérification n'ont pas pu partir. Le harnais a refusé les deux fusions, « Merge Without Review ».

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

**Sans `/code-review`, le run s'arrête ici.** Aucune demande n'est touchée, et le rendu le dit.
Le vérifier plus tard ferait toucher tout le lot pour rien.

Lister les demandes de fusion ouvertes, par les outils GitHub de la session. Pour chacune, sa
branche visée, son état, sa tête, son dernier bilan, et ce qui la bloque.

**Seules entrent les demandes qui visent la branche principale.** Une demande empilée se
fusionnerait dans une autre branche de travail. Elle va au rendu, « vise une autre branche ».

**Toute demande prête entre, sans délai d'inactivité.** Le `CLAUDE.md` le dit, « prête » veut
dire « fini, à relire ». Une session peut pourtant pousser encore après l'avoir déclarée prête.
Ce risque est accepté, et l'étape 2 dit ce qui le limite. Une demande qui porte un bilan se trie
par son bilan avant d'entrer au lot.

> Décidé par l'admin le 2026-10-26, qui retire le délai de deux heures. Tout ce qui est prêt
> doit être ramassé.

**Un brouillon n'entre pas au lot sans son numéro.** Il n'est pas fini, et le `CLAUDE.md` veut
la revue sur une demande prête. Il va au rendu, « brouillon, pas déclarée finie ». **Nommé en
argument, il entre.** Le numéro donné par l'admin vaut « c'est fini ».

**Un brouillon qui attend l'admin se dit.** Le `CLAUDE.md` le dit, ce qui attend une décision,
une maquette ou une vérification reste sur sa branche. Le corps, les commentaires ou une note
de décision le disent. Il va au rendu, « bloquée, attend l'admin ».

**Un bilan qui porte la ligne « Questionnaire » attend tes réponses**, même si sa tête bouge. Il
va au rendu, « attend tes réponses ». Nommée, elle se mène comme les autres, et son bilan perd la
ligne « Questionnaire ». Une tête qui a bougé arrête aussi la reprise, comme le dit
[`references/questionnaire.md`](references/questionnaire.md).

> Décidé par l'admin le 2026-10-22, par questionnaire. Une demande qui attend ses réponses ne se
> relit pas, même modifiée. Ses réponses ne sont jamais jetées en silence.

**Le bilan est un commentaire laissé sur une demande non partie.** Il porte deux têtes, puis la
cause. La tête de la demande est sa tête distante au moment du bilan, poussées du run comprises. La cause dit ce qui doit
bouger pour que la demande revienne au lot. Une demande qui attend la fusion de l'admin porte sa
tête en entier, celle que sa commande épingle.

- **Revue**, un constat a survécu. Elle revient quand sa tête bouge.
- **Conflit ou vérification**, la cause peut venir de la branche principale. Elle revient quand
  l'une des deux têtes bouge.
- **Approbation**, une protection de branche l'exige. Elle revient quand l'approbation arrive.
- **Fusion à l'admin**, le harnais a refusé le geste. Revue et vérification sont acquises sur
  les deux têtes du bilan. Elle revient quand sa tête bouge, ou quand une approbation arrive.
  Quand seule la branche principale bouge, elle est revérifiée sans revue, comme le dit
  [`references/fusion-admin.md`](references/fusion-admin.md). Sinon elle va au rendu, « relue,
  attend ta fusion », avec sa commande.

Une autre demande dont rien n'a bougé va au rendu, « déjà tentée, rien de neuf ».

**Un bilan ne fait pas entrer un brouillon.** La demande non partie a repassé en brouillon.
Sans argument, elle revient au lot quand une session la remet en prête, et son bilan dit alors
si quelque chose a bougé. Nommée, elle entre comme tout brouillon nommé.

- **Sans argument**, le lot est fait de toutes les demandes prêtes.
- **Avec des numéros**, le lot est fait de ces demandes, prêtes ou en brouillon, bloquées ou
  non. L'admin les a nommées, et cela vaut sa décision. Seule la branche visée reste exigée.
- Les demandes laissées vont au rendu, avec leur raison.

**Les prêtes passent d'abord**, les brouillons nommés ensuite. Dans chaque groupe, la plus
ancienne ouvre la marche. Elle a le plus de chances de diverger de la branche principale.

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

**Un brouillon nommé passe en prête en premier**, avant toute revue. La revue se fait sur une
demande prête.

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

**Ce contrôle de la tête est le seul filet contre une session encore active.** Elle peut
pousser encore après avoir déclaré sa demande prête. Il ne rattrape pas une session qui pousse
après la fusion.

## Étape 3. La revue et ses corrections

1. Lancer la revue de code, `/code-review`, sur la demande, au niveau et au nombre que fixe
   [`references/tri-des-constats.md`](references/tri-des-constats.md).
2. Corriger ce qu'elle trouve, pousser, relancer **une seule fois**, sauf après une revue unique.
3. Corriger ce que trouve la seconde, pousser, puis rendre la troisième revue à la session.

Une revue sans rien à corriger arrête la boucle. Une forme à corriger compte comme à corriger.

**Trois revues au plus, chacune suivie de sa correction.** Le compte se lit sur les revues
lancées, jamais sur les constats. Les revues courtes n'y entrent pas, comme celle de l'étape 7.
Un run qui corrigerait jusqu'au propre tournerait sans fin sur ce qu'il ne sait pas fermer.

**Un constat se trie avant de se corriger.** Seul ce qui touche le changement de la demande se
corrige. C'est la règle du `CLAUDE.md`, « Un changement ne contient que la demande ».

- **Le constat porte sur une ligne que la demande change**, ou qu'elle casse. Il se corrige.
- **Le constat porte sur du code que la demande ne touche pas.** Il se note pour le rangement de
  fin de run. Il ne se corrige pas ici.

**Une revue propre ne rend aucun constat du premier genre.** Le tri, les niveaux et l'agent de
la troisième revue vivent dans [`references/tri-des-constats.md`](references/tri-des-constats.md).

**Avant chaque commit de correction**, l'impact-grep du `CLAUDE.md` sur les termes changés.
Les hooks du projet tournent au commit. Le message suit l'usage du dépôt, « Traiter la revue de
la NN ».

**La poussée passe par `scripts/pousser.sh`** quand le projet en a un. Il lance les contrôles
du noyau et du projet avant d'ouvrir la connexion.

## Étape 4. Vérifier, puis fusionner

1. Obtenir la vérification du dernier commit poussé. Réécrire la description si elle a vieilli.
2. Vérifier que la branche principale n'a pas bougé depuis sa fusion dans la branche.
3. Rendre la main à la session, qui fusionne en exigeant la tête vérifiée.
4. Supprimer la branche distante, que le `CLAUDE.md` veut supprimée après fusion.

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
la vérification repasse. Un conflit à cette refusion prend l'une des revues qui restent, et la
troisième part à l'agent. Après la dernière revue, sa résolution passe une revue courte, et un
défaut qu'elle y introduit arrête la demande. Si la branche principale bouge encore, la demande
ne part pas, cause vérification.

**Un écart reste entre le contrôle et la fusion.** La fusion épingle la tête de la demande,
pas celle de la branche principale. Seule une protection qui exige une branche à jour le ferme.
Le rendu dit si le dépôt n'en a pas.

**Une vérification rouge reçoit une correction, une seule.** Cette correction passe la revue
comme les autres, dans la limite des revues de la demande. Après la dernière, elle passe une
revue courte. Un défaut qu'elle y introduit ou un second rouge, et la demande ne part pas.

**Rien ne se force pour passer au vert.** Aucun test désactivé, aucun commit vide pour relancer
la CI, aucune fermeture suivie d'une réouverture.

**Une approbation humaine exigée n'est pas un défaut à corriger.** Une protection de branche
qui l'exige est un bord. La demande reste prête, cause approbation.

**Un refus du harnais au geste de fusion ne se contourne pas.** La demande reste prête, cause
fusion à l'admin, avec sa branche distante. Le refus vaut pour tout le run. Les demandes
suivantes vont jusqu'à leur vérification verte, sans rendre la main pour la fusion.

**Toute demande menée qui ne part pas reçoit son bilan**, avec la cause, ce qui est fait et ce
qui reste. Elle repasse en brouillon, sauf celle qui attend une approbation ou la fusion de
l'admin, qui reste prête.
Une demande devenue active en route n'est pas menée, et ne reçoit rien.

## Étape 4 bis. Le rangement de fin de run

Les constats notés pour le rangement, revues courtes comprises, vont dans la roadmap ou le
backlog, selon l'étape 4 de grand pas. Le rangement se fait une fois, après la dernière demande.

```
specs/roadmap-developpement.md
specs/roadmap-backlog.md
```

**Ces deux chemins vivent dans un bloc de code**, pour la raison que grand pas donne.

**Le rangement a sa propre branche jetable** et sa propre demande, qui survit à une demande
abandonnée. Il ne se mêle à aucune demande ramassée. La session la fusionne sans revue à la fin
du run. Son relais et son incident vivent dans [`references/sous-agent.md`](references/sous-agent.md).

## Étape 5. Le rendu

Le rendu final suit le gabarit de [`references/gabarit.md`](references/gabarit.md). Il dit,
pour chaque demande, où elle en est et pourquoi.

- Les demandes fusionnées, avec le nombre de revues et de constats corrigés.
- Celles qui ne sont pas parties, avec ce qui les retient.
- Celles qui attendent la fusion de l'admin, avec leur commande.
- La demande de rangement, si le run en a ouvert une.
- Le questionnaire, s'il y en a un, avec son lien.
- Celles laissées parce qu'actives ailleurs, avec ce que le run y avait déjà poussé.
- Ce qui a été rangé, et où.

**Une fusion visible porte deux lignes de plus.** Le symptôme à surveiller si sa prémisse est
fausse. Et le rappel de la passe parcours, la règle F5 du `CLAUDE.md`, à lancer à la main.

**Une demande que le harnais retient donne sa commande de fusion**, prête à lancer. Sa règle vit
dans [`references/fusion-admin.md`](references/fusion-admin.md), sa forme dans le gabarit.

**Avant de dire « c'est fait », recroiser le lot.** Chaque demande du lot apparaît dans le
rendu, fusionnée ou non. Une demande absente du rendu est une demande perdue.

Un rendu qui annonce une fusion sans revue propre ni vérification verte est invalide. Quatre
exceptions : les corrections de la dernière revue, une forme rangée par une revue courte, le rangement et une rediffusion de pures copies.

## Étape 6. Le questionnaire de fin de run

Ce qui retient les demandes menées qui ne sont pas parties finit dans un questionnaire. Ses
réponses suffisent à les fusionner, sans autre question. Il sort après le rendu, qui en donne le
lien. Sa règle vit dans [`references/questionnaire.md`](references/questionnaire.md).

## Étape 7. Le run des réponses

Il part quand l'admin dit que la page est remplie, et ne pose aucune question. Il applique les
réponses, les consigne, puis relit ses seules corrections par une revue courte. Il vérifie et
fusionne comme à l'étape 4. Sa règle vit dans le même fichier.
