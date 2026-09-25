# Le système documentaire, comment la doc tient debout

> **Ce fichier fait foi** sur la façon dont l'information est possédée et partagée. La **forme**
> de ce qui s'écrit vit à côté, dans
> [`etalons-de-redaction.md`](etalons-de-redaction.md).

## Le problème qu'on combat

Une même information finit écrite à trois endroits. On en corrige un. Les deux autres deviennent
faux, et rien ne le signale. Six mois plus tard, personne ne sait lequel des trois dit vrai.

C'est la **dérive documentaire**. Elle ne fait aucun bruit, et elle coûte plus cher que les
bogues, parce qu'elle fait travailler sur une fausse carte.

## Le principe fondateur, une seule source de vérité

**Chaque information a UN seul propriétaire, un fichier responsable.** Tous les autres documents
y renvoient par un lien, ou en partagent une copie vérifiée identique. Jamais une copie libre.

Ce principe gouverne tout le reste. Les contrôles ne font que le rendre non contournable.

## Les deux seules façons de partager du contenu

**Le lien.** Le cas normal. On écrit une phrase et on renvoie au propriétaire. Le contrôle 1
refuse le commit si la cible n'existe pas.

**Le bloc synchronisé.** Quand deux fichiers doivent vraiment porter le même texte, on le balise.

```
<!-- sync:ma-cle -->
Le texte partagé, à l'identique.
<!-- /sync:ma-cle -->
```

Le contrôle 3 compare toutes les copies d'une même clé, au caractère près, et refuse le commit à
la moindre différence. C'est la seule duplication autorisée, parce que c'est la seule qui ne
peut pas diverger en silence.

## La carte, qui possède quoi

| Information | Propriétaire | Les autres |
|---|---|---|
| la vision et le pitch | `README.md`, la vitrine | en partagent l'essence par un bloc synchronisé |
| le point d'entrée et la carte des specs | le hub du projet | tous les docs y renvoient |
| les règles de doc | ce fichier | le fichier d'instructions y renvoie |
| la forme de ce qui s'écrit | [`etalons-de-redaction.md`](etalons-de-redaction.md) | ce fichier y renvoie |
| le comportement de l'agent | `CLAUDE.md` | renvoie ici pour les règles de doc |
| une règle chargée à chaque session, quand le fichier d'instructions est plein | son propriétaire reste un fichier de `docs/` | `.claude/rules/` en porte la copie, jamais l'original |
| le comportement du produit | les fichiers de `specs/` | sans aucun statut dedans |
| ce qui reste à faire | la roadmap | les autres lient |
| ce qui est livré, et quand | `CHANGELOG.md` | les autres lient |
| les croyances sur le monde extérieur | [`observations-terrain.md`](observations-terrain.md) | le code porte l'étiquette |
| la définition brève d'un terme | le glossaire | les fiches techniques l'expliquent |
| ce qui protège le projet | [`garde-fous.md`](garde-fous.md) | rien ne le recopie |

**Spec ou doc, un seul test.** Un fichier va dans `specs/` seulement si un constructeur l'ouvre
pour savoir **quoi coder**. C'est le comportement d'une
brique. Ses entrées, ses sorties, ses messages exacts et ses cas limites. Tout le reste est un
doc.

**Être source de vérité est une propriété, pas un dossier.** Un doc peut faire foi sur un sujet
et rester un doc.

**Les docs se rangent par lecteur.** Chaque fichier a un lecteur primaire, et le dossier suit ce
découpage.

- `guide/` pour l'utilisateur du produit
- `comprendre/` pour qui veut savoir comment marche un morceau
- `exploitation/` pour qui fait tourner la machine
- `decisions/` pour le motif d'un choix, daté
- `archives/` pour ce qui est clos

On n'invente **jamais** une catégorie pour caser un orphelin. S'il n'a pas de lecteur, il
n'existe pas.

## Alimenter le journal des livraisons

`CHANGELOG.md` répond à une seule question. Qu'est-ce qui a changé d'important, et quand ? Ce
n'est **pas** un journal de commits.

- **Une entrée quand** un item de la roadmap est terminé, ou quand une décision structurante
  change la façon de comprendre le projet.
- **Pas d'entrée pour le bruit.** Ni typo, ni reformulation, ni remaniement sans impact
  observable. Le test du doute : dans six mois, voudrais-je savoir que ça a changé ?
- **Format.** Un en-tête daté, le plus récent en haut. Une ligne en gras pour le quoi, plus le
  pourquoi si c'est une décision. Le pourquoi est le plus précieux.
