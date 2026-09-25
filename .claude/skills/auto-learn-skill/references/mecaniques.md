# Les huit mécaniques, et ce qu'elles coûtent vraiment

À lire à l'étape 3, une fois le verdict rendu. Ce fichier ne recopie aucune règle. Il sert à
**choisir**, puis à annoncer le vrai prix. La liste vivante des garde-fous existants est le
registre [`docs/garde-fous.md`](../../../../docs/garde-fous.md), pas ce fichier.

La colonne *coût* est la plus utile. Une proposition qui oublie un fichier obligatoire se
transforme en commit refusé chez l'admin, ce qui est exactement ce qu'on cherchait à éviter.

## 1. Contrôle du doc-lint

**Attrape** ce qui se lit dans des fichiers suivis par git, doc comprise. Motifs, liens,
cohérence entre deux fichiers, vocabulaire périmé.

**Coût** : le contrôle dans `scripts/doc-lint.sh`, **plus** sa ligne dans la table de
`docs/systeme-documentaire.md`. Le contrôle 15 refuse le commit si la ligne manque.

**Modèle à copier** : le contrôle 16 de `scripts/doc-lint.sh`. Il garde le registre en table
et refuse qu'une clé en disparaisse. Ne copiez plus le contrôle 15 : son corps a déménagé dans
`scripts/registre-garde-fous.py`, et il ne tient plus qu'en trois lignes de délégation.
Squelette obligatoire, dans cet ordre.

```
# NN) LE POURQUOI, le cas vécu, la date.
section "NN. Titre court"
out=$(python3 - 2>&1 <<'PYNN'
...  # une ligne imprimée par violation, rien si tout va bien
PYNN
)
out=$(garde_plante $? "$out")
check "ce qui est garanti" "$out"
```

Trois pièges qui ont déjà mordu ce dépôt :

- **Le numéro se prend libre en tenant compte des branches ouvertes**, pas seulement de `main`.
  Deux contrôles homonymes se fondent en silence à la fusion.
- **`garde_plante` n'est pas optionnel.** Sans lui, un heredoc qui lève écrit sa trace sur la
  sortie d'erreur. La capture reste vide, et le contrôle compte vert pour toujours.
- **La comparaison se fait en Python**, jamais en `grep -i`, qui ne replie pas les accents.

## 2. Contrôle du code-lint

**Attrape** les fautes lexicales du code que la machine locale ne peut pas compiler. Kotlin,
workflows, tests, déclarations sans consommateur.

**Coût** : le contrôle dans `scripts/code-lint.sh`, plus son entrée au registre, à cause du
contrôle 15. S'il demande un script à part, ce script vit dans `scripts/`.

**Modèle à copier** : le contrôle 1 de `scripts/code-lint.sh`. Il porte le bon patron
d'exemption, un commentaire `# @assertion-double : <motif>` posé sur la ligne, ou sur celle du
dessus. Une exemption nommée vaut mieux qu'un contrôle qu'on désactive.

## 3. Filet dans un hook git

**Attrape** ce qui dépend du geste git lui-même, pas du contenu. Le sens d'une fusion, la
fraîcheur d'une preuve de tests, ce que l'amont a touché pendant qu'on travaillait.

**Coût** : du bash dans `scripts/githooks/`, plus l'entrée au registre. Attention, `merge.ff`
doit valoir `false` pour que `pre-merge-commit` se déclenche, ce que pose `installer-hooks.sh`.

**Modèle à copier** : le second filet de `scripts/githooks/pre-push`, qui nomme les fichiers
que l'amont a touchés aussi, sans jamais refuser. Un hook qui ne décide rien reste lisible.

**La leçon vient d'un garde antérieur, hors de ce dépôt.** Il testait une **sentinelle absolue**,
un commit qui n'appartenait qu'à une ligne de version. Un calcul relatif à la branche principale
se serait vidé précisément le jour de l'accident.

## 4. Étiquette plus fiche

**Attrape** une croyance écrite comme un fait. Sur le monde extérieur, ou sur la sortie de nos
propres prompts.

**Coût** : le patron d'étiquette dans le code, la fiche dans `docs/observations-terrain.md`, et
le contrôle qui les relie. Le contrôle 14 fait déjà ce travail pour `@terrain` et `@suppose`.

