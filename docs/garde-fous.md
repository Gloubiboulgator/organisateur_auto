# Ce qui protège ce projet, et contre quoi

Ce fichier recense les garde-fous. Une seule question compte quand une erreur se reproduit.
**Est-ce qu'un garde-fou couvrait déjà ce cas, et pourquoi n'a-t-il pas tenu ?** Sans registre,
personne ne peut y répondre.

## Comment ça s'utilise

Trois usages, dans l'ordre de fréquence.

**Avant de proposer une règle de plus.** On cherche ici si le cas est déjà couvert. Si une règle
existait et n'a pas tenu, la réponse n'est pas d'en écrire une deuxième. C'est de dire pourquoi
elle n'a pas tenu, et de la mécaniser.

**Pour savoir ce qui bloque vraiment.** La colonne *régime* sépare ce qui refuse un geste de ce
qui se contente d'avertir. Un garde-fou qui avertit ne retient rien tout seul.

**Pour situer un garde-fou neuf.** La colonne *mécanique* nomme les huit familles disponibles. On
en choisit une plutôt que d'inventer une neuvième.

## Les huit mécaniques

| Mécanique | Régime | Ce qu'elle coûte à poser |
|---|---|---|
| contrôle `doc-lint` | refuse le commit | le contrôle, plus sa ligne dans la table du système documentaire |
| contrôle `code-lint` | refuse le commit | le contrôle, parfois un script à part |
| filet dans un hook git | refuse le commit, la fusion ou le push | du bash dans `scripts/githooks/` |
| étiquette plus fiche | refuse le commit | le patron, la fiche, le contrôle qui les relie |
| liste de dette qui rétrécit | refuse le commit | trois contrôles solidaires, jamais un seul |
| hook d'agent | refuse l'appel d'outil | un script sans dépendance externe, plus sa pose |
| angle d'audit périodique | signale seulement | une ligne de configuration, plus sa table d'objets |
| règle écrite | rend la faute constatable | du texte, et rien qui la fasse respecter |

Les deux dernières ne bloquent rien, et c'est assumé. Un jugement qui dépend du contexte ne se
mesure pas. Le prétendre produirait un contrôle qui se contourne ou qui gêne.

## Les trois principes de conception

Ils traversent les huit mécaniques, et ce sont eux qui coûtent le plus cher à réapprendre.

**Une liste d'exclus qui ne fait que rétrécir**, jamais une liste d'autorisés. Un fichier neuf
naît alors conforme, sans geste à penser. Une liste d'autorisés fait l'inverse, et un fichier
neuf y entre en dehors de toute vérification.

**Un contrôle qui plante doit crier**, jamais se taire. Un contrôle jugé sur sa seule sortie
comptait vert quand il levait une erreur, sa trace partie sur la sortie d'erreur.

**Un garde qui surveille un outil échoue ouvert.** S'il plante, il bloquerait l'outil surveillé,
donc toute la session. Bash et grep seuls, ou Python de la bibliothèque standard, sortie en
zéro sur tout chemin inattendu.

## Le registre

### Les contrôles du doc-lint

Leur liste vit dans [`systeme-documentaire.md`](systeme-documentaire.md), qui en est le
propriétaire. La recopier ici créerait une deuxième vérité, et obligerait à deux mises à jour
pour un seul ajout.

### Les contrôles du code-lint

| clé | ce qu'il attrape | régime |
|---|---|---|
| `code-lint:1` | une assertion de test qui ne décide rien | refuse le commit |

### Les hooks git

| clé | ce qu'il attrape | régime |
|---|---|---|
| `githooks/pre-commit` | une doc ou un code qui dérive, par les deux lints | refuse le commit |
| `githooks/pre-push` | ce que l'amont a touché, et un arbre sans témoin de contrôle local | avertit, refuse sans témoin |
| `githooks/pre-merge-commit` | la même chose, sur une fusion | refuse la fusion |

### Les gardes d'agent

Ils se déclarent dans le `.claude/settings.json` **versionné**, avec un chemin en
`${CLAUDE_PROJECT_DIR}`. Le fichier suit donc le clone, et aucun geste d'installation n'est
nécessaire. Un settings personnel, hors dépôt, ferait l'inverse. Les gardes n'y existeraient pas
tant que personne ne les y pose, et manqueraient en silence sur une machine neuve.

