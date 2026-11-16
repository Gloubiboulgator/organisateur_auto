---
name: menage
description: >
  Fait le ménage qu'aucun utilisateur du produit ne voit. Trois départs, qui gardent leur lettre
  d'un rapport à l'autre. A les branches git déjà fusionnées et les worktrees orphelins. B les
  fichiers que rien n'utilise. C la spec périmée, README et aide d'installation compris. Chaque
  départ rend son tableau, en chiffres, et rien ne s'écrit ni ne se supprime sans le oui de
  l'admin. Ne chasse aucun bug visible, c'est le départ de `/lakitu` qui répare les bugs.
  S'invoque UNIQUEMENT sur commande explicite `/menage`. Ne se déclenche jamais tout seul.
---

# Ménage

## But

Un dépôt accumule ce que personne ne voit. Des branches fusionnées depuis des mois, un script
qui ne sert plus, une spec qui décrit un comportement retiré. Rien ne casse, mais chaque
session relit ce bruit, et le prend parfois pour vrai.

**Il dit ce qu'il ferait, en chiffres.** « Je supprime 5 branches fusionnées et je corrige
2 specs. » Puis il attend le oui.

> Incident fondateur. Le 2026-11-08, l'admin a refondu lakitu. Son départ « nettoyer » mêlait
> les branches mortes et les bugs jamais remontés. Il est sorti pour devenir ce skill, avec une
> frontière nette. Lakitu répare ce que l'utilisateur voit, le ménage range ce qu'il ne voit pas.

## Quand il s'exécute

Sur commande explicite seule, `/menage`, sans argument.

## Ce qu'il n'est pas

**Il ne chasse aucun bug.** Un défaut que l'utilisateur subit relève du départ de
[`../lakitu/SKILL.md`](../lakitu/SKILL.md) qui répare les bugs. Le ménage le croise parfois en
route. Il le nomme alors dans la forme du gabarit, et ne le corrige pas.

**Il ne touche pas à la roadmap.** La réordonner est un départ de lakitu.

**Il n'écrit rien de lui-même.** Rendre le rapport termine son travail. Le oui de l'admin ouvre
ensuite ce que la lettre annonce, et rien de plus. Avant le oui, il ne lance que des lectures,
plus le `git fetch --prune`. Celui-ci ne retire que la copie locale d'une branche que GitHub a
déjà supprimée.

## Étape 1. A, les branches

Une branche fusionnée a déjà versé son contenu dans la branche principale. La supprimer ne perd
rien. Un worktree est une copie du dépôt ouverte pour une session, à côté du dossier principal.

**Ce qu'il cherche.**

- Les branches locales déjà fusionnées.
- Les branches distantes déjà fusionnées, sur GitHub.
- Les worktrees dont la branche est fusionnée, ou dont le dossier a disparu.
- Les branches dont la demande de fusion a été fermée sans fusion.

```
principale=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) \
  && principale=${principale#origin/} \
  || principale=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
git fetch --prune origin
git branch --merged "origin/$principale" --format='%(refname:short)'
git branch -r --merged "origin/$principale" --format='%(refname:short)'
gh pr list --state all --limit 1000 \
  --json headRefName,headRefOid,state,mergedAt,isCrossRepository
git worktree list --porcelain
git -C <worktree> status --porcelain --ignored
lsof -a -d cwd -Fn | grep '^n' | cut -c2-
```

**La sortie de git porte plus que des branches.** `origin` y désigne `origin/HEAD`, et la
principale s'y liste elle-même. Ni l'un ni l'autre n'entre au tableau.

**La branche principale se lit, jamais ne se suppose.** Un dépôt sur `master` ferait échouer la
commande. La source se lirait alors comme muette, à tort. Sans `origin/HEAD`, GitHub la donne.

**Les branches locales se comparent à la principale distante.** `git fetch` ne met pas à jour la
principale locale. Une branche fusionnée sur GitHub depuis le dernier `git pull` lui échapperait.

**Git seul ne voit pas tout.** Une fusion en un seul commit, le squash de GitHub, réécrit
l'historique. Git ne reconnaît plus alors la branche comme fusionnée. L'état de sa demande de
fusion fait donc foi, à côté de `git branch --merged`.

**La demande qui compte est celle de la tête.** Son `headRefOid` est le dernier commit de la
branche. Un nom de branche peut servir à plusieurs demandes, et une demande venue d'un fork, que
`isCrossRepository` marque, ne vise pas la branche du dépôt. Sans demande à la tête de la
branche, elle passe en 👀.

**Une demande ouverte protège sa branche.** Elle ne sort jamais au tableau. Une branche que git
dit fusionnée sans demande fusionnée passe en 👀. Ce peut être une branche à peine créée, sans
commit à elle, où une session commence.

**La liste des demandes se lit en entier.** Une demande « fermée sans fusion » a l'état `CLOSED`.
Une liste qui atteint sa limite est tronquée, et la ligne A le dit, comme une source muette.

**Ce qui ne se supprime jamais.** La branche principale, la branche courante, et toute branche
qu'un worktree gardé a extraite. Un worktree supprimé libère sa branche, qui part après lui.

**Un worktree vivant passe en 👀.** Il porte des fichiers qu'aucun commit ne garde, modifiés ou
ignorés, comme un `.env`. `git status --porcelain --ignored` les montre. Ou une session y tourne
encore, et un processus a alors son dossier courant dedans, ce que `lsof` montre. Sans `lsof`, la
source est muette, et chaque worktree passe en 👀.