**Choisir cette mécanique quand** la faute est de *ne pas avoir su* qu'on supposait. Une
étiquette ne vérifie rien du monde. Elle rend visible qu'une ligne repose sur du vent.

## 5. Liste de dette qui rétrécit

**Attrape** une règle de forme qu'on veut imposer au neuf sans réécrire tout l'ancien.

**Coût** : **trois** contrôles solidaires, jamais un seul. Un qui exige, un qui refuse toute
ligne ajoutée à la liste, un qui empêche un fichier déjà inscrit d'empirer. Le trio doc est
7 plus 8 plus 9. Le duo code, 12 plus 13, n'a pas le troisième, et c'est un trou connu.

**La règle qui fait tout marcher** : une liste d'**exclus** qui ne fait que rétrécir, jamais une
liste d'autorisés. Un fichier neuf naît conforme, sans geste à penser. Le contrôle 7 a d'abord vécu
l'inverse, et aucun fichier neuf n'y entrait.

## 6. Hook d'agent

**Attrape** un geste d'agent avant qu'il parte, pas un fichier après qu'il soit écrit. C'est la
seule mécanique qui agit sur le monde extérieur au dépôt.

**Coût** : un script `scripts/garde-*.sh`, en bash et grep, ou en Python de la bibliothèque
standard quand le jugement l'exige. Il lui faut **sa déclaration dans le
`.claude/settings.json` versionné**, avec un chemin en `${CLAUDE_PROJECT_DIR}`, et **sa ligne au
registre**. Le contrôle 15 refuse le commit si l'une des deux manque. Le fichier de réglages
suit le clone, donc aucune pose manuelle n'est nécessaire.

**Modèle à copier** : l'un des gardes d'agent existants. Deux propriétés à ne pas perdre en le
copiant.

- **Il échoue ouvert.** Un hook qui plante bloquerait l'outil qu'il surveille, donc toute la
  session. Bash et grep seuls, ou Python de la bibliothèque standard, sortie en zéro sur tout
  chemin inattendu.
- **Son motif épargne le mot seul.** La garde exige une adresse, pas le nom du site, pour que
  l'impact-grep continue de marcher.

## 7. Angle d'audit périodique

**Attrape** ce qui demande du jugement sur du code déjà écrit. Il **signale**, il ne bloque
rien.

**Coût** : une ligne dans le fichier de configuration des angles, quand le projet en tient un.
S'y ajoute la déclaration de ses **objets** dans la table des angles. Quand un contrôle garde
cette table, il refuse le commit si la déclaration manque.

**Le piège propre à cette mécanique** : un constat trouvé par deux angles se paie deux fois,
deux nuits, deux runs. Avant d'ajouter un angle, vérifier qu'aucun objet n'appartient déjà à un
autre. La table du cadrage existe exactement pour ça.

## 8. Règle écrite

**Attrape** un jugement qui dépend du contexte, et que rien ne peut mesurer. La provenance d'une
affirmation, le moment où poser une question.

**Coût** : du texte, et **rien qui le fasse respecter**. `CLAUDE.md` le dit de ses propres
règles non mécaniques. Elles rendent la faute constatable en une seconde, ce qui est déjà
beaucoup, mais elles ne bloquent rien.

**Trois questions avant d'en proposer une**, et le premier non ferme la porte.

1. Aucune des sept mécaniques ci-dessus n'attrape ce cas, et c'est écrit mécanique par
   mécanique, pas en bloc.
2. La règle porte sur un **jugement**, pas sur une forme. Une forme se mesure, donc se mécanise.
3. Elle rend la faute constatable après coup. Sinon ce n'est ni un garde-fou ni une méthode.

**Deux contraintes de placement**, si les trois réponses sont oui.

- Elle entre dans une **section existante** de `CLAUDE.md`, sauf si aucune ne peut la porter.
- **Budget constant** : dire ce qu'on peut retirer en échange. Le fichier est chargé à chaque
  session, et un fichier qui grossit sans fin est un fichier moins lu.

Elle entre aussi au registre, sous forme d'un début de titre de section, à cause du contrôle 15.
