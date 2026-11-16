# La grille de synthèse

Ce fichier gouverne la phase 4. Il fixe l'ordre de la lecture, puis les blocs de l'artefact de
sortie. Le lecteur est l'admin, qui connaît son app et n'a vu aucun testeur.

## La lecture, dans cet ordre

1. **La sortie du lanceur.** Un testeur sans rapport se nomme d'abord, avec sa panne.
2. **Chaque bilan**, `testeur-<n>/bilan.json`. Le rapport, le coût, et les refus de permission.
3. **Chaque journal**, `testeur-<n>/journal.jsonl`, geste par geste, avec sa capture ouverte. Le
   rapport dit ce que le testeur a retenu. Le journal dit ce qu'il a vécu, et les deux
   divergent parfois.
4. **Le parcours de la phase 1**, `parcours.json`.

## Ce que la lecture produit

**Le chemin de chaque testeur sur le parcours.** Chaque capture se rattache à l'écran du
parcours qu'elle montre. Une capture qu'aucun écran ne décrit est un écart du parcours, à
signaler comme tel.

**Les problèmes, regroupés.** Deux frictions sont un même problème si elles montrent le même
écran et la même cause. Chaque problème porte ces champs.

- Le nombre de testeurs touchés, sur le total.
- La gravité la plus haute rapportée.
- Une capture, et le commentaire du testeur cité mot pour mot.
- L'écran du parcours où il se trouve.

**Ce qu'aucun testeur n'a atteint.** Les écrans du parcours sans aucune capture. Ce n'est pas un
défaut en soi. C'est la part de l'app que ce run n'a pas jugée.

**L'écart de compréhension.** Ce que promet la fiche, face à ce que chaque testeur a compris
au premier écran, puis à la fin.

## Les blocs de l'artefact, dans cet ordre

1. **Le verdict**, en une phrase. Combien de testeurs ont compris l'app, combien ont abandonné.
2. **Les problèmes**, triés par testeurs touchés, puis par gravité. Capture et citation pour
   chacun.
3. **Le logigramme de la phase 1**, coloré. Un écran atteint par tous, par certains, par aucun.
   Une marque là où un testeur a abandonné.
4. **La compréhension**, la fiche face aux phrases des testeurs.
5. **Ce qui marche**, les points forts cités par plusieurs testeurs.
6. **Chaque testeur**, son fil de captures avec le commentaire de chaque geste, replié par
   défaut.
7. **Ce qui n'a pas pu être jugé.** Testeurs sans rapport, écrans jamais atteints, refus de
   permission, coût total du run.
8. **La limite du test**, en une ligne. Des modèles et non des humains, qui sous-estiment la
   confusion d'une personne pressée.

Les captures se publient avec la page, par ses fichiers joints, jamais par un chemin local.

## Ce que la synthèse ne fait pas

**Elle ne corrige rien.** Un problème trouvé se range dans le backlog du projet, si l'admin le
demande après lecture.

**Elle n'invente aucune cause.** Le testeur dit ce qu'il a vécu. Une cause dans le code se
cherche après, et s'écrit séparément du constat.
