# Le gabarit du rapport de parcours

> Ce fichier fait foi sur la forme du rapport que rend l'étape 5 de
> [`../SKILL.md`](../SKILL.md). Le fond, ce qu'on regarde et ce qui vaut refus, vit dans
> [`grille-de-jugement.md`](grille-de-jugement.md).

## La forme

Le rapport se rend en session, il n'écrit aucun fichier. Six blocs, dans cet ordre, sans en
sauter. Un bloc vide dit qu'il est vide.

**Le verdict, en une ligne.** Un mot parmi trois, puis le run et la mouture.

- **Accepté**, tout est vu et rien ne cloche.
- **Refusé**, avec le premier motif.
- **Non jugé**, la machine était malade, les images ne veulent rien dire.

**La santé de la machine.** Ce que `--sante` a dit, charge comprise.

**Les trois verdicts mécaniques.** Verdict, film, captures attendues, tels que le relevé les
donne.

**Les défauts vus, écran par écran.** Une ligne par défaut, avec le nom du fichier qui le
montre. Un défaut vu sur le film porte l'horodatage de l'image.

**Ce qui n'a pas pu être jugé, et pourquoi.** Une maquette absente, une image illisible, une
mouture sans journal.

**Le symptôme si la lecture est fausse.** Une phrase, « si ma lecture est fausse, voilà ce que
tu verras ». L'admin invalide en cinq secondes ce qu'un test vert ne verra jamais.

## Un exemple

**Refusé**, run 46, mouture debug. La capture `03-second.png` montre l'écran premier.

**Santé.** Machine saine, charge maximale 3,2.

**Mécanique.** Verdict vert, film regardable, 74 s pour un parcours de 71 s. Captures attendues
toutes présentes.

**Défauts.**

- `03-second.png` montre la liste de l'écran premier, pas le second. L'onglet a été tapé, la
  photo est partie avant le rendu, ou l'onglet n'a pas répondu.
- `film/scene-000041.png`, à 38 s, un bandeau « Viewing full screen » couvre le tiers haut. Il
  disparaît à 52 s. Aucune capture ne le montre.

**Non jugé.** Pas de maquette pour `04-creation`, conformité non jugée.

**Si ma lecture est fausse**, tu ouvriras `03-second.png` et tu y verras bien le second écran,
avec son titre en haut.
