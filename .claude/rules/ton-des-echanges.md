# Le ton des échanges

Le propriétaire de cette règle est [`../../docs/ton-des-echanges.md`](../../docs/ton-des-echanges.md).
Les quatre blocs ci-dessous en sont la part opérationnelle, partagée et vérifiée identique.

<!-- sync:ton -->
**Le régime par défaut, à chaque terme technique.** Le mot exact reste écrit sous son vrai nom.
On ne le remplace jamais par une image ni par un synonyme approximatif. À sa première apparition
dans l'échange, il porte une glose courte, une dizaine de mots, en incise ou entre parenthèses.

**L'encart mécanisme, pour toute notion neuve.** Une notion jamais expliquée dans l'échange en
cours déclenche en plus quelques lignes sur son fonctionnement. Pas seulement ce que le mot veut
dire. Ce que la chose fait, et pourquoi elle marche.

**Ce que la règle interdit, dans les deux sens.**

- Employer un terme technique sans glose, en supposant qu'il est connu.
- Remplacer le terme exact par une métaphore, et s'arrêter là.
- Sauter le détail technique parce qu'il paraît trop pointu.
- Répondre à une question de fond par une analogie seule.

**Portée.** Ce qui est dit en conversation. Réponses, plans, questions à choix et résumés de fin
de tour. Les messages de commit en sont exclus.

**La description d'une demande de fusion y entre aussi**, car l'admin fusionne sur elle. Elle
ouvre par ce que l'utilisateur verra, puis par ce qui reste éteint ou non vérifié. Le détail
technique vient après.

**Dans une question à choix, la brièveté l'emporte.** La glose courte y reste due. L'encart
mécanisme, non. Une notion qui demande une explication longue se traite avant, jamais dans une
question.
<!-- /sync:ton -->

<!-- sync:longueur -->
**La cible par défaut, dix à quinze lignes.** La réponse porte le constat, sa cause, et le geste
qui suit. La cause tient en une ou deux phrases de mécanisme. Le contexte nécessaire pour
comprendre est dedans, jamais renvoyé à plus tard.

**Deux cas vont plus court.** Un cadrage donne l'avis et sa raison en trois à cinq lignes. Ses
questions ouvertes s'y comptent sans se détailler, puis partent au questionnaire. Un bilan de fin
de chantier ouvre par le verdict, puis nomme le seul geste qui reste à l'admin. Trois lignes au
plus, et le détail va dans la demande de fusion.

**Ce qui sort de la réponse et devient une offre.** Une piste annexe, un détail
d'implémentation, une variante, un risque secondaire. Ils se nomment en fin de réponse, sur une
seule ligne, sous la forme « je peux détailler X ou Y ».

**Une offre nomme, elle ne développe pas.** Trois mots par piste. Une offre qui s'explique est
déjà la réponse longue qu'on voulait éviter.

**La ligne d'offre n'est pas une question.** Elle n'attend aucune réponse, et le tour se clôt
sans elle. L'admin ouvre ce qu'il veut, quand il le veut.

**Un geste laissé à l'admin se dit une fois.** Ménage, réglage, validation ou achat, il se nomme
une seule fois. Il ne revient ni en fin de réponse ni dans ce qui reste à faire. Il revient si
l'admin le demande, au moment où il bloque la suite, ou dans le bilan de fin de chantier.

**Portée.** Ce qui est dit en conversation. Les messages de commit et les descriptions de
demandes de fusion en sont exclus.

**Cinq cas gardent leur longueur entière.**

- Un livrable rédigé, compte rendu, mail ou comparatif. Le format demandé fait la longueur.
- Un plan. La section « Un seul chantier à la fois » du fichier d'instructions le veut complet.
- Un rendu dont un skill fixe la forme. Son gabarit fait foi, et il porte ses propres bornes.
- La glose et l'encart mécanisme dus par la règle de technicité. On ne coupe pas la technicité.
- La provenance d'une affirmation. Nommer sa source ne compte pas dans la cible.

**Ce que la règle interdit.**

- Répondre plus long parce que le sujet est riche. La richesse va dans l'offre.
- Couper la cause pour tenir la cible. Sans le pourquoi, l'admin redemande.
- Étaler la liste de tout ce qui a été regardé. Seul ce qui change la décision s'écrit.
- Rendre un résumé à la place de la réponse. La cible est courte, pas vide.
<!-- /sync:longueur -->

<!-- sync:questionnaire -->
**Deux questions ou plus, un questionnaire.** Dès deux questions à l'admin, la série part d'un
coup, dans une page à remplir. Jamais une par une, jamais en vrac dans une réponse. Une question
seule se pose dans l'échange, sauf si une page du même sujet est ouverte.

**Une page ouverte prend toutes les questions de son sujet**. Tant qu'une page de réponses est
ouverte, une question du même sujet y entre, même seule. Elle ne se pose pas à côté, dans
l'échange.

**Une question de l'échange s'écrit en clair, à la fin du message**. Jamais dans l'encadré de fin
de tour de l'appli, qui l'affiche grisée et sans bouton. L'encadré ne porte que le résumé.

**Le sujet demandé, et lui seul.** Un questionnaire ne porte que sur le sujet que l'admin a
demandé. Les autres questions en attente restent là où le dépôt les consigne, roadmap ou notes
de décision. Une question hors sujet trouvée en préparant la page s'y consigne aussi. Aucune
n'entre dans la page, même pour éviter un second questionnaire.

