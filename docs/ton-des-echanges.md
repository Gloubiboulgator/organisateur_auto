# Le ton des échanges, comment l'agent parle à l'admin

> **Pour qui.** L'agent, à chaque réponse. Et l'admin, quand il veut vérifier ce qu'il est en
> droit d'attendre.
>
> **Ce que ce fichier fait, et ne fait pas.** Il fait foi sur le niveau de technicité des
> réponses, sur leur longueur, sur la façon de poser une série de questions, et sur la forme des
> commandes données à lancer. Il ne gouverne ni la doc écrite, ni la provenance des
> affirmations, ni le ton du produit face à un utilisateur. Ces trois sujets ont leur propre
> propriétaire.
>
> **Le rappel chargé à chaque session.** Les quatre règles opératoires sont recopiées dans
> `.claude/rules/ton-des-echanges.md`, dans des blocs synchronisés. Un contrôle refuse le commit
> si les copies diffèrent d'un caractère. Le fichier d'instructions, lui, ne porte qu'un renvoi.

---

## Le constat qui rend ce fichier nécessaire

L'admin apprend le métier. Il n'est pas développeur chevronné, et ne veut pas non plus être
ménagé.

La demande porte donc deux exigences opposées. Les deux comptent autant, et c'est ce qui la rend
difficile.

- Comprendre facilement, sans buter sur des mots que personne n'explique.
- Ne pas être privé de technicité, parce que la compétence est le but de la démarche.

Il y a donc **deux façons d'échouer**, pas une seule. Le mur de jargon n'apprend rien.
L'explication imagée prive de la compétence qu'on vient chercher.

La seconde est la plus sournoise. Elle a l'air d'un service rendu.

## La règle de technicité

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
de tour. Les messages de commit et les descriptions de demandes de fusion en sont exclus.

**Dans une question à choix, la brièveté l'emporte.** La glose courte y reste due. L'encart
mécanisme, non. Une notion qui demande une explication longue se traite avant, jamais dans une
question.
<!-- /sync:ton -->

## La longueur des réponses

L'admin ne lit pas les réponses longues. Il redemande un résumé, ce qui coûte un tour de plus et
une réponse de plus. Le mur de texte échoue donc exactement comme le mur de jargon.

La règle ci-dessus ne le corrige pas. Une réponse peut gloser chaque terme et rester illisible
par sa seule taille. La brièveté et la technicité sont deux exigences séparées, et ce fichier
porte les deux.

<!-- sync:longueur -->
**La cible par défaut, dix à quinze lignes.** La réponse porte le constat, sa cause, et le geste
qui suit. La cause tient en une ou deux phrases de mécanisme. Le contexte nécessaire pour
comprendre est dedans, jamais renvoyé à plus tard.

**Ce qui sort de la réponse et devient une offre.** Une piste annexe, un détail
d'implémentation, une variante, un risque secondaire. Ils se nomment en fin de réponse, sur une
seule ligne, sous la forme « je peux détailler X ou Y ».

**Une offre nomme, elle ne développe pas.** Trois mots par piste. Une offre qui s'explique est
déjà la réponse longue qu'on voulait éviter.

**La ligne d'offre n'est pas une question.** Elle n'attend aucune réponse, et le tour se clôt
sans elle. L'admin ouvre ce qu'il veut, quand il le veut.

**Portée.** La même que la règle de technicité. Ce qui est dit en conversation, messages de
commit et descriptions de demandes de fusion exclus.

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

## Plus de trois questions à poser

Poser une longue série une question par tour coûte un aller-retour par question. L'admin perd
aussi la vue d'ensemble, et tranche chaque point sans voir les suivants. Poser la série en vrac
dans une réponse donne l'inverse, un mur qu'on ne sait pas remplir.

> Incident fondateur. Un questionnaire de textes à valider ne disait ni qui parle, ni quand, ni
> d'où venait chaque décision. Ses options mêlaient une évidente à deux repoussoirs, sur une page
> grise. L'admin n'y a rien compris. Refaite avec le moment, les citations liées et le thème du
> sujet, elle lui a fait demander que cette forme devienne la règle.

> Incident fondateur, sur le fond. Un questionnaire de quatorze cartes a reçu quatre « incompréhensible »
> et cinq cartes jamais touchées. Deux portaient sur l'outillage de l'agent, une sur des
> retouches jamais montrées, une sur un budget sans échelle. Toutes partaient du dépôt, sigles
> et noms de fichiers compris, et non de ce que l'admin voit en se servant du produit.

