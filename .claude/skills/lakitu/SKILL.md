---
name: lakitu
description: >
  Te repêche et te repose sur la route, comme le Lakitu des jeux. Rend en une page quatre départs,
  chacun avec ce qu'il ferait sous les yeux. A boucle la session, sur l'arbre de ce qui est resté
  en plan. B réordonne la roadmap, sur une grille de départ. C répare les bugs, sur la liste des
  bugs connus. D attaque l'étape 1 de la roadmap. Les départs se combinent, et s'enchaînent dans
  l'ordre des lettres sans s'arrêter. Les questions arrivent toutes à la fin.
  S'invoque UNIQUEMENT sur commande explicite `/lakitu`. Ne se déclenche jamais tout seul.
---

# Lakitu

## But

On l'appelle quand on est paumé. Il doit remettre sur les rails, en une page, sans rien donner
d'inutile à lire. **Le rapport se comprend sans contexte**, puisque son lecteur a perdu le fil.

**Il ne rend donc pas un inventaire.** Chaque bloc du rapport sert un départ, et rien d'autre.

> Incident fondateur. Un premier rendu listait quatorze demandes de fusion, quatre-vingt-quatre
> commits, et cinq lignes dont trois disaient qu'il n'y avait rien. L'admin devait choisir seul,
> ce qui est exactement ce qu'il ne peut pas faire quand il est paumé.

> Incident fondateur, sur la forme. Le rapport rendait une route, un premier pas, quatre rangs de
> gravité, puis quatre départs exclusifs. L'admin a jugé tout ce qui suivait la route « pas
> clair ». Il voulait voir chaque départ avec ce qu'il ferait, et pouvoir les combiner. Retours de
> l'admin le 2026-11-08, sur des rapports factices puis sur un vrai.

**Le second usage, la dérive.** Une session longue dérive sans que rien ne s'allume. On part
fusionner une demande de fusion, et trois heures plus tard on répare une phrase dans un document
que personne ne lit. L'arbre de A la rend visible.

## Ce qu'il n'est pas

**Il n'écrit rien de lui-même.** Aucun fichier, aucun commit, aucune issue. Rendre le rapport
termine son travail, jusqu'au choix de l'admin.

**Il ne fait pas le ménage.** Supprimer des branches git déjà fusionnées ou corriger un README ne
change rien pour l'utilisateur. C'est le travail de `/menage`, un skill à part.

**Il ne passe pas la main à grand pas.** Qui veut un grand pas appelle `/grand-pas`. Un départ
qui le lançait doublait la commande, et liait les deux skills par des règles de passage.

## Étape 1. Le relevé

Lire, sans rien écrire, ce qui remplit les quatre blocs.

- La session en cours, pour l'arbre de A.
- La roadmap, pour la grille de B et la route de D. Le plan, sa file en tête, puis le registre,
  à l'horizon « Maintenant » puis « Ensuite ».
- Les défauts connus, observés par l'admin ou constatés dans le dépôt, pour C. Les issues
  ouvertes en font partie.
- Les demandes de fusion en brouillon et les branches non fusionnées. Elles disent ce qui est
  déjà commencé ailleurs, pour B et D.

```
specs/roadmap-developpement.md
specs/roadmap-backlog.md
principale=$(git symbolic-ref --short refs/remotes/origin/HEAD | cut -d/ -f2)
gh issue list --state open
gh pr list --state open
git branch --no-merged "$principale"
```

**La branche principale se lit, jamais ne se suppose.** Un dépôt sur `master` ferait échouer la
commande. La source se lirait alors comme muette, à tort.

**Une source illisible se nomme, dans le bloc qu'elle aurait rempli.** Par exemple « issues
non lues, `gh` indisponible » sous C. Un bloc vide sans le dire vaut « rien à faire »,
ce qui est le contraire.

### Les quatre rangs, qui ne s'affichent pas

Tout ce qui attend se range dans un rang, et un seul. Les rangs décident de l'ordre de la grille
et de celui des bugs. Le rapport ne les écrit pas.

- 🛑 **Bloquant utilisateur.** Un utilisateur ne peut pas faire ce pour quoi il vient. Aucun
  contournement n'existe.
- ⚠️ **Stabilité.** Ça plante, ça perd des données, ou ça rend un résultat faux. Contournable,
  mais l'application n'est pas fiable.
- 🚩 **Le produit.** Ce qui fait avancer ce que le produit sait faire.
- 🧹 **Le reste.** Hygiène, outillage, dette.

