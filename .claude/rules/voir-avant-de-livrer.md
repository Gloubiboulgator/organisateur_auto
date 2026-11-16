# Voir avant de livrer

Le propriétaire de ces règles est [`../../docs/voir-avant-de-livrer.md`](../../docs/voir-avant-de-livrer.md).
Le bloc ci-dessous en est la part opérationnelle, partagée et vérifiée identique.

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