**Un worktree détaché passe en 👀.** Il n'a pas de branche à comparer. Un worktree que git marque
`prunable` a perdu son dossier. Il sort en 🗑️, et `git worktree prune` le retire.

**Une branche fermée sans fusion passe toujours en 👀.** Elle porte du travail jamais repris.
On la regarde avant de la jeter.

## Étape 2. B, les fichiers jamais utilisés

**Ce qu'il cherche.**

- Les fichiers suivis que rien n'importe, n'appelle ni ne cite. Scripts, modules, images.
- Les fichiers générés commités par erreur, comme `__pycache__/`, `*.pyc`, `dist/` ou `.DS_Store`.

**« Rien ne l'utilise » se prouve.** Le nom du fichier et son chemin se cherchent dans tout le
dépôt, code, docs et configurations comprises. Puis dans ce qui lance du code sans l'importer.

- Les tâches planifiées et les services de la machine qui fait tourner le projet.
- La CI, les hooks git, les scripts du gestionnaire de paquets, un `Makefile`.
- Les chargements dynamiques, un nom bâti par concaténation ou lu dans un fichier.

**Un point d'entrée, rien ne l'appelle.** Un README, une licence, un test découvert
par son lanceur, une migration, une configuration lue par un outil.
Ils ne sortent jamais en 🗑️.

**Le doute passe en 👀.** Un fichier qui pourrait être appelé d'une façon qu'on n'a pas su
chercher ne se supprime pas d'un oui groupé.

**Un fichier généré se supprime et s'ignore.** Le geste ajoute sa ligne au `.gitignore`, sinon il
revient au prochain commit.

## Étape 3. C, la spec périmée

Une spec est un document qui décrit ce que le code doit faire, dans `specs/` le plus souvent.

**Ce qu'il cherche.**

- Une spec qui décrit un comportement que le code ne fait plus, comme une valeur par défaut.
- Une spec d'une fonctionnalité retirée.
- Le README et l'aide d'installation. Une commande qui ne marche plus, une étape qui manque.

**Seule une affirmation vérifiable se compare.** Un chiffre, un nom, une commande, un
comportement que le code porte. Une intention ou un « pourquoi » ne se juge pas contre le code.

**Une commande d'installation se vérifie sans rien écrire.** On lit les manifestes, comme
`package.json` ou `requirements.txt`. On ne lance que ce qui ne modifie rien.

**Corriger une spec, c'est décider que le code a raison.** Le code suit la spec, jamais
l'inverse. Le code n'a donc raison que si une source le dit. Une décision consignée, une entrée du
journal, ou le commit qui a changé le comportement exprès. La ligne cite alors cette source, et
sort en ✏️.

**Sans source, la ligne passe en 👀**, et la question revient à l'admin. Quand c'est le code qui a
tort, c'est un bug. Il relève du départ de lakitu qui répare les bugs, et la ligne sort du
tableau.

## Étape 4. Les sources muettes

**Une source qu'on n'a pas pu lire se nomme, dans sa ligne.** Par exemple « branches distantes
non lues, `gh` indisponible ». Une ligne qui se tait sans le dire vaut « rien à ranger », ce qui
est le contraire.

**Une lettre vide s'écrit « rien de connu, j'en cherche ».** Ce n'est pas du remplissage. Sans
elle, on ne sait pas si l'agent a regardé ou s'il a oublié.

## Étape 5. Le oui, et ce qu'il ouvre

**Le oui se donne par lettre, et se combine.** « A+C », « tout », ou « détaille B ». Les lettres
s'enchaînent dans l'ordre, sans s'arrêter.

**Un oui groupé ne prend que les lignes 🗑️ et ✏️.** Chaque ligne 👀 demande son propre oui,
ligne par ligne. C'est elle qui porte le risque.

**Les suppressions de branches se font sur place.** Elles ne touchent aucun fichier suivi. Un
worktree se retire avant sa branche. Le bilan donne, pour chaque branche supprimée, son dernier
commit. Il suffit à la recréer.

**Une branche se supprime par `git branch -d`.** Git la refuse quand il ne la voit pas fusionnée.
C'est le cas après un squash, ou quand la principale locale est en retard. `git branch -D` ne
passe alors que si la tête de la branche est encore le `headRefOid` de sa demande fusionnée, relu
juste avant.

**Les écritures de B et C partent dans une demande de fusion.** Une branche jetable s'ouvre,
jamais la branche principale. L'admin relit et fusionne.

**Le bilan suit la règle du bilan de fin de chantier**, dans
[`docs/ton-des-echanges.md`](../../../docs/ton-des-echanges.md). Le détail va dans la demande de
fusion.

## Étape 6. Le vocabulaire

**Tout terme technique porte une glose courte à sa première apparition.** Branche fusionnée,
worktree, squash, spec. C'est la règle de
[`docs/ton-des-echanges.md`](../../../docs/ton-des-echanges.md), et elle compte double ici.
On lance le ménage rarement, donc on en a oublié les mots.

## Étape 7. Le rendu

Le gabarit exact vit dans [`references/gabarit.md`](references/gabarit.md), et il possède la
forme. **Un rapport qui n'aide pas à décider a raté.** En le refermant, on sait ce qui va disparaître
et ce qui va changer.
