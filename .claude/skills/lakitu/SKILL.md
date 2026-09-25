---
name: lakitu
description: >
  Te repêche et te repose sur la route, comme le Lakitu des jeux. Tranche ce qu'il faut faire
  maintenant, au lieu d'en dresser la liste. Il suit un ordre de gravité fixe. Ce qui bloque un
  utilisateur d'abord, puis ce qui menace la stabilité, puis ce qui fait avancer le produit, et
  le reste en dernier. Donne ensuite le premier geste concret, borné au quart d'heure, puis
  quatre départs qui gardent leur lettre d'un rapport à l'autre. A la route, B réparer, C
  nettoyer, D réordonner et faire un grand pas.
  Sur une session déjà longue, retrace en tête ce qu'on a ouvert en chemin, et qui l'a ouvert.
  S'invoque UNIQUEMENT sur commande explicite `/lakitu`. Ne se déclenche jamais tout seul.
---

# Lakitu

## But

On l'appelle quand on est paumé. Il doit remettre sur les rails, en une page, sans rien donner
d'inutile à lire.

**Il ne rend donc pas un inventaire.** Il tranche d'abord, il justifie ensuite. La liste vient
après la décision, jamais avant.

> Incident fondateur. Un premier rendu listait quatorze demandes de fusion, quatre-vingt-quatre
> commits, et cinq lignes dont trois disaient qu'il n'y avait rien. L'admin devait choisir seul,
> ce qui est exactement ce qu'il ne peut pas faire quand il est paumé.

**Le second usage, la dérive.** Une session longue dérive sans que rien ne s'allume. On part
fusionner une demande de fusion, et trois heures plus tard on répare une phrase dans un document
que personne ne lit. L'arbre des branches la rend visible.

## Quand il s'exécute

Sur commande explicite seule.

**Deux régimes, selon ce que la session a produit.** Une session qui n'a rien fait n'a rien à
raconter. Le rapport se tourne alors vers le dépôt seul.

- **Session neuve**, moins de trois branches tracées. Pas d'arbre.
- **Session entamée**, trois branches ou plus. L'arbre s'ajoute, en tête du rapport.

**Le seuil vise une demi-heure de travail**, que l'agent ne sait pas mesurer. Les trois branches
en sont l'approximation observable. Un « coucou, ça va ? » n'en produit aucune.

## Ce qu'il n'est pas

**Il n'écrit rien de lui-même.** Aucun fichier, aucun commit, aucune issue. Rendre le rapport
termine son travail.

La seule exception est le oui de l'admin. Chaque lettre ouvre alors ce qu'elle annonce, et rien
de plus. A, B et D écrivent la roadmap, C ouvre des issues et supprime des branches mortes. D
passe ensuite la main à un autre skill, qui écrit bien plus.

Il ne réordonne rien tout seul. L'ordre écrit appartient à l'admin, et le rapport se termine par
un choix qu'on lui laisse.

Il ne se tait pas pour autant. L'étape 4 lui impose de proposer quatre départs, dont trois
réécrivent l'ordre. Se taire laisse un ordre périmé gouverner sans que personne le voie.

## Étape 1. Les quatre rangs

Tout ce qui attend se range dans un rang, et un seul. C'est le coeur du skill.

- 🛑 **Bloquant utilisateur.** Un utilisateur ne peut pas faire ce pour quoi il vient. Aucun
  contournement n'existe.
- ⚠️ **Stabilité.** Ça plante, ça perd des données, ou ça rend un résultat faux. Contournable,
  mais l'application n'est pas fiable.
- 🚩 **Le produit.** Ce qui fait avancer ce que le produit sait faire.
- 🧹 **Le reste.** Hygiène, outillage, dette, branches qui traînent.

**Cet ordre est celui de la gravité, pas celui du rendu.** Le rapport ouvre par le rang d'où sort
la route. La décision arrive ainsi en premier, et le gabarit possède cette bascule.

**L'ordre des rangs dit ce qui passe après.** Le produit ne bouge pas tant que 🛑 et ⚠️ ne sont
pas soldés. Le rapport n'a donc pas à le réécrire en prose.

**La règle qui empêche l'agent de se flatter.** Le rang 🚩 exige un item écrit de la roadmap, ou
une décision datée. Sinon, la ligne descend au rang 🧹.

Le doute descend, toujours. Un agent qui classe son propre travail le classe trop haut.

