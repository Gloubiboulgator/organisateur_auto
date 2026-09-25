# Les étalons d'écriture

> Ce fichier **fait foi** sur la forme de tout ce qui s'écrit dans le projet. La doc, les
> spécifications et la prose du code. Le système qui le fait respecter vit dans
> [`systeme-documentaire.md`](systeme-documentaire.md).

## Écrire lisible, mise en page et ponctuation

Une doc dense, écrite par et pour une machine, est illisible et intransmissible. Les règles
valent pour **toute** la doc, et le contrôle 7 du doc-lint les impose hors dette.

**Le bloc ci-dessous est le seul endroit où ces règles sont écrites.** Le contrôle 3 vérifie que
ses copies sont identiques au caractère près. Le contrôle 10 confronte en plus ses valeurs aux
constantes de [`../scripts/doc-mesure.py`](../scripts/doc-mesure.py). Le texte et la mesure ne
peuvent donc pas dire deux choses différentes.

<!-- sync:etalon-redaction -->
**Une idée par phrase, environ 15 mots, 25 au maximum.** Couper plutôt qu'enchaîner.

**Toute énumération devient une liste verticale.** Jamais de suite (a)(b)(c), jamais de chaîne
de « · » au fil d'une phrase.

**Ligne vide entre les blocs.** Le gras est réservé aux titres, jamais à l'emphase en pleine
phrase.

**Un paragraphe tient en trois phrases, 4 au maximum.** Au-delà, on coupe, on sous-titre, ou
on liste. Un pavé se balaie, il ne se lit pas.

**Un signe, un rôle.**

- `;` `→` `&` ne vont nulle part en prose. Écrire « donne », « et », ou faire une liste.
- `—` marque une incise par phrase au maximum. Jamais en cascade, jamais dans un titre.
- `·` sépare les métadonnées d'une ligne de titre, jamais dans une phrase.
- `:` introduit une liste ou un exemple, jamais dans un titre.
- `( )` porte une précision courte, une par phrase, jamais imbriquée.
- `« »` encadre les libellés d'interface et les citations.
- Les accents graves encadrent le code, les chemins et les identifiants.

**Le détail qui ne tient pas va chez son propriétaire**, et un lien suffit.

**Longueurs cibles** : item de roadmap 15 lignes, note de décision 150, spec 300.
<!-- /sync:etalon-redaction -->

La mesure vit dans [`../scripts/doc-mesure.py`](../scripts/doc-mesure.py). C'est un outil de
suivi, qui n'échoue jamais, à ne pas confondre avec le doc-lint.

**Conforme ne vaut pas validé.** Une réécriture n'est faite qu'après relecture de l'admin.
L'étalon mesure la forme, pas le goût.

**L'étalon s'applique aussi à la prose du CODE.** Les commentaires et les docstrings sont de la
prose. Ils obéissent donc aux mêmes règles, sans qu'une seule soit réinventée ailleurs. Le calcul
est partagé, dans [`../scripts/etalon_prose.py`](../scripts/etalon_prose.py).

## Écrire du code lisible

La section précédente gouverne la prose, y compris celle des commentaires. Les règles ci-dessous
gouvernent le **code** lui-même.

**Le bloc ci-dessous est le seul endroit où ces règles sont écrites.** Le contrôle 3 vérifie ses
copies. Le contrôle 11 confronte ses nombres aux constantes de
[`../scripts/code-mesure.py`](../scripts/code-mesure.py).

<!-- sync:etalon-code -->
**Une règle ne s'écrit qu'à un seul endroit.** Deux endroits qui doivent la connaître appellent
une fonction partagée, jamais une copie. Toutes piles.

**Un commentaire dit pourquoi, jamais quoi.** Un commentaire qui paraphrase sa ligne signale un
nom à changer, pas un commentaire à garder. Toutes piles.

**Une fonction mute son argument, ou elle rend une valeur.** Jamais les deux. Python,
JavaScript, Kotlin.

**Un aiguillage est une table, pas une cascade.** Une cascade qui reste porte une ligne qui la
déclare. Elle échappe alors à la limite de longueur. Toutes piles.

**Une fonction tient dans un écran, 50 lignes.** Les tests de comportement ont leur propre
seuil, plus large. Toutes piles.

**Un fichier de plus de 500 lignes porte un bandeau par section.** Jamais de table des matières,
qui serait une copie des bandeaux. Toutes piles.

