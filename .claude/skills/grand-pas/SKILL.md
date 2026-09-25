---
name: grand-pas
description: >
  Met les bottes de sept lieues et avance le produit aussi loin que possible, sans repasser par
  l'admin. Lit ce que lakitu lit, propose ses portées, puis part. A le pas sûr, sans décision
  structurante. B le pas long, en tranchant soi-même ce qu'un humain aurait tranché. C tout
  solder, roadmap, backlog et issues. Un argument libre nomme la chose qu'on veut faire
  avancer. Le menu rend alors deux plans ambitieux pour elle, A et B, et pas de C. Un texte
  libre remplace la lettre. Chaque trou se tranche et se consigne dans une note de décision.
  Chaque anomalie trouvée en route se range dans la roadmap ou le backlog. Livre une demande de
  fusion passée en revue et prête. S'invoque UNIQUEMENT sur commande explicite `/grand-pas`,
  avec ou sans argument, ou par le départ D de `/lakitu`. Ne se déclenche jamais tout seul.
---

# Grand pas

## But

On l'appelle quand on veut que le produit avance sans qu'on tienne la main. Il fait en un run
ce qui demandait une conversation entière de relances.

**Il tranche, il consigne, il continue.** Un trou de spec n'arrête pas le run. Il devient une
décision écrite, prise avec la règle de la portée choisie, et le run repart.

> Incident fondateur. Une session avançait un produit par relances de l'admin. « Et ensuite ? »
> revenait toutes les dix minutes, sur des points dont la réponse était écrite dans une spec ou
> tombait sous le sens. L'admin faisait le travail d'un bouton.

**Le second usage, le soir.** L'admin part et laisse un run tourner. Le lendemain, il lit une
note de décision, une demande de fusion prête, et une roadmap qui porte ce qui a été trouvé.

## Quand il s'exécute

Sur commande explicite seule, avec ou sans argument. Ou par le départ D de
[`../lakitu/SKILL.md`](../lakitu/SKILL.md), qui lui passe ses quatre rangs. Le réalignement de
la roadmap est alors son premier point de run, jamais avant. Lakitu possède cette règle.

**Un argument change le menu et le lot du run.** L'étape 2 possède le menu, l'étape 1 le
relevé, l'étape 4 le lot.

**La phrase d'ouverture sort avant tout le reste**, en gras, telle quelle. Le gabarit la
possède. Puis la réflexion commence, et l'admin la voit.

**Une seule sollicitation, le menu.** Le run pose une question, celle de la portée, puis plus
aucune jusqu'au rendu final. Une question posée en cours de run est une faute, pas une prudence.

## Ce qu'il n'est pas

**Ce n'est pas un lakitu qui écrit.** Lakitu tranche ce qu'on fait maintenant et rend un rapport.
Grand pas fait, jusqu'à la fin annoncée.

**Ce n'est pas un contournement du harnais.** Un garde qui refuse est un bord du run, jamais
un obstacle à passer autrement. Le refus se consigne, le run reprend sur un autre point. Une
demande de permission du harnais, ou un garde en mode « ask », attend l'admin comme d'habitude.
Le skill ne suppose aucun mode de permission, et il ne cherche pas à en changer.

**« Rien n'interrompt » vise les questions du run, pas celles du harnais.** Le run ne pose
aucune question de son cru. Ce que le harnais demande, il le demande, et on ne fait rien péter
pour aller plus loin.

**Ce n'est pas une fusion.** Il ne pousse jamais la branche principale, ne fusionne rien, ne
supprime aucune branche. Il livre une demande de fusion prête, et la fusion reste à l'admin.

## Ce qu'il prend en charge à la place du `CLAUDE.md`

Le `CLAUDE.md` pose quatre règles pour une session ordinaire, où l'admin est là.

- Un trou de spec est une décision de l'admin.
- Une ambiguïté se pose en question courte.
- Un changement graphique attend une maquette validée.
- Un outil système absent se signale, puis on attend.

**Appeler ce skill délègue ces quatre décisions au run.** Le choix de la portée est le « go »
clair du `CLAUDE.md`. Après lui, on enchaîne sans réinterrompre. Le skill prend donc le pas
sur ces quatre règles, et sur elles seules, le temps du run.

**La quatrième n'est pas un contournement.** L'outil manquant se nomme, avec son paquet et sa
commande. Personne n'étant là pour l'installer, attendre reviendrait à figer le run jusqu'au
matin. Le point s'abandonne donc, et l'admin installe en lisant la note.