**L'agent classe lui-même.** Aucune source ne porte la gravité, et attendre qu'un projet
l'étiquette laisserait les deux premiers rangs vides pour toujours. C'est donc un jugement, pas
un fait. Chaque ligne des deux premiers rangs nomme la trace qui la porte, une observation de
l'admin ou un défaut constaté.

**Un rang vide s'écrit « rien de connu ».** Ce n'est pas du remplissage. C'est ce qui justifie que
la route se trouve au rang du dessous.

> Ce que la maquette a montré. Sans les rangs vides, on ne sait pas si l'agent a regardé les bugs
> ou s'il les a oubliés. Ces deux cas appellent des gestes opposés.

## Étape 2. La route

**La route sort du rang le plus haut qui n'est pas vide.** Le choix du rang est mécanique. Il ne
laisse aucune place au goût du moment.

**Sa ligne est nue.** Un titre, la route, rien d'autre. Ce qu'elle débloque se lit dans le rang
juste sous elle, et répéter la justification fait perdre la seule ligne qu'on lit à coup sûr.

**Dans un rang à plusieurs lignes, la première débloque le plus.** On compte ce qui attend
celle-là, dans la roadmap et les issues. Le plus grand compte gagne, et à égalité l'ordre écrit de
la roadmap tranche.

Ce compte est un jugement, contrairement au choix du rang. La ligne de rang le porte donc, « six
items l'attendent ». Sans lui, la route sortirait de l'ordre où la prose a cité ses lignes, un
hasard de rédaction qui gouvernerait tout le rapport.

**Le rang 🧹 ne fournit jamais la route.** Ranger n'est pas un cap. Proposer une corvée à
quelqu'un de paumé le laisse aussi paumé qu'avant.

Si les trois premiers rangs sont vides, le rapport le dit et s'arrête là. **Une route déduite
serait suivie**, et c'est donc le pire résultat possible.

### Où se cherche ce qui remplit les rangs

L'ordre ci-dessous dit où regarder, jamais dans quel ordre trancher. Seul le rang décide de la
priorité.

- Le chantier ouvert de la session en cours, s'il en reste un.
- Les défauts connus, observés par l'admin ou constatés dans le dépôt.
- Les issues ouvertes, les demandes de fusion en brouillon, les branches non fusionnées.
- Le plan, sa file en tête. Le registre, à l'horizon « Maintenant » puis « Ensuite ».

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

**Une source qu'on n'a pas pu lire se nomme, dans son rang.** Par exemple « issues non lues, `gh`
indisponible ». Un rang qui se tait sans le dire vaut « rien à faire », ce qui est le contraire.

### Quand une cible est donnée

Un argument libre nomme une cible, et la route la vise au lieu du rang le plus haut.

```
/lakitu                          la route par défaut, par rang de gravité
/lakitu le produit minimum       la route vise cette cible
```

La cible se cherche en deux temps, les fichiers de roadmap d'abord, le dossier `specs/` élargi
ensuite. Introuvable, elle se dit, et **ni route ni premier pas ne sortent**.

**La route nomme la cible qu'elle vise.** Sans ça, rien ne distingue une route visée d'une route
par défaut.

## Étape 3. Le premier pas

Le rapport ne propose jamais « reprendre la route ». Une route n'a pas de bord, et elle perd
contre une correction fermable en dix minutes.

Il propose **le plus petit geste concret** qui avance dessus. Nommé, borné, faisable dans le quart
d'heure.

**Il s'écrit en une demi-ligne.** Un verbe et son objet, comme « trancher le format du papier :
A4 ou fiche bristol ». Le quart d'heure est la règle qui le dimensionne, pas une durée à écrire.

Ce pas se dérive d'une trace écrite. S'il faut l'inventer, le rapport pose la question au lieu
d'y répondre.

## Étape 4. Par où on part

Le rapport se termine par **quatre départs, jamais par quatre degrés d'un même oui**. Chacun
ouvre un chantier différent, et chacun garde sa lettre d'un rapport à l'autre.

> Incident fondateur. Les options rendaient « j'aligne puis j'attaque », « le premier pas seul »,
> et « autre chose, dis quoi ». La deuxième était la première amputée d'une écriture dont le coût
> n'était nulle part, donc personne ne la prenait. La troisième est ce qui se passe déjà quand on
> tape n'importe quoi. Il restait une option sur trois.

