# Quand le harnais refuse la fusion

> Ce fichier porte la règle de la demande que le harnais retient, pour [`../SKILL.md`](../SKILL.md).
> Le skill dit quand le refus arrive et ce qu'il arrête. La forme du rendu vit dans le
> [gabarit](gabarit.md).

Une demande sortie propre de la revue et de la vérification peut voir sa fusion refusée par le
harnais. Elle reste prête, cause fusion à l'admin, et attend que l'admin lance sa commande.

## La demande qui attend ta fusion

**Une demande qui attend ta fusion ne se relit pas, même nommée**, tant qu'aucune des deux
têtes de son bilan n'a bougé. Sa revue et sa vérification tiennent encore, et sa commande
ressort telle quelle.

**Seule la principale a bougé : pas de revue.** Le run fusionne la principale à jour dans sa
branche et relance la vérification. Sa commande ressort sur la tête neuve. Une revue n'a lieu
que si cette fusion a demandé de trancher un conflit. Après la dernière revue, c'est une revue
courte, comme le dit l'étape 4 du skill.

> Décidé par l'admin le 2026-10-22. Deux revues à chaque mouvement de la principale finissaient
> au même point, une commande à lancer, puisque le harnais refuse encore.

**Une approbation arrivée sur GitHub la fait revenir.** Le run la reprend comme au paragraphe
précédent, puis la rend à la session.

## La commande de fusion

**La commande de fusion se donne prête à lancer**, dans un bloc `bash`. Elle épingle la tête
vérifiée, en entier, et supprime la branche distante. Sa forme vit dans le [gabarit](gabarit.md).

**`--repo` nomme le dépôt, `propriétaire/nom`.** La commande ne dépend alors d'aucun dossier,
et ne commence par aucun `cd`. La règle des commandes de
[`../../../rules/ton-des-echanges.md`](../../../rules/ton-des-echanges.md) le permet depuis le
2026-10-22. Le skill ne voit pas le clone de l'admin, et n'invente pas son chemin.

**gh laisse aussi la branche locale**, qu'un worktree tient souvent. Sans `--repo`, il échoue
sur elle après la fusion, et la distante reste.

> Incident fondateur. Une commande de fusion donnée sans dossier a été lancée depuis le terminal
> d'un autre projet. Elle y a visé la demande du même numéro, et supprimé sa branche.

**Plusieurs commandes s'enchaînent sur une seule ligne**, dans l'ordre du rendu. Chacune ne part
que si la précédente a réussi, et les suivantes attendent le run d'après. Chacune épingle sa
demande, pas la branche principale, que la première fusion fait bouger. Leur combinaison n'est
donc pas vérifiée, et le rendu le dit sous le bloc.