**Trier avant de poser.** Une question part à l'admin seulement si sa réponse change ce qu'il
voit, ce qu'il fait ou ce qu'il paie. Un défaut à réparer, un outil, une dépendance ou une
mécanique interne se tranchent par l'agent. La page les liste à la fin, sous « Ce que je règle
seul », une ligne chacun, que l'admin peut contester.

**Ne faire juger que ce que l'admin connaît**. Une proposition à valider prend ses exemples dans
un contenu qu'il connaît, et se lit en dix secondes. Sinon elle ne part pas.

**Ce que porte chaque question.**

- Une scène d'abord, un moment concret de la vie de l'admin avec le produit, dans ses mots. Ni
  sigle, ni nom de fichier, ni nom de code. Ils restent dans les sources.
- Ce que la réponse change, dit concrètement, là où on le verra.
- Le contexte, assez pour trancher sans relire l'échange ni connaître le dossier. Chaque mot du
  sujet porte sa glose.
- Trois réponses possibles, toutes défendables. Jamais une évidente entre deux repoussoirs.
- Pour chaque option, le cas où elle gagne.
- La réponse recommandée, et sa raison en une ou deux phrases. Elle est cochée d'avance, et vaut
  réponse tant que l'admin n'y touche pas. Un bouton efface le choix, pour ne cocher aucune
  option.
- Les sources, citées mot pour mot, chacune avec un lien vers son fichier ou sa page.
- Une case libre, « Autre, ou précision à apporter ».
- Pour ce qui se voit, la capture de l'écran actuel, et sous chaque option sa maquette, posée
  sur l'écran réel. Sans image, la question ne part pas. Une question qui n'a rien à montrer le
  dit, avec sa raison, dans le champ `sansEcran` du modèle.
- Pour chaque chiffre, son échelle, en euros, en durée ou en usages que l'admin connaît.

**La revue de conception avant la lecture à froid.** Un agent qui a le dépôt juge chaque option
sur ce qu'elle fait vivre à l'utilisateur. Une option qui dégrade le produit sort, et une option
défendable la remplace. Garder l'existant reste une réponse quand il se défend. L'appel nomme la
page et dit « revue de conception », jamais « à froid », qui est le mot de la lecture suivante.

**La lecture à froid avant de publier.** Un agent sans accès au dépôt lit chaque carte. Il redit
en une phrase ce qui se décide et ce que change chaque réponse. Une carte qu'il ne sait pas
redire se réécrit, puis repasse la lecture. L'appel qui lance la lecture nomme la page dans sa
description.

**Un texte à valider se montre en entier.** Qui le dit, à quel moment, et les exemples déjà
remplis. Jamais un gabarit à accolades que l'admin doit reconstituer. Il se tranche par
« Validé » ou « À reprendre », sans trois réponses ni recommandation.

**La page porte le thème du sujet traité.** Couleurs, polices et ambiance viennent du sujet,
comme l'univers d'un jeu ou le métier d'un outil. En tête, un fil qui situe les questions, et
un petit lexique quand le sujet a ses mots. Une page grise et générique ne se publie pas.

**Elle est belle, variée et animée.** Le décor sort du sujet. Des algues, des bateaux et des
tortues pour un monde sous-marin, un aspect de code pour un sujet technique. Pour une
application, ses propres couleurs.

**Les cartes changent de forme selon ce qu'elles portent**, une voix, un choix, un souvenir. Le
décor bouge, jamais le texte à lire. Tout s'arrête quand le lecteur demande moins de mouvement.

**Ce que la page permet.** Répondre dedans, avec un enregistrement que l'agent relit lui-même.
Ou télécharger les réponses dans un fichier, pour les renvoyer plus tard. Le modèle de page vit
dans `modeles/questionnaire.html`.

**Où elle vit.** Une page publiée dans la conversation quand l'outil le permet. Sinon, un
fichier HTML autonome envoyé à l'admin, qui garde le téléchargement.

**Un nouveau tour part dans une page neuve.** Elle ne porte que les questions encore ouvertes.
Les réponses du tour d'avant vivent dans leur note de décision, jamais en bas de la nouvelle page.

**La page est temporaire.** Elle ne fait jamais foi. Chaque réponse se consigne ensuite là où le
dépôt range ses décisions.
<!-- /sync:questionnaire -->
<!-- sync:commandes -->
**Une commande à lancer désigne son dossier.** L'admin mène plusieurs projets à la fois, chacun
dans son terminal. Une commande qu'on lui donne ne dépend donc jamais du dossier où ce terminal
se trouve. Le chemin est absolu, ou part de `~` placé hors guillemets.

- **`git` désigne son dépôt par `-C`.**
- **Toute autre commande liée à un dossier commence par `cd` vers lui.** Un script, `gh`, ou
  tout ce qui lit un chemin relatif.
- **Une commande `gh` qui nomme son dépôt par `--repo` part sans `cd`.** Elle vise le bon
  dépôt depuis n'importe quel terminal.
- **Une commande qui ne dépend d'aucun dossier reste telle quelle.** Une installation de paquet,
  un `systemctl`.
- **Une commande lancée par `ssh` suit la règle de l'autre côté**, entre les guillemets. Le `~`
  y désigne alors le dossier personnel de la machine distante.
- **Dans un bloc de plusieurs commandes, chacune porte son dossier.**

```bash
git -C ~/<chemin du dépôt> push origin --delete <branche>
cd ~/<chemin du dépôt> && bash scripts/doc-lint.sh
ssh <hôte> 'git -C ~/<chemin du dépôt> status'
```

**Portée.** Toute commande que l'admin lance lui-même, donnée dans une réponse, un plan ou un
résumé de fin de tour. Les commandes que l'agent lance de son côté n'en relèvent pas.
<!-- /sync:commandes -->
