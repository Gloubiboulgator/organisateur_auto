# Comment on prouve un garde-fou candidat

À lire à l'étape 4, une fois la mécanique choisie. Un garde-fou décrit mais jamais exécuté n'est
pas un garde-fou, c'est une intention. Ce fichier dit comment le faire tourner sans rien écrire
dans le dépôt.

## Où ça vit, et ce qui est interdit

Tout vit dans le **répertoire temporaire de session**, en chemins absolus. Le contrôle candidat
dans `candidat/controle.py`, les cas de test dans `cas/`.

Interdits explicites, sans exception :

- toute écriture sous la racine du dépôt
- `git worktree add`, `git stash`, `git checkout`, `git reset`

L'audit des gardes a muté un worktree jetable, et c'était légitime, parce qu'il
avait le droit d'écrire. Ce skill ne l'a pas. **On mute une copie**, jamais l'original. Les deux
outils de mesure du dépôt acceptent un chemin absolu, donc on les pointe où l'on veut.

## Le budget, et ce qu'il veut dire quand il craque

Le contrôle candidat tient en une **soixantaine de lignes**, sans dépendance nouvelle. Bash et
grep, ou Python de la bibliothèque standard. C'est la contrainte que le dépôt s'impose partout.

Si le contrôle ne tient pas dans ce budget, **c'est un résultat, pas un échec**. On l'écrit, et
on déclare la mécanisation déraisonnable pour ce cas. Un contrôle qu'on ne peut pas relire est
un contrôle que personne ne corrigera le jour où il se trompera.

## Les cas, avec leurs quotas

Deux familles, et les quotas comptent. Sans eux, on produit deux cas polis qui passent tous.

**Au moins trois cas trop restreints.** La même dérive sous une autre forme, que le garde-fou
laisserait passer. Ceux-là s'inventent, c'est leur rôle.

**Au moins trois cas légitimes.** Et ceux-là **ne s'inventent pas**. On les tire du dépôt réel,
par recherche, parmi les lignes qui ressemblent à la faute sans en être une. Un cas légitime
inventé ne prouve rien. Un vrai cas du dépôt prouve que le contrôle ne casse pas le travail
existant.

## Les trois exécutions, dans cet ordre

L'attendu s'écrit **avant** de lancer. Sinon on lit le résultat à l'envers.

**1. Le cas fondateur doit rougir.** On reconstruit le fragment fautif en copie. Si le contrôle
candidat ne rougit pas dessus, il n'existe pas, et rien d'autre ne mérite d'être regardé. C'est
la seule exécution dont l'échec arrête tout.

**2. Les cas légitimes restent verts.** Le moindre rouge ici veut dire trop large. On ajuste
avant d'aller plus loin, et on note l'ajustement.

**3. La passe sur tout le dépôt**, en lecture seule, sur le vrai périmètre. Elle coûte quelques
secondes sur tout le périmètre suivi. Il n'y a aucune excuse à la sauter.

## Lire le résultat de la passe

Écrit d'avance, parce qu'un résultat se lit toujours dans le sens qui arrange.

| Ce qu'on voit | Ce que ça veut dire |
|---|---|
| zéro rouge | suspect, pas rassurant. Revérifier que l'exécution 1 rougit bien avant de conclure |
| quelques rouges | c'est la liste à corriger, et le prix d'entrée du garde-fou. Elle part telle quelle dans la proposition, fichier et ligne |
| beaucoup de rouges | soit le garde-fou est trop large, soit le dépôt porte une vraie dette. Trancher, et le dire |

**La sortie interdite est d'ajouter une liste d'autorisés.** Le dépôt a tranché l'inverse deux
fois. Une liste d'exclus qui ne fait que rétrécir, et un fichier neuf qui naît conforme.

## Ce que la passe déclenche ensuite

Les findings de la passe ne restent pas dans la conversation. Ils deviennent un **item de
registre**, rédigé au format d'un item de roadmap. L'étalon de rédaction possède ce format.

On le propose au registre, à l'horizon **Maintenant**, puis au plan quand le projet en tient
un. Décision de l'admin.

Ce bloc est prêt à coller. Le skill ne l'écrit nulle part avant la validation de l'étape 6.

## Le verdict

Il tranche, en un mot, et il porte sa raison.

- **PRÊTE** quand les trois exécutions ont tourné, et que la liste d'impact est connue.
- **PAS PRÊTE** dans tous les autres cas, y compris quand la passe n'a pas pu tourner.

Un garde-fou qui ne porte sur rien de vérifiable dans le dépôt ne peut pas exécuter la passe. Le
dire, et pourquoi. Ne pas inventer une recherche qui ne veut rien dire pour remplir la case.