Tout le reste du `CLAUDE.md` tient tel quel. Un seul chantier à la fois, la provenance nommée,
l'anonymat, la branche principale jamais poussée, et les gardes d'agent.

**Le `CLAUDE.md` ne mentionne pas ce skill, et c'est voulu.** Un fichier d'instructions qui
cite chaque skill grossit à chaque ajout, donc se lit moins. La délégation vit ici, chez celui
qui la demande.

## Étape 1. Le relevé

Lire ce que lakitu lit, aux mêmes endroits et par les mêmes commandes. Les quatre rangs de
[`../lakitu/SKILL.md`](../lakitu/SKILL.md) servent de grille, sans être redéfinis ici.

- Le chantier ouvert de la session en cours, s'il en reste un.
- Les défauts connus, observés par l'admin ou constatés dans le dépôt.
- Les issues ouvertes, les demandes de fusion en brouillon, les branches non fusionnées.
- Le plan, sa file en tête.
- Le registre des items, à l'horizon « Maintenant » puis « Ensuite », que C promet de vider.
- Les specs, pour savoir ce qui est cadré et ce qui ne l'est pas.

**Une source qu'on n'a pas pu lire se nomme.** Elle vaut « inconnu », jamais « rien ». Un run
qui ignore une source ignorée avance sur une carte trouée sans le savoir.

**Un argument oriente le relevé, il ne le remplace pas.** Les mêmes sources se lisent, pour
situer la chose demandée et ce qui s'y oppose. Il se cherche en deux temps, les fichiers de
roadmap d'abord, le dossier `specs/` élargi ensuite. C'est le geste de lakitu pour une cible.

**Introuvable, l'argument n'arrête rien.** Lakitu se tait faute d'écrit, parce qu'il rend une
route à déduire. Grand pas fait, et ce qu'on lui demande de faire n'a pas toujours été écrit
avant. Le relevé note « rien d'écrit », et le menu le reprend.

**La reprise depuis lakitu saute cette étape, sauf ce qu'il ne lit pas.** Un rapport lakitu
frais tient lieu de relevé, par ses quatre rangs. Frais veut dire sans commit ni changement de
branche depuis le rapport. Refaire le reste coûterait une lecture pour rien.

**Les specs se lisent quand même, le registre selon le cas.** La ligne A du menu dit jusqu'où
vont les specs. Le registre se lit pour la portée C, donc sans argument. L'étape 4 y écrit dans
tous les cas, sans avoir eu à le lire.

**L'argument venu de D se situe quand même.** Lakitu l'a trouvé, sinon il ne l'aurait pas
transmis. Son rapport ne dit pas où, et le menu doit le nommer.

Une étape 1 sans les quatre rangs écrits est invalide et se refait.

## Étape 2. Le menu

Sans argument, le menu propose trois portées. Avec un argument, deux plans pour la chose
demandée.

Chaque ligne dit **ce que l'admin a besoin de savoir pour la choisir**, et rien d'autre. Aucun
compte de décisions, ce chiffre serait inventé.

**A, le pas sûr.** Aussi loin que le produit va avec les seules décisions évidentes et logiques.
Le run s'arrête au premier bord atteint. Sa ligne du menu dit une seule chose, on n'ira pas
plus loin que ce que les specs cadrent.

- Un trou que la logique ne peut pas combler.
- Un choix de fonctionnement du produit, celui qu'un humain aurait tranché.
- Un changement graphique sans maquette validée.

**B, le pas long.** Aussi loin que le produit va en tranchant soi-même les décisions
structurantes. Jusqu'à une étape moins cadrée, ou pas cadrée du tout mais dont la suite est
évidente. La fin est le point où même une décision prise ne donne plus de suite dérivable d'un
écrit.

Sa ligne du menu liste, à la louche, les décisions produit que le run comblerait. C'est ce que
l'admin veut voir avant de déléguer.

**C, tout solder.** Vider les rangs, du plus grave au moins grave. 🛑, puis ⚠️, puis 🚩, puis
🧹. La roadmap, le backlog et les issues ouvertes y passent, sans plafond.

On le lance quand les bugs et l'usage se sont accumulés, et c'est là qu'un plafond gênerait. Ce
que le run trouve en chemin se consigne et ne s'ajoute pas au lot en cours.

