# La grille de jugement d'un parcours

> Ce fichier fait foi sur ce que le juge regarde, dans quel ordre, et sur ce qui vaut refus. Le
> juge est la session Claude Code qui exécute `/apk-test`. Elle lit les images elle-même.

## L'ordre, et pourquoi il compte

1. **Le relevé du script**, `scripts/rapatrier-parcours.sh`. Une machine malade ou un verdict
   rouge se rapporte en premier, et le jugement des images ne prétend alors pas juger l'app.
   Une bande noire se raconte aussi bien comme un défaut de mise en page que comme une barre
   système morte. Seule la seconde lecture était la bonne au run 31967863064.
2. **Les captures nommées**, une par une, dans l'ordre de leur préfixe, avec l'outil de lecture
   d'images de la session.
3. **Les images tirées du film**, dans l'ordre du temps, dossier `film/` de la mouture.
4. **La maquette**, si le réglage `MAQUETTES` nomme un dossier et qu'une maquette porte le nom
   de l'écran. Le relevé du script dit ce dossier, et dit s'il est introuvable.

## Ce qu'on cherche sur une capture

- **Le bon écran.** Une capture nommée messagerie qui montre les annonces est un cafouillage
  de navigation, ou une photo partie trop tôt.
- **Un dialogue ou un bandeau le recouvre-t-il ?** Une boîte de permission, une proposition de
  l'app, un « Viewing full screen ». Le parcours s'est alors figé sans que rien ne le dise.
- **Une zone noire ou vide ?** En haut ou en bas, c'est une barre système morte, à recouper avec
  la santé de la machine. Au milieu, c'est un écran pas encore dessiné.
- **Un indicateur de chargement ?** L'écran n'était pas rendu quand la photo est partie.
- **Le clavier, s'il devait être là, l'est-il ?** Et l'inverse.

## Ce qu'on cherche sur les images du film

Ce qui vit **entre** deux captures. Un bandeau système a couvert le tiers haut de l'écran
pendant quinze secondes au run 31509968766, invisible sur toutes les photos. Un écran de
chargement qui s'éternise, un flash blanc à une transition, un retour au bureau d'Android.

Les images de scène marquent les changements. Les images plancher, une toutes les quelques
secondes, attrapent ce qui ne bouge pas. Une image plancher identique à la précédente pendant
longtemps est soit un écran stable, soit un parcours figé : le relevé des captures dit lequel.

## La maquette

Quand elle existe, l'écran visible doit lui correspondre, et pas seulement être le bon écran.
Quand elle n'existe pas, la grille le dit : « pas de maquette pour cet écran, conformité non
jugée ». Ne jamais juger la conformité de mémoire.

## Ce qui vaut refus

- Une machine malade. Le rapport dit « non jugé », jamais « refusé pour tel défaut de l'app ».
- Un verdict mécanique rouge.
- Une capture qui montre un autre écran que son nom.
- Un dialogue ou un bandeau sur une capture ou sur une image du film.
- Une capture attendue absente.
- **Une image que le juge ne sait pas interpréter.** Elle se rapporte comme telle, jamais comme
  un succès. Le doute vaut échec, c'est la règle de toute l'échelle.

## Ce qui vaut avertissement

- Une machine lente, charge au-dessus du seuil sans dégât constaté.
- Un film qui couvre moins des deux tiers du parcours.
- Une capture partie tôt, écran reconnaissable mais pas encore complet.

## Ce que le juge ne fait pas

Il n'écrit aucun fichier, ne modifie aucune ligne du projet, ne rejoue aucun run. Il rend le
rapport de [`gabarit-rapport-parcours.md`](gabarit-rapport-parcours.md), et s'arrête.
