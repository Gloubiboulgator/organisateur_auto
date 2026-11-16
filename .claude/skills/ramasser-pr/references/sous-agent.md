# Le sous-agent et la session

> Ce fichier porte le relais entre le sous-agent qui mène le run et la session qui fusionne,
> pour [`../SKILL.md`](../SKILL.md). Le refus du harnais vit dans [`fusion-admin.md`](fusion-admin.md).

**Le run se mène dans un sous-agent.** La session qui reçoit la commande ne relit rien
elle-même. Elle lance un sous-agent, lui passe ce skill et l'argument, puis attend. Relevé,
revues, corrections, vérifications, rangement, bilans et questionnaire se font chez lui. Le run
des réponses, qui part sur « c'est rempli », suit le même relais.

**Le sous-agent sans `/code-review` rend la main tout de suite.** Il n'a rien touché. La session
mène alors le run elle-même, comme avant ce relais, et le rendu le dit.

**La phrase d'ouverture sort de la session**, avant qu'elle lance le sous-agent. La liste des
demandes sort du sous-agent au relevé. Il rend la main avec elle, la session l'affiche telle
quelle, puis le relance pour mener le lot.

**La fusion reste à la session.** C'est elle qui porte la commande de l'admin. Le sous-agent ne
tente jamais une fusion. À l'étape 4, il rend la main avec la demande et sa tête vérifiée.

> Décidé par l'admin le 2026-10-27. Le ramassage part dans un sous-agent, et une revue faite
> vaut son accord de fusion. Observé le même jour, le harnais a refusé la fusion au sous-agent,
> « Merge Without Review ». Il l'a laissée passer depuis la session où l'admin avait écrit son
> accord.

**Que la commande seule suffise au harnais n'est pas observé.** Ce jour-là, l'accord était
écrit en toutes lettres dans la session. Un refus garde donc sa règle, et la commande de fusion
va à l'admin.

**Le relais suit un ordre fixe.**

1. Le sous-agent rend la main avec une ligne, « Prête à fusionner : #NN, tête `<sha complet>` ».
2. La session vérifie que la tête distante est bien celle-là.
3. Elle fusionne par la commande de [`fusion-admin.md`](fusion-admin.md).
4. Elle relance le même sous-agent avec le résultat, « fusionnée » ou « refusée », motif cité.

**La troisième revue passe aussi par la session.** Le sous-agent rend la main avec une ligne.

```
Troisième revue : #NN, tête <sha complet>, dossier <chemin du clone>
```

La session vérifie que la tête distante est bien celle-là, comme avant une fusion. Elle lance ensuite l'agent que décrit
[`tri-des-constats.md`](tri-des-constats.md), puis relance le sous-agent avec son résultat.

**Le rangement de fin de run passe aussi par la session.** Le sous-agent ouvre sa demande, prête,
puis rend la main avec une ligne.

```
Rangement à fusionner : #NN, tête <sha complet>
```

La session vérifie la tête, et fusionne sans revue par la même commande. C'est un simple ajout à
la roadmap, que le `CLAUDE.md` fait fusionner par la session qui l'écrit. La session relance
ensuite le sous-agent avec le résultat, pour le rendu.

**Un refus du harnais le laisse prêt**, avec sa commande et son bilan, cause fusion à l'admin. Le
run suivant ne le relit donc pas. Un refus déjà subi dans le run vaut pour lui : le sous-agent
pose ce bilan sans rendre la main pour la fusion.

> Incident fondateur. Le 2026-10-30, trois demandes de rangement attendaient en brouillon, la
> plus ancienne depuis la veille. Le skill les ouvrait en brouillon, et un run sans argument
> n'en prend aucun. La règle du `CLAUDE.md` du 2026-10-27 n'avait pas été reportée ici.

**L'état du run voyage avec lui.** Chaque fois qu'il rend la main, il joint le lot restant.
Il y ajoute les revues passées par demande, un refus du harnais déjà subi, les constats à ranger.
Si le même sous-agent ne peut pas reprendre, la session en lance un neuf avec cet état, et il
repart de la demande suivante.

**Après une troisième revue, l'état porte aussi le dossier**, les commits de l'agent pas encore
poussés et ses constats non corrigés. Le sous-agent neuf reprend alors la même demande, et
pousse d'abord ces commits.

**La branche fusionnée se supprime côté session.** La commande de
[`fusion-admin.md`](fusion-admin.md) le fait d'elle-même. Une fusion faite autrement est suivie
de la suppression, par la session. Le sous-agent n'y touche pas.

**Le rendu de fin vient du sous-agent, et la session le relaie tel quel.** Avant, elle relit
l'état de chaque demande annoncée fusionnée. Un écart avec le rendu se dit en tête.