**La saisie libre.** L'admin écrit ce qu'il veut à la place d'une lettre. « Entre A et B », une
cible nommée, une limite de temps. Le run reformule en une phrase ce qu'il a compris comme fin
prévue, l'écrit en tête de la note, et part. Il ne redemande pas.

**Une cible nommée en saisie libre vaut fin prévue, jamais argument.** Le menu ne se rejoue
pas. Elle se reformule, au lieu de se recopier telle quelle.

**Le menu est le seul arrêt.** Après la réponse, tout ce qui suit se fait sans question. Le
gabarit possède la forme du menu.

Une étape 2 sans fin prévue nommée pour chaque lettre est invalide et se refait. « Rien à
avancer » en tient lieu dans deux cas, le relevé vide et l'argument déjà soldé. Sans cette
sortie, l'étape se refait à l'identique et le run ne part jamais.

### Quand un argument est donné

L'argument nomme une chose à faire avancer. Il devient le lot du run, à la place de ce que le
relevé portait. Chaque rang 🛑 ou ⚠️ hors de l'argument se nomme donc sous le menu, une ligne
chacun.

```
/grand-pas                          le menu ordinaire, trois portées
/grand-pas partager le carnet       deux plans pour cette chose
```

**Le menu rend alors deux plans, A et B, et rien d'autre.** Tous deux visent le bout de
l'argument, jamais un premier pas. C'est ce qui les rend ambitieux.

**A et B gardent leur régime.** A ne tranche que l'évident, B tranche aussi le structurant.
Seul leur objet change, l'argument à la place du relevé. Ce ne sont donc pas deux tailles du
même pas, chaque ligne nomme sa route.

**A vise ce bout sans promettre de l'atteindre.** Quand la première décision structurante tombe
tout de suite, sa ligne le dit. Un A qui promet le bout en tranchant en douce n'est plus un pas
sûr.

**C disparaît, parce qu'il contredit l'argument.** Tout solder vide les rangs, c'est-à-dire ne
rien viser en particulier, donc ignorer ce qu'on vient de demander.

**Un argument sans trace écrite se dit dans le menu.** A y devient le plan que la seule logique
dérive. B tranche ce qu'il faut pour aller au bout.

**Un argument que le dépôt dément se dit en une ligne.** Un écrit s'y oppose, et les deux plans
partent de ce constat. La chose déjà faite est l'autre cas. A y devient « rien à avancer », et
B dit ce qu'il irait chercher au-delà.

**La cible venue du départ D est un argument.** Lakitu la transmet avec ses rangs, et elle
ouvre donc un menu à deux plans.

**La fin prévue reste due pour chaque ligne.** La règle d'invalidité ci-dessus vaut pour deux
lettres comme pour trois.

## Étape 3. Le run

Une branche jetable s'ouvre au départ, au nom libre. Tout le run y vit.

**Un seul chantier à la fois, dans l'ordre des rangs.** Chaque point suit le chemin ordinaire.
Spec, code, tests, doc, commit, push. Le point suivant ne s'ouvre pas avant.

### Un trou se tranche, il ne se pose pas

Tout trou rencontré se trie en trois, et le tri s'écrit dans la note.

- **La réponse est écrite quelque part.** On la prend, et on cite le fichier. Ce n'est pas une
  décision, c'est une lecture.
- **La logique la comble.** Une seule suite est cohérente avec ce qui est écrit. On tranche, on
  consigne avec la raison. Toutes les portées le permettent.
- **C'est une décision structurante.** Plusieurs suites tiennent, et le choix engage le
  fonctionnement du produit. A s'arrête là, c'est sa fin. B et C tranchent, consignent, et
  disent ce qu'un autre choix aurait donné.

**La maquette suit ce régime.** En A, un changement graphique sans maquette validée est un
bord. En B et C, le run dessine la maquette, la range dans la note, et code dessus. L'admin la
voit à la fin, avec le motif du choix.

### Rien n'interrompt

Une erreur, un test rouge, un outil absent, un refus de garde. Aucun de ces cas ne pose une
question. Chacun se consigne, puis le run cherche un autre chemin ou passe au point suivant.

**Un point s'abandonne après deux chemins.** Le premier échoue, on en tente un second. Le second
échoue, le point se ferme avec son état écrit. Ce qui est fait, ce qui reste, où ça vit.

**Un outil système absent se consigne, il ne se contourne pas.** C'est la règle du `CLAUDE.md`,
et un run seul n'a personne à qui demander. Le paquet et la commande d'installation vont dans la
note, et le point s'abandonne.

