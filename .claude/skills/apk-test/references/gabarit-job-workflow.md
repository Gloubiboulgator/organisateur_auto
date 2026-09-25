# Le gabarit du job de workflow

> Ce fichier fait foi sur la façon de brancher [`job-tester.yml`](job-tester.yml) dans le
> workflow du projet. Le job lui-même porte le pourquoi de chaque étape, en commentaire.

## Ce que le job attend en amont

Un artefact portant deux paquets par mouture, produits par un job de compilation.

- L'app, `*-<mouture>.apk`.
- Son robot de test, `*androidTest*<mouture>*.apk`, compilé par la tâche
  `assembleAndroidTest` de Gradle avec le même type de build.

Le gabarit nomme le job amont `compiler` et l'artefact `couples-test`. Les deux s'adaptent.

## Ce que le job produit

Un artefact, `parcours` dans le gabarit, publié même quand les tests échouent. Il contient par
mouture les captures, le film et un dossier de traces, plus les journaux `resultat-<mouture>.txt`
et `logcat-<mouture>.txt`, et la liste `echecs.txt`. C'est ce que
`scripts/rapatrier-parcours.sh` télécharge.

## Comment le brancher

1. Copier le bloc `tester:` sous `jobs:` du workflow, en gardant l'indentation.
2. Adapter `needs`, le nom de l'artefact téléchargé, le nom de l'artefact publié.
3. Poser le secret `TEST_APP_TOKEN`, le jeton d'un compte de test dédié, jamais celui de
   l'admin. Sans lui, l'app reste à l'écran d'accueil et l'artefact ne contient qu'une image.
4. Laisser le bloc `script:` sur une ligne. L'action le découpe ligne par ligne.
5. Laisser `fetch-depth: 0`. Sans historique, le contrôle des captures ne compare à rien.

## Ce que le gabarit ne porte pas

Le projet d'origine y ajoutait un laissez-passer par étape, un petit fichier disant ce que
l'étape a produit, dont l'absence vaut échec pour la suivante. Et un rejeu réseau derrière un
mandataire local. Ni l'un ni l'autre ne vaut pour tout projet. Un projet qui enchaîne plusieurs
étapes reprendra l'idée du laissez-passer : une preuve qui ne s'écrit que sur succès.

## Le coût

Une douzaine de minutes de machine par run chez le projet d'origine, le job le plus lent de sa
chaîne. Il ne tourne que sur décision, jamais sur un push. Un build engage un numéro de version
et des minutes comptées.