Le **`SessionStart`** est la pièce qui compte le plus. Il repose `core.hooksPath` et `merge.ff`
au démarrage de chaque session. Sans lui, une session fraîche n'a aucun contrôle, et rien ne le
signale. C'est vérifié en session cloud, où les hooks qu'il pose refusent bien les commits
fautifs.

Tous **échouent ouverts**. Un garde qui plante bloquerait l'outil qu'il surveille, donc toute la
session. Bash et grep seuls, ou Python de la bibliothèque standard, sortie en zéro sur tout
chemin inattendu.

| clé | ce qu'il attrape | régime |
|---|---|---|
| `scripts/garde-arriere-plan.sh` | une commande longue lancée au premier plan, qui sera tuée | refuse l'appel d'outil |
| `scripts/garde-provenance-affirmee.sh` | un message qui attribue une décision aux règles du dépôt, sans citer sa source | bloque la fin du tour |
| `scripts/garde-verifie-par-lecture.sh` | un plan qui étiquette « vérifié » ce qui vient d'une simple lecture de code | demande confirmation |
| `scripts/garde-publication-non-sollicitee.sh` | un appel qui expose ou détruit hors du dépôt, sans que le tour l'ait demandé | demande confirmation |
| `scripts/garde-perte-seche.sh` | un effacement que rien ne rend, ni jetable ni suivi par git sans modification, ou un geste git qui jette du travail | refuse l'appel d'outil |
| `scripts/garde-avis-non-sollicite.sh` | une recommandation dans la réponse, quand la demande n'en appelait aucune | bloque la fin du tour |
| `scripts/garde-incapacite-declaree.sh` | une incapacité déclarée à compiler, tester ou déployer, sans nommer ce qui a été essayé | bloque la fin du tour |
| `scripts/garde-offre-retrecie.sh` | une réponse qui accepte en nommant un geste plus étroit que l'offre, lue comme un accord entier | signale seulement |

### Le contrôle du noyau

| clé | ce qu'il attrape | régime |
|---|---|---|
| `scripts/verifier-noyau.sh` | un fichier du noyau bricolé ou supprimé | refuse le commit |
| `scripts/verifier-noyau.sh` | le retard sur la source | avertit seulement, `--strict` le rend bloquant |

### Les listes de dette

Une dette marche sur une liste d'exclus **qui ne fait que rétrécir**. Il faut trois contrôles
pour tenir la promesse. Un qui exige, un qui protège la liste, un qui protège le fond.

| clé | ce qu'elle tient | les contrôles qui la gardent |
|---|---|---|
| `scripts/dette-doc.txt` | les dispenses du NOYAU, figées | 7 exige, 8 protège la liste, 9 protège le fond |
| `scripts/dette-doc-local.txt` | les fichiers de doc de CE projet, écrits avant le noyau | 7 exige, 8 protège la liste, 9 protège le fond |
| `scripts/dette-code.txt` | les dispenses du NOYAU, côté code | 12 exige, 13 protège la liste |
| `scripts/dette-code-local.txt` | les fichiers de code de CE projet, écrits avant le noyau | 12 exige, 13 protège la liste |

Les listes du noyau sont **figées**. Celles du projet s'amorcent **une fois**, à l'installation,
par `installer.sh --amorcer-dette`. Sans cet amorçage, un dépôt qui a déjà de la doc voit chacun
de ses fichiers refuser tous les commits, dès l'installation.

La dette de code n'a **pas** d'équivalent du contrôle 9. Un fichier déjà inscrit peut donc encore
voir sa prose empirer. C'est un trou connu, pas un oubli de ce registre.

### Les règles écrites

Rien ne les fait respecter. Elles rendent la faute constatable en une seconde, ce qui est déjà
beaucoup. Chaque clé est un début de titre de section dans [`../CLAUDE.md`](../CLAUDE.md).