Une étape 3 qui pose une question à l'admin est invalide. Le run reprend sur le tri des trous.

## Étape 4. Ce qu'on trouve en chemin

Toute anomalie hors du point en cours se range, jamais ne se traite. C'est la règle du
`CLAUDE.md`, « Un seul chantier à la fois », et elle compte double sur un run sans surveillance.

- 🛑 et ⚠️ deviennent un item du registre à « Maintenant », puis une entrée du plan.
- 🚩 et 🧹 vont au registre seul. Une entrée de plan cite toujours un item qui existe.

```
specs/roadmap-developpement.md
specs/roadmap-backlog.md
```

**Ces deux chemins vivent dans un bloc de code.** Ce n'est pas du rangement. Le contrôle 1
du doc-lint suit tout chemin cité en prose. Un projet sans `specs/` verrait donc ce fichier du
noyau casser son lint, sans pouvoir le corriger. Lakitu les cite au même endroit et de la même
façon.

Un item s'écrit au format de l'étalon, quinze lignes au plus. Le fichier absent se crée, aux
horizons de l'étalon, et le run le dit dans la note.

**Le rang se juge, et le doute descend.** Un run qui classe ses propres trouvailles les classe
trop haut. Une ligne des deux premiers rangs nomme la trace qui la porte.

**En portée C, ce qui est trouvé n'entre pas dans le lot.** Le lot est ce que le relevé
portait au départ. Sinon C ne finit jamais.

**Avec un argument, le lot est l'argument.** Ce qui est trouvé à côté se range, même au rang
🛑. Un run qui élargit son lot ne rend plus la chose qu'on lui a demandé de faire avancer.

## Étape 5. La note de décision

Elle vit dans `docs/decisions/`, un fichier par run, nommé par la date. Le gabarit possède sa
forme. Ce dossier est celui que
[`../../../docs/systeme-documentaire.md`](../../../docs/systeme-documentaire.md) désigne pour le
motif d'un choix, daté.

**Elle s'ouvre au départ et se complète au fil du run.** Une session coupée laisse ainsi une
trace. Un run dont la note ne s'écrit qu'à la fin peut disparaître sans rien laisser.

Une ligne par décision. Le trou, ce qui a été tranché, la raison, et la provenance.

- **lu**, en nommant le fichier qui portait la réponse
- **déduit**, en nommant l'écrit d'où la logique part
- **tranché**, pour une décision structurante, avec l'autre choix possible

Une note sans provenance sur une ligne est invalide. La ligne se complète ou la décision se
refait.

## Étape 6. La fin, et la livraison

Le run s'arrête à sa fin prévue. Ou quand tout est soldé. Ou quand le dernier point restant a
été abandonné après deux chemins.

**Avant de dire « c'est fait », recroiser la fin prévue.** Le fait et le non-fait, en deux
listes. Un run qui s'arrête avant sa fin le dit, avec la raison.

Puis la livraison, dans cet ordre, et sans question.

1. Pousser la branche, ouvrir la demande de fusion **en brouillon**.
2. Lancer la revue de code, `/code-review`, sur la demande.
3. Corriger ce qu'elle trouve, pousser, relancer la revue. **Une seule fois.**
4. Passer la demande en **prête**, dès qu'une revue revient propre.

Une première revue propre saute l'étape 3. Rien à corriger ne se relance pas.

**Deux revues au total, donc une passe de correction entre les deux.** C'est la règle des deux
chemins, portée sur la revue. Elle ferme un point après deux tentatives. Un constat qui survit à sa correction part en
abandon, avec son état, et la demande **reste en brouillon**.

Le compte se lit sur les revues lancées, jamais sur les constats. Un run sans surveillance qui
corrigerait jusqu'au propre tournerait jusqu'au matin sur ce qu'il ne sait pas fermer.

**La fusion est un geste de l'admin.** Le run s'arrête à « prête ». C'est la règle du `CLAUDE.md`
sur les sessions en parallèle, et un run seul n'a aucune raison d'y déroger.

Le rendu final suit le gabarit de [`references/gabarit.md`](references/gabarit.md). Il donne la
fin prévue et si elle est atteinte, puis les décisions prises. Ensuite ce qui a été rangé et
où, ce qui a été abandonné, et l'état de la demande de fusion.

Une étape 6 sans revue de code passée est invalide. La demande reste en brouillon.