**La règle qui empêche l'agent de se flatter.** Le rang 🚩 exige un item écrit de la roadmap, ou
une décision datée. Sinon, la ligne descend au rang 🧹. Le doute descend, toujours.

**L'agent classe lui-même.** Aucune source ne porte la gravité. Chaque défaut des deux premiers
rangs nomme donc la trace qui le porte, une observation de l'admin ou un défaut constaté.

## Étape 2. Les quatre départs et leurs blocs

Chaque départ s'écrit en une ligne, puis son bloc juste dessous. La ligne dit ce que le départ
ferait, le bloc montre sur quoi. L'émoji de la ligne est celui du bloc.

### 🟠 A · boucler la session

Finir tout ce que la session a laissé en plan. Le bloc est l'arbre de la session.

**A ne prend que ce qui a une trace dans la session.** Ce sont les tâches 🟠 de l'arbre. Une
gêne subie en chemin y figure aussi, comme un contrôle qui a refusé à tort. Rien d'inventé, rien
de la roadmap.

**Une session neuve n'a pas d'arbre.** Sous trois tâches tracées, la ligne A sort sans bloc.
Elle compte les tâches en plan, ou dit « rien en plan » s'il n'y en a aucune. Le seuil approche
une demi-heure de travail, que l'agent ne sait pas mesurer.

### 🏁 B · réordonner la roadmap

Mettre la roadmap dans l'ordre des rangs. Le bloc est la grille de départ, le nouvel ordre.

**La roadmap se réordonne, elle ne se réécrit jamais.** Trois gestes seulement y sont permis.
Déplacer un item, fusionner deux items qui disent la même chose, rapprocher deux items qui se
chevauchent. Aucun item ne s'ajoute, ne change de fichier, ni ne voit son texte changer.

**Fusionner garde le texte du premier item**, et le second sort. Un second item qui dit quelque
chose de plus n'est pas un doublon, et il reste.

**Le moins de déplacements possible.** Ce qui doit passer devant monte, par son rang ou par ce
qu'il débloque dans son rang. Le reste garde son ordre relatif. Bouger le milieu pour rien noie
les vrais changements.

**Dans un même rang, l'item qui débloque le plus passe devant.** On compte ce qui attend
celui-là, dans la roadmap et les issues. À égalité, l'ordre écrit tranche.

**B ne pose aucune question.** Un doublon douteux ne se fusionne pas, il reste à sa place.

**Une entrée permanente de la file ne bouge jamais.** Ce n'est pas un item, comme celle qui
fait ramasser ce qui est prêt. Un projet peut l'épingler par un contrôle, et le commit refusé
est alors le signal, pas une panne.

### 🐞 C · réparer les bugs

Corriger les bugs connus, puis en chercher d'autres. Le bloc est la liste des bugs connus, en
cartes, du plus grave au moins grave.

**Un bug est ce que l'utilisateur voit.** Une carte le nomme en quelques mots, dit en une phrase
ce que vit l'utilisateur, puis sa trace. C ne touche pas la roadmap. Un défaut que personne ne
voit, comme une spec décalée, relève de `/menage`.

**C ne disparaît jamais.** Sans bug connu, sa ligne dit « aucun connu, j'en cherche ». Un C qui
s'effacerait ferait passer « rien de connu » pour « rien ».

**La recherche est une passe, pas une boucle**. C relit une fois les sources du relevé et ce que
ses corrections touchent, puis rend la main au départ suivant.

### 🌈 D · attaquer l'étape 1

Lancer le premier item de la roadmap, la route. Sa ligne le nomme, sans autre bloc.

**L'étape 1 suit l'ordre en vigueur.** Combiné avec B, c'est l'item que B a mis en tête, même
avant la fusion de B. Seul, c'est celle de la roadmap telle qu'elle est écrite.

**La ligne D nomme les deux quand elles diffèrent.** L'étape 1 avec B d'abord, puis celle sans B.
Le rapport sort avant le choix de l'admin, et il ne sait pas encore si B sera pris. Quand B ne
change pas la tête, la ligne nomme un seul item.

> Incident fondateur. La ligne D annonçait l'item mis en tête par B, avant que l'admin ait choisi
> B. Sans B, D aurait attaqué un autre item que celui annoncé. Relevé par la troisième revue de
> la #98, le 2026-11-08. Décidé par l'admin le même jour, la ligne D nomme les deux.