**Rien ne se rattrape en silence.** Un rattrapage d'erreur laisse une ligne de journal, et un
rattrapage large nomme ce qu'il attend. Toutes piles.

**La prose du code obéit à l'étalon de rédaction**, commentaires et docstrings compris. **Tout ce
qui naît porte un nom français**, sans renommage rétroactif.
<!-- /sync:etalon-code -->

**Deux de ces règles ne se mesureront jamais.** Aucun programme ne distingue un commentaire qui
explique le pourquoi d'un commentaire qui répète sa ligne. Aucun ne voit deux logiques jumelles
écrites avec des mots différents. Ce sont les deux premières, et ce sont les plus importantes.

Elles ne restent pas sans surveillance. Une relecture les cherche, fichier par fichier. Un audit
qui comprend ce qu'il lit les cherche aussi, sur une tranche à la fois.

## Écrire une vitrine

Cette section gouverne le fond des fichiers **vitrine**, ceux qu'on lit en premier. Le
`README.md` racine, pour le visiteur. Une vitrine n'est pas une doc, c'est une page
d'atterrissage.

Elle répond à quatre questions, dans cet ordre, en quelques secondes chacune.

1. C'est quoi ? Le pitch en langage lecteur, jamais en vocabulaire interne du projet.
2. Pourquoi ça existe ? Le problème raconté en deux ou trois phrases. Une histoire se retient,
   une liste de fonctions non.
3. À quoi ça ressemble ? Montrer avant d'expliquer, par une capture ou une animation.
4. Comment j'essaie ? Le chemin le plus court vers un premier succès, sans variantes.

Tout le reste renvoie aux docs par un lien. Trois corollaires.

- Les bénéfices avant la mécanique.
- Le technique tient en quelques lignes, avec ses liens, pour le lecteur qui veut vérifier que
  c'est sérieux.
- Aucun code interne, aucun numéro de version, aucune taxonomie de projet.

Les deux pièges à reconnaître sont le README-rapport d'avancement, écrit pour l'équipe, et le
README-sommaire, écrit pour l'archiviste. Le test qui départage : un inconnu qui tombe sur le
dépôt comprend-il, et a-t-il envie d'essayer, en trente secondes ?

## Écrire un README d'outil, et pourquoi ce n'est pas une vitrine

Les README **autres** que le racine ne s'adressent pas à un visiteur. Ils s'adressent à qui va se
servir de l'outil ou le modifier. Leur appliquer la règle vitrine les viderait de leur utilité.

Un README d'outil répond à trois questions, dans cet ordre.

1. **À quoi ça sert, et comment ça marche.** Le mécanisme, assez pour qu'on puisse le déboguer.
2. **Comment on s'en sert.** Installer, lancer, les gestes du quotidien.
3. **Ce qu'il faut savoir avant d'y toucher.** Garde-fous, pièges, décisions passées et motifs.

Ce qu'il **possède** : le fonctionnement de son outil, ses gestes, ses règles d'exploitation.
Ce qu'il ne possède **jamais** : le comportement du produit, le statut d'un chantier, ce qui est
livré.

**Le vocabulaire interne y est légitime**, c'est l'inverse exact de la vitrine. Le lecteur cherche
les noms de fichiers et de fonctions, et les cacher lui coûte un aller-retour dans le code.

> Incident fondateur. Une règle de gestion a été écrite dans le README d'un outil sans qu'aucune
> règle ne dise si elle avait le droit d'y être. Un lecteur appliquant « vitrine » l'aurait
> retirée comme du vocabulaire interne, et elle aurait disparu sans que rien ne s'allume.

## Écrire une roadmap, des horizons et pas un inventaire

Une roadmap est un outil de décision, pas un entrepôt d'items. Elle répond à trois questions,
lisibles en deux minutes. Ce qu'on fait maintenant, ce qui vient ensuite, ce qu'on a choisi de ne
pas faire et pourquoi.

**Un plan qu'on lit et un registre qu'on maintient sont deux documents.** Ils ont deux lecteurs.
Tant qu'ils partagent un fichier, le registre gagne par le volume. L'échafaudage de suivi noie le
plan.

**Le plan se raconte, il ne se liste pas.** Le test qui départage : le plan doit pouvoir se lire
à voix haute. Un paragraphe par horizon, écrit en phrases, une minute de lecture.

- **Le registre** est rangé par **horizons**. Maintenant, Ensuite, Plus tard, Hors scope. Sans
  dates, parce que sur un projet solo les horizons glissent et c'est normal. Le plan, lui, porte
  sa file en tête, et chacune de ses entrées cite un item du registre. Décision admin du
  2026-09-16 : un horizon ne se cherche jamais dans le plan.