**Trois d'entre eux écrivent la roadmap, et c'est le point.** Les quatre rangs sont l'ordre de
l'agent, pas celui du projet. Le rapport le montre, puis il s'efface quand on le referme. La
roadmap, elle, garde le sien, et gouverne la suite de la conversation.

> Incident fondateur. La roadmap portait trois points sous « Maintenant ». Le rapport a rendu le
> premier cité, un seuil d'affichage, alors que les deux autres débloquaient bien plus. Il ne
> disait nulle part qu'aucune spec n'existait encore. L'admin a dû le voir seul, puis l'agent a
> réordonné de son propre chef sur une simple question.

**A, la route.** Réaligner la roadmap sur l'ordre des rangs, puis attaquer le premier pas.

**Réaligner ne déplace jamais une entrée permanente de la file.** A, B et D classent les items,
et eux seuls. Une entrée qui n'est pas un item, comme celle qui fait ramasser ce qui est prêt avant
d'ouvrir un chantier, garde sa place. Un projet peut l'épingler par un contrôle, et le commit
refusé est alors le signal, pas une panne.

**B, réparer.** Solder les rangs 🛑 et ⚠️, et remanier la roadmap pour que les corrections y
passent devant le produit. Sans cette écriture, on répare, puis on repart sur un ordre périmé et
la suite de la conversation ne suit plus rien.

B se formule sur ce que ces deux rangs contiennent, et **il ne disparaît jamais**.

- Des défauts connus, il les prend par gravité décroissante, en les comptant. « Vingt bugs
  loggés, j'attaque par gravité décroissante. »
- Les deux rangs vides, il se retourne et va chercher. « Aucun bug actif, je creuse pour en
  trouver. »

Un B qui s'effacerait faute de défaut connu ferait passer « rien de connu » pour « rien ». C'est
précisément ce qu'un rang muet ne sait pas dire quand une source lui a manqué.

**C, nettoyer.** Les branches mortes, les erreurs de code jamais remontées en bug, les specs
décalées de ce qui tourne.

C ouvre du travail que le rapport ne connaît pas. Le rang 🧹 ne liste que ce qui a une trace, C
part chercher ce qui n'en a pas encore.

**D, réordonner et faire un grand pas.** Quand A ne suffit pas. A fait un premier pas d'un
quart d'heure, D part pour aller beaucoup plus loin, sans repasser par l'admin. La main passe à
[`../grand-pas/SKILL.md`](../grand-pas/SKILL.md), qui réaligne la roadmap en premier point.

**Le réalignement se fait dans le run, jamais avant.** La branche jetable s'ouvre au début du
run. Une écriture faite avant elle tomberait hors de la demande de fusion livrée. Sur une
session partie de la branche principale, elle la toucherait, ce que le `CLAUDE.md` interdit.

Les deux ne se recouvrent pas. A propose un geste, D propose d'autres portées, que grand pas
rend dans son propre menu. D lui passe les quatre rangs tels quels, et grand pas ne refait pas
le relevé. Ce menu est la seule question qui reste avant le run.

**Une cible trouvée suit la main.** D la transmet avec les rangs, où elle vaut argument. Le menu de
grand pas rend alors deux plans pour elle. Sans ça, `/lakitu <une cible>` puis D perdrait la cible
en route. Introuvable, elle est déjà tombée plus haut, et D suit la route par défaut.

**Une ligne d'échappement ferme le bloc.** Elle offre de détailler une option avant de partir, ou
d'aller ailleurs. Elle n'est pas une cinquième lettre.

### Quand A n'a pas de route à porter

Le menu ne rétrécit pas. Quatre lettres qui changent de nombre selon les cas ne s'apprennent pas.

- **Cible introuvable.** A devient la route par défaut, celle qu'on aurait rendue sans cette
  cible. D la suit.
- **Les trois premiers rangs vides.** A devient « rien à proposer », B « vérifier que c'est
  vrai ». Sans cible, D garde son sens tant que le rang 🧹 porte quelque chose, que la portée C
  vide. Les quatre rangs vides, il devient « rien à passer », sauf une cible à passer.

### Quand la route sort déjà de 🛑 ou ⚠️

A et B se recouvrent, et il faut les séparer. **A ne prend que la première ligne du rang.** B prend
les deux rangs entiers, jusqu'au solde. Sans ça, B n'est qu'un A élargi sans nom.

### Le sprite de départ, et pourquoi A seul y a droit

Partir sur A ouvre le tour suivant par le sprite du kart et sa phrase. Le gabarit les possède.