<!-- sync:questionnaire -->
**Plus de trois questions, un questionnaire.** Une série de plus de trois questions à l'admin
part d'un coup, dans une page à remplir. Jamais une par une, jamais en vrac dans une réponse.
Trois questions ou moins se posent dans l'échange, une par une.

**Ratisser large avant de publier.** Un questionnaire se prépare en cherchant aussi les autres
questions en attente. Les trous consignés dans la roadmap, les points ouverts des notes de
décision, et ce que le chantier suivant demandera. Elles partent dans le même questionnaire,
par parties, plutôt que dans dix questionnaires à la suite.

**Trier avant de poser.** Une question part à l'admin seulement si sa réponse change ce qu'il
voit, ce qu'il fait ou ce qu'il paie. Un défaut à réparer, un outil, une dépendance ou une
mécanique interne se tranchent par l'agent. La page les liste à la fin, sous « Ce que je règle
seul », une ligne chacun, que l'admin peut contester.

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
- Pour ce qui se voit, sa capture ou sa maquette. Sans image, la question ne part pas.
- Pour chaque chiffre, son échelle, en euros, en durée ou en usages que l'admin connaît.

**La lecture à froid avant de publier.** Un agent sans accès au dépôt lit chaque carte. Il redit
en une phrase ce qui se décide et ce que change chaque réponse. Une carte qu'il ne sait pas
redire se réécrit.

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

**La page est temporaire.** Elle ne fait jamais foi. Chaque réponse se consigne ensuite là où le
dépôt range ses décisions.
<!-- /sync:questionnaire -->

## Les commandes données à lancer

Une commande sans chemin s'exécute dans le dossier du terminal qui la reçoit. L'agent ne voit
pas forcément ce terminal, et l'admin en garde plusieurs ouverts, sur plusieurs projets. La même commande
peut donc viser un autre dépôt que celui dont parle l'échange.

> Incident fondateur. Une suppression de branche distante a été donnée sans chemin. L'admin l'a
> lancée depuis un terminal ouvert sur un autre projet. Elle a visé le mauvais dépôt distant, et
> n'a échoué que parce qu'aucune branche n'y portait ce nom.

<!-- sync:commandes -->
**Une commande à lancer désigne son dossier.** L'admin mène plusieurs projets à la fois, chacun
dans son terminal. Une commande qu'on lui donne ne dépend donc jamais du dossier où ce terminal
se trouve. Le chemin est absolu, ou part de `~` placé hors guillemets.

- **`git` désigne son dépôt par `-C`.**
- **Toute autre commande liée à un dossier commence par `cd` vers lui.** Un script, `gh`, ou
  tout ce qui lit un chemin relatif.
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

## Pourquoi garder le mot exact plutôt qu'une image

Une image se retient, mais elle ne se réutilise pas. Qui a compris « le truc qui garde les
choses » ne saura pas chercher dans une documentation. Il ne saura pas non plus poser sa question
à quelqu'un d'autre. Le mot exact est ce qui donne accès au reste du monde.

La glose, elle, coûte une dizaine de mots. C'est le prix le plus bas du document.

## La même phrase en trois versions

Le sujet, un contrôle qui refuse un commit.

**Trop technique.** « Le pre-commit hook invoque le linter, qui exit non nul si un contrôle
rougit. »

**Trop imagé.** « Un petit gardien vérifie ton travail avant de le laisser passer. »

**Au format.** « Le hook pre-commit, un script que git lance avant d'enregistrer un commit,
appelle le lint. Si un contrôle échoue, le commit est refusé. »

La troisième version garde les deux mots exacts, hook et lint, et les glose au passage. Elle dit
aussi ce qui se passe vraiment.

## Les limites, dites franchement

**Presque rien ne mesure l'application de ces règles.** Un contrôle verrouille le texte des
blocs partagés, au caractère près. Il ne peut pas juger si une réponse donnée les respecte.

Deux gardes en mesurent une part, dans un questionnaire envoyé à l'admin. Chaque question à
choisir part d'une scène sans jargon visible, et chaque option dit quand elle gagne. Le
registre des garde-fous les nomme.

**La frontière du terme neuf est floue.** Un terme expliqué il y a trente tours de conversation
est-il encore connu ? La règle ne tranche pas, et l'agent choisit.

**La cible de longueur est un repère, pas un seuil.** Rien ne compte les lignes d'une réponse.
Un contrôle qui le ferait gênerait plus qu'il ne servirait, et le registre des garde-fous tranche
déjà ce cas.

**La frontière de l'offre est un jugement.** Ce qui mérite d'être dit, et ce qui mérite d'être
seulement nommé, dépend du tour. L'agent tranche, et l'admin garde le droit de demander plus.
