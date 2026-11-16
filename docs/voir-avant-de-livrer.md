# Voir avant de livrer

> **Nature du document.** Règles de méthode, nées des défauts d'une première livraison. Ce
> fichier les possède. Leur part opérationnelle est chargée à chaque session depuis
> `.claude/rules/voir-avant-de-livrer.md`. Elles vivent ici parce que le fichier d'instructions
> a atteint sa longueur cible.

## Le constat

Le premier jeu jouable d'un projet équipé partait au vert sur toute la ligne. Deux lints, les
tests, une passe parcours et une revue à six relecteurs, dont tous les constats étaient corrigés.

Le même soir, en dix minutes de jeu, l'admin y a relevé une vingtaine de défauts. Le filet avait
tenu sur tout ce qu'il mesurait. Rien ne mesurait ce que l'admin a vu.

## Les règles

<!-- sync:voir-avant-de-livrer -->
**Une maquette approuvable est complète**. Chaque écran se dessine sur téléphone et sur
ordinateur, avec ses états et la carte de navigation. Ses contrastes se mesurent, au moins 3 pour
1 pour un élément graphique. L'approbation se fait écran par écran, jamais en bloc.

**Aucune génération d'images payante avant une composition approuvée**. L'écran se compose et
s'approuve d'abord. Ses pièces se fabriquent ensuite.

**La recette ne se retire jamais**. La recette est une passe où l'on se sert du produit comme un
utilisateur, avant de le dire prêt. Un lot mené sans point d'arrêt la garde, et finit par une
courte démonstration à l'admin. Le régime se redemande à chaque lot.

**Rien n'est « prêt » sans avoir été vu**. « Prêt », « livré » ou « à montrer » ne s'écrivent
qu'avec un rapport de recette nommé. Décrire ce qu'un écran montre exige d'avoir ouvert sa
capture.

**Une affirmation de relevé porte sa preuve**. Dans une note, « gardé », « corrigé » ou « livré »
cite le test ou la capture qui le montre.

**« À remettre à la file » se range dans le même commit**. La mention lie l'item de roadmap ou de
backlog qui la reprend. Un mot dans un relevé ne range rien.

**Mesurer avant de committer**. Un texte long, une page ou plus, passe par
`bash scripts/doc-lint.sh` avant son commit, pas après le refus du hook. Un texte court va droit
au commit, dont le hook fait le même contrôle.

**Un skill du noyau vérifie d'abord sa fraîcheur**. Avant de le suivre, l'agent lance
`bash scripts/verifier-noyau.sh .`. Il dit à l'admin tout retard annoncé.

**Un service externe s'observe avant sa mise en service**. Son premier appel réel se fait en
diagnostic, et la réponse brute se garde. Chaque `@suppose` sur un service payant a son canari,
lisible dès ce premier appel.
<!-- /sync:voir-avant-de-livrer -->

## Les incidents qui les ont fait naître

> La maquette. Vingt-huit écrans approuvés en un bloc portaient eux-mêmes des défauts. Aucun ne
> montrait l'envoi en cours ni le retour arrière, et deux seulement le téléphone. Une légende peu
> contrastée venait de la maquette.

> La dépense. Deux jours de suite, 39 puis 145 générations d'images payantes sont parties avant
> que l'écran soit composé.

> La recette. Le lot n'avait que deux points d'arrêt, l'approbation du plan et la revue finale.
> Rien n'imposait de jouer au jeu comme un joueur avant de le mettre en service.

> Le « prêt ». L'agent a écrit « prêt à montrer » sans avoir ouvert un seul écran. Seuls le
> serveur et la page d'accueil avaient répondu.

> La preuve. Le relevé des décisions affirmait « gardée » une phrase d'accueil que le code
> n'avait pas.

> La file. Deux points notés « à remettre à la file » ne sont entrés dans aucun registre, et l'un
> s'est perdu.

> La mesure. Quatre commits ont été refusés d'affilée par le lint, pour des phrases trop longues
> et des liens manquants.

> La fraîcheur. Un rapport de reprise a suivi l'ancienne version de son skill, le noyau n'ayant
> pas été mis à jour avant.

> Le service. Les croyances sur un fournisseur n'avaient jamais été observées, et aucun appel de
> diagnostic n'était prévu. Le premier soir, la cause de douze échecs est restée inconnue.

## Ce que ces règles ne font pas

Elles ne bloquent rien. Le registre de la roadmap du noyau porte leurs mécaniques à venir.

La neuvième proposition est écartée, « la demande se prend au pied de la lettre ». La section
« Un changement ne contient que la demande » du fichier d'instructions la couvre déjà.