**Deux conditions, et les deux sont exigées.** La route est de rang 🚩. Et les rangs 🛑 et ⚠️
portent tous deux « rien de connu ».

**B et C n'y ont pas droit, et c'est le but.** Le sprite récompense l'avancée du produit. On la
prend alors plus souvent, au lieu de s'user sur le reste.

**D n'y a pas droit non plus, et pour une autre raison.** Le sprite récompense une avancée
faite. D n'a encore rien avancé quand il sort. Il ouvre un run, dont la fin seule dira s'il
a porté le produit. Le rendu de grand pas tient ce rôle à sa place.

**La seconde condition n'est pas une redondance.** Une route par rang la vérifie d'elle-même, mais
une cible donnée vise hors de l'ordre de gravité. Sans elle, `/lakitu <une cible produit>`
récompenserait une avancée alors qu'un bloquant attend.

**Un A de rang 🛑 ou ⚠️ n'y a pas droit non plus**, c'est une réparation au même titre que B.
**« Détaille » n'y a pas droit**, c'est encore de la délibération, pas un départ.

## Étape 5. Le vocabulaire du projet

**Tout terme maison porte une glose courte à sa première apparition.** Une dizaine de mots, en
incise ou entre parenthèses.
C'est la règle de [`docs/ton-des-echanges.md`](../../../docs/ton-des-echanges.md), et elle compte
double ici. Un rapport de reprise s'adresse à qui revient, donc à qui a oublié les noms.

> Ce que la maquette a montré. Un rendu employait trois termes maison sans un mot d'explication.
> Ce sont exactement les mots qu'on ne se rappelle plus.

## Étape 6. L'arbre

Sur une session entamée seulement, **en tête du rapport**, sous le sprite. Il ne regarde que la
session, jamais le dépôt, et ne déborde pas sur les rangs. Il vient avant la route : la dernière
heure d'abord, la prochaine ensuite.

Une branche y est une tâche qu'on a choisi d'ouvrir, imbriquée sous celle qui l'a fait naître.

> Attention au mot. La branche de l'arbre est une tâche de session, jamais une branche git. Le
> rang 🧹 parle des secondes, et le rapport ne doit pas laisser confondre les deux.

**Rien ne s'invente**, et c'est la règle la plus importante de cette étape. Chaque ligne tient à
une trace : un message de l'admin, un geste proposé puis exécuté, un commit, une contrainte
subie. Un arbre reconstruit de mémoire raconte une histoire cohérente, le défaut même à éviter.

Chaque branche porte son état devant le dessin, et ses marqueurs alignés en bout de ligne.

- 👤 la demande vient de l'admin.
- 🤖 l'agent a ouvert la branche de lui-même.
- 🔗 le harnais l'impose, comme une revue avant de sortir du brouillon.
- 💥 le monde extérieur l'impose, comme un conflit de fusion.
- 🚩 elle fait avancer le produit.

**Les quatre premiers sont exclusifs, et aucune branche n'en manque** : une ligne nue serait une
branche dont l'origine s'est perdue. **Le cinquième se cumule** et vient en second. Il obéit à la
règle anti-flatterie de l'étape 1, sans item écrit ni décision datée il ne se pose pas. Une
demande de l'admin qui avance le produit porte `👤 🚩`.

L'état vaut `✔` allée au bout ou `○` restée en plan, et ne regarde que sa branche, jamais ses
filles. **Toute branche `○` nomme sous elle, en `reste : …`, le geste qui manque** pour finir. La
ligne `reste :` n'est pas une branche, et ne porte ni état, ni trait, ni marqueur.

**Le doute laisse en plan.** C'est la règle anti-flatterie portée à l'état. Marquer fini ce que
personne n'a fermé masque la dérive que l'arbre existe pour montrer.

Deux lignes sous l'arbre donnent les comptes, l'état puis les marqueurs. Un agent qui a pris le
volant se voit là, et non en relisant chaque ligne. **Un marqueur à zéro ne s'y écrit pas**, et
l'état seul écrit les siens.

## Étape 7. Le rendu

Le gabarit exact vit dans [`references/gabarit.md`](references/gabarit.md), et il possède la
forme. L'ordre des blocs, le sprite qui ouvre chaque rapport, la ligne d'échappement qui le ferme.
**Un rapport qui n'aide pas à décider a raté.** Le test n'est pas sa longueur, c'est de savoir
quoi faire en le refermant.