**Un bug que C vient de corriger ne fait plus la route.** D saute à l'item suivant.

**Un item 🧹 ne fait jamais la route.** Ranger n'est pas un cap. D saute à l'item suivant, et
sans item des trois premiers rangs, il dit « rien à attaquer ».

**Une cible donnée change la route**, même combinée avec B. `/lakitu <une cible>` la cherche
dans les fichiers de roadmap, puis dans le dossier `specs/` élargi. Trouvée, D la vise et la
nomme. Introuvable, D le dit, et ne la remplace par rien.

## Étape 3. Les combinaisons

L'admin choisit une lettre ou plusieurs, « A+B », « ACD » ou « tout ».

**Elles s'exécutent toujours dans l'ordre des lettres**, quel que soit l'ordre tapé. Finir ce qui
traîne, remettre la roadmap en ordre, réparer, puis avancer. Un bug passe ainsi devant le
produit, comme le veulent les rangs.

**Le combo s'enchaîne sans s'arrêter.** Aucun départ ne tranche à la place de l'admin, comme le
veut le `CLAUDE.md`. Une tâche de A ou un bug de C qui attend sa décision reste en plan, et les
autres avancent. Un trou de spec arrête D sur ce point, et rien ne se code autour. Les questions
arrivent à la fin, et se posent selon la règle du questionnaire de
[`docs/ton-des-echanges.md`](../../../docs/ton-des-echanges.md).

**Chaque départ suit le chemin ordinaire du projet.** Sa branche, ses contrôles, sa demande de
fusion, comme le `CLAUDE.md` le veut. Un départ se mène jusqu'à sa demande prête avant que le
suivant s'ouvre. C'est la règle « Un seul chantier à la fois ».

**Le sprite de départ ouvre D.** Deux conditions, toutes deux exigées, lues quand D commence. La
route est de rang 🚩, et aucun bug connu n'attend, ni du rapport ni trouvé par C. Le sprite
récompense une avancée du produit faite sans laisser un bug derrière. Le gabarit possède le
sprite.

## Étape 4. L'arbre de A

**Rien ne s'invente**, et c'est la règle la plus importante de cette étape. Chaque ligne tient à
une trace : un message de l'admin, un geste proposé puis exécuté, un commit, une contrainte
subie. Un arbre reconstruit de mémoire raconte une histoire cohérente, le défaut même à éviter.

Une branche y est une tâche qu'on a choisi d'ouvrir, imbriquée sous celle qui l'a fait naître.
C'est une tâche de session, jamais une branche git.

**L'état passe par une pastille, à gauche.** 🟢 allée au bout, 🟠 restée en plan. Elle ne
regarde que sa branche, jamais ses filles. Le doute laisse en plan, puisque marquer fini ce que
personne n'a fermé masque la dérive.

**Chaque 🟠 que A finira porte un numéro à gauche**, ①, ②, et ainsi de suite. Une branche 🟠
qui attend seulement ses filles n'en porte pas. Le numéro désigne la tâche, son libellé dit le
geste.

**Deux origines, à droite.** 👤 la demande vient de l'admin. 🤖 l'agent l'a ouverte, ou le harnais
et le monde extérieur l'ont imposée. **🚩 se cumule** quand la tâche fait avancer le produit,
sous la règle anti-flatterie de l'étape 1.

**Deux lignes de comptes ferment l'arbre, en émojis avec leur légende.** L'état d'abord, ses deux
comptes toujours écrits. Puis l'origine et 🚩, dont les zéros se taisent.

> Incident fondateur. L'arbre portait cinq marqueurs, une ligne `reste :` sous chaque tâche en
> plan, et `✔` ou `○` pour l'état. L'admin a jugé les indicateurs trop nombreux, et le `reste`
> désagréable à lire. Retours du 2026-11-08.

## Étape 5. Le vocabulaire du projet

**Tout terme maison porte une glose courte à sa première apparition.** Une dizaine de mots, en
incise ou entre parenthèses. C'est la règle de
[`docs/ton-des-echanges.md`](../../../docs/ton-des-echanges.md), et elle compte double ici. Un
rapport de reprise s'adresse à qui revient, donc à qui a oublié les noms.

## Étape 6. Le rendu

Le gabarit exact vit dans [`references/gabarit.md`](references/gabarit.md), et il possède la
forme. **Un rapport qui n'aide pas à décider a raté.** Le test n'est pas sa longueur, c'est de
savoir quoi faire en le refermant.