- Chaque horizon regroupe des **caps**, le résultat visé dit en une phrase en langage lecteur.
- **Peu de caps, haute altitude.** Cinquante lignes au même niveau ne hiérarchisent rien.
- **Les décisions négatives portent leur raison.** C'est ce qui évite de re-débattre.

Le piège nommé, et il revient : **la machinerie qui écrit le document**. Trois versions de suite,
c'est le lint et l'étalon qui avaient dicté la forme, pas le lecteur.

> Leçon apprise en supprimant un ancien rangement. **Une structure qu'on retire définissait
> peut-être des choses en creux.** Avant de supprimer une structure, chercher ce qu'elle était
> seule à expliquer.

## Écrire une fiche technique

Une **fiche technique** recharge un concept d'informatique générale, appliqué ici, en deux
minutes. Ce n'est pas une spécification. Le comportement vit dans les specs, la fiche donne le
mécanisme et le motif du choix.

- **Une fiche, un fichier**, nommé par le terme. On trouve par le nom du fichier, jamais par une
  famille. Un classement par rayons suppose qu'on connaisse déjà le terme cherché.
- **La porte est le [glossaire](comprendre/glossaire.md)**, qui possède la définition brève. La
  fiche n'a pas le droit de redéfinir le terme, elle l'explique. Ce chemin est une EXIGENCE du
  noyau, pas une simple citation : le contrôle 18 la tient, et l'installateur repose le fichier
  s'il manque. Son contenu, lui, reste la propriété du projet.
- **Le gabarit, quatre blocs et pas un de plus.**
  - *En clair*, l'analogie, sans vocabulaire technique
  - *Sous le capot*, le vrai mécanisme, avec le vrai vocabulaire
  - *Pourquoi chez nous*, à quoi ça sert ici, et où creuser
  - *Source*, un lien fiable, un seul
- **Une techno introduite égale sa fiche dans le même commit**, plus son entrée de glossaire.
- **Aucun fait volatil recopié**, ni statut, ni chiffre, ni chemin exact. La fiche pointe vers le
  fichier propriétaire. Ce qu'elle explique est stable, donc sans risque de dérive.

### L'entrée de glossaire, et le lien qu'elle arme

Une entrée est une puce. Le terme en gras, puis sa définition brève.

```
- **terme** : la définition brève, une phrase ou deux.
```

Un terme qui possède une fiche porte en plus un lien vers elle.

```
- **terme** ([fiche](fiches-techniques/<terme>.md)) : la définition brève.
```

**Toute entrée fait entrer son terme dans le périmètre du doc-lint**, avec ou sans fiche. Le
premier emploi du terme, dans n'importe quelle doc, porte un lien vers le glossaire, ou vers sa
fiche quand elle existe. Un lecteur qui bute sur un mot trouve ainsi son explication en un clic.

**Tout terme technique entre au glossaire dans le commit qui l'introduit.** Sans entrée, rien
ne peut exiger son lien. Le mot reste du jargon nu, et le contrôle ne connaît que le glossaire.
Cette part-là tient par l'auteur.

> Incident fondateur. Une roadmap, le premier document qu'un lecteur ouvre, employait « spike »
> et « répétition espacée » sans un mot d'explication. Le glossaire les définissait. Rien ne
> rougissait, parce que seuls les termes à fiche comptaient.

**Ce que la mesure ne couvre pas.** Le contrôle vérifie qu'un terme est lié au moins une fois
dans son fichier. Il ne vérifie pas que c'est le premier emploi qui porte le lien. Un terme de
plusieurs mots coupé par un retour à la ligne lui échappe aussi.

La règle reste celle du premier emploi, et cette part-là tient par la relecture. Le détail des
deux trous vit en tête de l'outil, [`liens-glossaire.py`](../scripts/liens-glossaire.py).

Les variantes d'un même terme se séparent par une barre oblique ou par une virgule.

## Le jargon courant ne se francise pas de force

Un terme technique qui a un usage anglais standard s'écrit en anglais. Dans les documents, les
commentaires et les messages de commit.

On lui donne son genre français. Un seed, le cache, un commit, un build, un hash.

Traduire produit un mot que personne n'emploie, et la clarté y perd. On ne traduit que si le mot
français est, lui, l'usage courant.

Le reste s'écrit en français. C'est le jargon seul qui garde sa langue.