- **On ajoute, on ne réécrit jamais le passé.** Une entrée datée reflète ce qu'on savait ce
  jour-là.

Le contrôle 4 vérifie le format. Il ne peut pas deviner une entrée oubliée. Ça, c'est la
discipline.

## Le garde-fou, le doc-lint et le hook

[`../scripts/doc-lint.sh`](../scripts/doc-lint.sh) rejoue une batterie de contrôles. Chacun doit
revenir vide. Le hook pre-commit le lance à chaque commit et **bloque le commit** si un contrôle
rougit.

| # | Garantit que… |
|---|---|
| 1 | tout lien interne pointe vers un fichier qui existe |
| 2 | aucun prénom n'apparaît, nulle part |
| 3 | les blocs synchronisés sont identiques partout |
| 4 | le journal des livraisons est daté et trié du plus récent au plus ancien |
| 5 | toute branche citée dans la doc existe, ou est marquée comme passée |
| 6 | aucun compteur vivant n'est figé en prose |
| 7 | l'étalon de rédaction est respecté par tout fichier hors dette |
| 8 | la dette de format ne fait que rétrécir |
| 9 | la dette ne grossit pas par le bas, un fichier inscrit n'empire pas |
| 10 | le texte de l'étalon et le code qui le mesure disent la même chose |
| 11 | idem pour l'étalon de code |
| 12 | l'étalon de prose est respecté par le code hors dette |
| 13 | la dette de prose du code ne fait que rétrécir |
| 14 | toute croyance sur le monde extérieur porte son étiquette et sa fiche |
| 15 | le registre des garde-fous colle au dépôt, dans les deux sens |
| 16 | le registre des garde-fous ne rétrécit jamais |
| 17 | tout terme du glossaire employé dans un fichier y est lié au moins une fois |
| 18 | le glossaire que le noyau exige, docs/comprendre/glossaire.md, est en place |

Le détail exact vit dans le script, qui en est le propriétaire. Cette table n'en donne que
l'intention.

**Les contrôles propres à un projet vivent à part**, dans `scripts/doc-lint-local.sh`, avec des
numéros préfixés par `L`. Le noyau ne connaît pas ce fichier, et ne le réécrit jamais.

## L'audit de non-perte, avant toute réécriture

Une réécriture raccourcit. Elle peut donc effacer un fait que rien ne rattrapera, et **aucun
contrôle ne le verra**. Le doc-lint mesure la forme, jamais ce qui manque.

L'audit se fait **avant le commit**, en trois temps qui ne se remplacent pas.

**Le relevé mécanique.** On compare l'ancienne version à la nouvelle, et on liste ce qui a
disparu. Identifiants, dates, sigles, codes, et tout mot de plus de cinq lettres. Chaque disparu
se cherche ensuite dans le reste du dépôt. Un mot introuvable est un fait à réintégrer.

**La lecture des affirmations.** Une phrase reformulée peut rester fausse alors que tous ses mots
existent encore ailleurs. Chaque phrase qui affirme un comportement se relit donc contre la spec
qui le possède. On ne la relit **pas** contre l'ancienne version, qui peut avoir dérivé.

**Le compte rendu.** Le commit dit ce qui a été retiré, et où chaque chose a été retrouvée. Sans
lui, l'audit n'est pas vérifiable.

> Incident fondateur. Un hub annonçait un réglage retiré six jours plus tôt par sa propre spec.
> Le relevé mécanique n'a rien vu, tous les mots vivaient encore dans la phrase même qui les
> retire. Seule la lecture des affirmations l'a trouvé.

## Les limites, en toute honnêteté

Le système est solide, pas magique. Le doc-lint garantit les motifs encodés et les blocs
explicitement balisés. Il **ne voit pas** deux choses.

- Une **copie libre** introduite demain sans balise. Rien ne lui dit que ces deux paragraphes
  devraient être identiques.
- Une **dérive de sens** dans du texte non balisé. Deux fichiers qui se contredisent sur un point
  qu'on n'a pas verrouillé.

C'est pourquoi trois disciplines humaines complètent le mécanique. L'impact-grep à chaque
changement, la vérification sur toutes les branches avant d'affirmer un état de code, et un audit
de relecture à déclencheur fixe. Elles vivent dans `CLAUDE.md`.

**Répartition.** L'impact-grep et l'audit **trouvent**. Le lint **empêche que ça recommence**.