| clé | ce qu'elle attrape | mécanisée par ailleurs ? |
|---|---|---|
| `Les règles de doc` | de la doc écrite sans connaître les règles canoniques | partiellement, par tout le doc-lint |
| `L'impact-grep` | un fait dupliqué en prose libre, faux dès qu'on change l'original | non, et le fichier le dit |
| `Vérifier ce qui est fait` | affirmer qu'une chose n'est pas codée en regardant une seule branche | non |
| `Anonyme partout` | un prénom dans la doc, les specs ou les données de test | oui, contrôle 2 |
| `Une seule langue` | un nom neuf dans la mauvaise langue | non |
| `Git, la branche déployable` | du travail en cours là où il ne doit pas être | partiellement, contrôle 5 |
| `Plusieurs sessions à la fois` | deux sessions qui se défont l'une l'autre sans conflit git | partiellement, l'avertissement du pre-push |
| `Avant de coder` | du code écrit sur une spec qui laisse une zone grise | non |
| `Fait observé et fait supposé` | une croyance écrite comme un fait | oui, contrôle 14, et `scripts/garde-perte-seche.sh` pour la suppression |
| `Le filet contre les livraisons invisibles` | un point de spec livré sans geste qui y mène | partiellement, le code-lint |
| `Les quatre règles du dialogue` | une affirmation sans provenance nommable, ou une question déjà tranchée par le dépôt | partiellement, `scripts/garde-provenance-affirmee.sh` sur les décisions attribuées aux règles du dépôt, et `scripts/garde-incapacite-declaree.sh` sur l'impossibilité affirmée |
| `Le ton des échanges` | du jargon sans glose, une image qui remplace le mécanisme, ou une réponse trop longue | partiellement, `scripts/garde-avis-non-sollicite.sh` sur la recommandation que rien n'a demandée |
| `Un seul chantier à la fois` | plusieurs chantiers de front, en-cours illisible | non |
| `Un changement ne contient` | une ligne changée qui ne remonte à aucune demande | partiellement, `scripts/garde-offre-retrecie.sh` sur le « ok » qui absorbe le geste nommé après lui |
| `Explorer ou documenter` | du code écrit alors que le tour ne demandait qu'un cadrage | partiellement, `scripts/garde-avis-non-sollicite.sh` sur la recommandation que rien n'a demandée |
| `Ce qui est fusionné part` | un correctif fusionné qui n'entre dans aucune version | non |

## Ce que le contrôle 15 vérifie

Il compare ce registre au dépôt, **dans les deux sens**, et refuse le commit à la moindre
divergence. Cinq volets.

1. Tout contrôle du doc-lint du noyau a sa ligne dans la table du système documentaire, et
   réciproquement.
2. Tout contrôle local, préfixé `L`, a sa clé ici.
3. Tout contrôle du code-lint a sa clé `code-lint:N` ici, et réciproquement.
4. Tout hook de `scripts/githooks/`, tout `garde-*.sh`, toute `dette-*.txt` et tout
   `verifier-*.sh` a sa clé ici.
5. Tout titre de section du fichier d'instructions a sa clé ici, **et réciproquement**. Une clé
   de règle ouvre exactement un titre, jamais zéro ni deux. Zéro veut dire que la protection a
   disparu. Deux, qu'une section neuve s'est glissée sous une clé existante, en commençant par
   les mêmes mots, sans jamais réclamer sa propre ligne.

Le volet 5 porte une limite qu'il vaut mieux nommer. Une machine ne sait pas reconnaître ce
qu'est une règle. Le contrôle exige donc une entrée **par titre de section**, ce qui est plus
grossier que la vérité. Une section qui n'est pas un garde-fou s'exempte par une ligne
`<!-- pas-un-garde-fou -->` posée juste sous son titre.

**Ce que rien ne peut attraper**, et qu'il faut donc inscrire à la main. Un garde-fou qui n'est
pas un fichier n'a aucune réalité à confronter au registre. Deux cas.

| garde-fou | ce qu'il tient | où il vit |
|---|---|---|
| le `SessionStart` | repose `core.hooksPath` et `merge.ff` à chaque session | `.claude/settings.json` |
| `merge.ff` à `false` | sans lui, un hook de fusion ne se déclenche jamais | configuration git locale |
