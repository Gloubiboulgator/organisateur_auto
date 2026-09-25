# Le gabarit du parcours Kotlin

> Ce fichier fait foi sur ce qu'on adapte et ce qu'on ne touche pas dans
> [`ParcoursVisuelTest.kt`](ParcoursVisuelTest.kt), le fichier à copier dans le dossier
> `androidTest` du projet. Il pilote l'app par UiAutomator, comme un doigt sur l'écran.

## Le contrat que les scripts lisent

Le seuil de captures se dérive de ce fichier par `scripts/captures-attendues.py`. Il ne
comprend que ces formes, et refuse tout le reste.

- `photographier("littéral")`, l'argument entre guillemets.
- `repeat(n) { i -> … }`, la seule boucle dépliée.
- `${i}` ou `${i + k}` dans un littéral, résolus sur la boucle qui l'entoure.
- Un test conditionné au jeton se reconnaît à `assumeTrue` et au nom de l'argument du jeton,
  celui du réglage `ARG_JETON`, cités dans son corps.
- Un test `@Ignore` n'attend rien.

Un `photographier(nom)` avec une variable fait rougir la chaîne, en nommant la ligne. Ce n'est
pas une limite du parseur, c'est sa règle : deviner rouvrirait le plancher à zéro.

## Le nom d'une capture

Il contient le nom de l'écran, tel que `scripts/verifier-captures.sh` le dérive du fichier
d'écran. Sans extension, sans le préfixe `activity_`, sans le suffixe `Activity`, en
minuscules. `04-creation` couvre `activity_creation.xml` comme `CreationActivity.kt`. Un
préfixe numérique donne l'ordre de lecture.

## Ce qu'on adapte

- Le paquet, dans la constante `PAQUET`, le même que le réglage.
- La ligne de `preparerSession()` qui écrit le jeton là où l'app le lit.
- Les activités ouvertes, les identifiants de vues attendus, les identifiants tapés.
- Les libellés des boutons qui ferment les boîtes de l'app, dans `ecarterDialogue()`.
- Les noms de captures, et le nombre de tours de la boucle de rebascule.

## Ce qu'on ne touche pas

- **`photographier()`**, avec sa seconde tentative et sa ligne de journal. Une capture qui
  échoue en silence est un écran qu'on croit avoir regardé.
- **Le `finally` qui envoie `SIGINT` à `screenrecord`, puis attend le fil.** Sans lui, le film
  n'est jamais fermé. Dans un `finally`, sinon une assertion tombée le saute.
- **`ecarterDialogue()` avant chaque geste ET avant chaque photo.** Une boîte peut s'ouvrir
  après le tap qui l'a déclenchée.
- **`attendreEcran()` avant chaque photo d'un écran natif.** Une capture prise 600 ms après le
  geste montrait l'écran d'avant.
- **`taper()` qui renvoie faux sans faire tomber le test.** Un écran qui tarde doit se voir sur
  les images, pas planter le run.

## Ce que le projet d'origine a retiré, et pourquoi

Deux tests n'ont pas été portés dans le gabarit. Un test du clavier, ignoré chez lui parce que
sa prémisse était fausse, le champ visé étant désactivé au moment du tap. Un test de fenêtre
surgissante, propre à son mécanisme de fenêtres multiples.

Un projet qui en a besoin les écrit
sur le même contrat. Chaque étape s'assure de son effet, sinon le test tombe au lieu de
photographier autre chose.
