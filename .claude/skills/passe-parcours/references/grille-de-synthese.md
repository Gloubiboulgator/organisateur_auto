# La grille de synthèse

Ce fichier gouverne la phase 4. Il fixe l'ordre de la lecture, puis les blocs de l'artefact de
sortie. Le lecteur est l'admin, qui connaît son app et n'a vu aucun testeur.

## La lecture, dans cet ordre

1. **La sortie du lanceur.** Un testeur sans rapport se nomme d'abord, avec sa panne.
2. **Les réglages du run**, `reglages.json` de chaque plateforme. Un appui humain éteint change
   ce que les captures prouvent. Sans flou, le testeur a tout lu. Sans doigt imprécis, un bouton
   raté ne peut venir de sa taille. `temperaments_par_rang` dit le tempérament de chaque testeur.
3. **Chaque bilan**, `testeur-<n>/bilan.json`. Le rapport, le coût, et les refus de permission.
4. **Chaque journal**, `testeur-<n>/journal.jsonl`, geste par geste, avec sa capture ouverte. Le
   rapport dit ce que le testeur a retenu. Le journal dit ce qu'il a vécu, et les deux
   divergent parfois. Le testeur n'a vu que des coups d'œil flous, dans `captures/`. Les
   captures nettes du même numéro vivent dans `nettes/`. Un geste `lire` est une lecture. Sa
   capture dans `captures/` est la zone lue, nette, et le journal porte ses coins.
   `vise` et `touche` disent où le doigt visait et où il est tombé. `pose` dit en combien de
   secondes l'écran s'est posé. `"vide"` dit qu'il est resté vide jusqu'au bout de l'attente,
   `pose.max` des réglages, `"bouge"` qu'il bougeait encore. Sans mesure de la pose, le champ
   manque.
   `double` dit que le testeur a retouché un écran qui ne réagissait pas. Un double envoi se
   cherche sur la capture suivante. `voulu` et `tape` disent le texte visé et celui qui est parti
   avec ses fautes. `interruption` dit que l'app est passée en arrière-plan avant la capture.
5. **Le parcours de la phase 1**, `parcours.json`.

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
- Si le testeur avait lu la zone qui l'explique, par un geste `lire`.
- Si son doigt a manqué le bouton visé, d'après `vise` et `touche`. Un raté sur un petit bouton
  est un problème de taille de cible, pas de compréhension.
- La durée de pose, quand le testeur se plaint d'une lenteur. Un `"vide"` sur une capture nette
  qui montre un écran posé presque nu est une limite du pilote, pas une lenteur de l'app.
- Une solution proposée, ce qui changerait à l'écran pour que le testeur s'en sorte. Deux
  pistes, quand les champs ne départagent pas deux causes.

**Chaque problème vu propose une solution.** Un constat seul laisse l'admin refaire l'analyse.
La solution se tire de la capture, du commentaire et des champs ci-dessus, jamais du code.
Elle dit ce qui change pour qui utilise l'app, un libellé, une place, une taille ou une étape.

**Une limite du pilote n'est pas un problème de l'app.** Elle ne reçoit aucune solution. Elle
va au bloc « Ce qui n'a pas pu être jugé », jamais parmi les problèmes.

**La solution s'écrit à part du constat**, sous « Proposé ». L'admin distingue ainsi ce qu'un
testeur a vécu de ce que la synthèse suggère.

> Décidé par l'admin le 2026-11-23 : « chaque problème vu doit proposer une solution ».

**Ce qu'aucun testeur n'a atteint.** Les écrans du parcours sans aucune capture. Ce n'est pas un
défaut en soi. C'est la part de l'app que ce run n'a pas jugée.

**L'écart de compréhension.** Ce que promet la fiche, face à ce que chaque testeur a compris
au premier écran, puis à la fin.

## Les blocs de l'artefact, dans cet ordre

1. **Le verdict**, en une phrase. Combien de testeurs ont compris l'app, combien ont abandonné.
   Dessous, une ligne nomme les réglages du run qui s'écartent des défauts, ou dit qu'il n'y en a
   aucun.
2. **Les problèmes**, triés par testeurs touchés, puis par gravité. Capture, citation et solution
   proposée pour chacun.
3. **Le logigramme de la phase 1**, coloré. Un écran atteint par tous, par certains, par aucun.
   Une marque là où un testeur a abandonné.
4. **La compréhension**, la fiche face aux phrases des testeurs.
5. **Ce qui marche**, les points forts cités par plusieurs testeurs.
6. **Chaque testeur**, son fil de captures avec le commentaire de chaque geste, replié par
   défaut. Le fil montre les captures nettes. Une lecture y montre la zone lue, prise dans
   `captures/`.
7. **Ce qui n'a pas pu être jugé.** Testeurs sans rapport, écrans jamais atteints, limites du
   pilote, refus de permission, coût total du run.
8. **La limite du test**, en une ligne. Des modèles et non des humains, qui sous-estiment la
   confusion d'une personne pressée.

Les captures nettes se publient avec la page, par ses fichiers joints, jamais par un chemin
local. L'admin juge l'écran, pas le flou que voyait le testeur.

## Ce que la synthèse ne fait pas

**Elle propose, elle ne corrige rien.** Si l'admin le demande après lecture, un problème trouvé
se range dans le backlog du projet. Sa solution proposée l'accompagne, comme une piste à
trancher. Elle ne vaut ni décision de l'admin ni maquette validée.

**Elle n'invente aucune cause dans le constat.** Le testeur dit ce qu'il a vécu. Une cause dans
le code se cherche après, et s'écrit séparément du constat.

**La cause d'une solution est une hypothèse.** Sous « Proposé », chaque piste nomme la cause
d'écran qu'elle suppose. Ce peut être une cible trop petite, un libellé ou un ordre. Quand les
champs ne départagent pas deux causes, chaque piste dit la sienne.
