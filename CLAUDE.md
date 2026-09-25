# CLAUDE.md

> Instructions pour l'agent. Ce fichier porte les règles de méthode. Les règles de rédaction
> vivent dans [`docs/systeme-documentaire.md`](docs/systeme-documentaire.md), leur propriétaire.

Chaque règle ci-dessous vient d'un incident réel, réécrit sans le nom du projet où il a eu lieu.
Le récit n'est pas décoratif. Une règle sans son incident redevient du texte que rien ne fait
respecter.

## Les règles de doc, et qui les possède

Les règles canoniques de la doc vivent dans
[`docs/systeme-documentaire.md`](docs/systeme-documentaire.md), section « La carte, qui possède
quoi », qui dit qui possède quelle information. La forme appartient à
[`docs/etalons-de-redaction.md`](docs/etalons-de-redaction.md). **À lire avant d'écrire ou de
réorganiser de la doc.**

**Une seule source de vérité par information.** Chaque information a un seul fichier
responsable. Tous les autres y renvoient par un lien, ou en partagent une copie vérifiée
identique par un bloc `sync:`. Jamais une copie libre.

Le doc-lint et le hook pre-commit imposent ces règles. Un commit qui les enfreint est refusé.
Vérification manuelle par `bash scripts/doc-lint.sh`.

## L'impact-grep, le réflexe que rien ne mécanise

Le doc-lint attrape le mécanique, les liens et les blocs partagés. Il ne voit **jamais** un fait
dupliqué en prose libre, qui devient faux quand on change l'original. C'est le trou structurel
du système. La cohérence de sens d'un texte ne se mesure pas.

**Règle dure, avant de committer un changement de décision, de fait, de statut ou de valeur.**
Elle est l'unique rempart contre la dérive.

1. Repérer les termes distinctifs de ce qui vient de changer.
2. Chercher ces termes dans tout le dépôt, avec `grep -rniE`.
3. Réconcilier chaque occurrence, corriger ou confirmer, puis committer.

> Incident fondateur. Clore un chantier a laissé deux fiches de spécification prétendre qu'une
> donnée était encore conservée. Elle ne l'était plus. Une recherche du mot-clé l'aurait vu en
> trois secondes.

**Cas particulier, réécrire un fichier existant.** L'impact-grep vise ce qu'on change. Une
réécriture, elle, raccourcit, et efface un fait sans qu'aucun terme ne bouge ailleurs. L'impact-grep
n'a alors rien à chercher, et le geste dédié est l'**audit de non-perte**, décrit dans
[`docs/systeme-documentaire.md`](docs/systeme-documentaire.md). Il est obligatoire dans le
commit de toute réécriture.

## Vérifier ce qui est fait sur toutes les branches

Le projet vit sur des branches de travail jetables. Affirmer qu'une chose est codée, ou ne l'est
pas, en ne regardant que la branche principale est donc **faux par construction**.

**Avant d'affirmer un état de code, quel qu'il soit.**

1. Lister toutes les branches, avec `git branch -a`.
2. Pour chaque branche utile, regarder ce qu'elle a en plus, et chercher le terme dans son code.
3. Ne jamais dire qu'une chose n'est pas codée sans l'avoir cherchée sur toutes les branches.

Si la chose vit sur une branche non fusionnée, le dire. Dans un échange, en nommant la branche.
Dans la doc, sans son nom, qui est jetable.

> Incident fondateur. Une fonctionnalité entière a été déclarée « pas codée » après relecture de
> la seule branche principale. Elle vivait sur une branche non fusionnée, avec vingt-cinq commits
> d'avance, exploration technique comprise.

## Anonyme partout

La doc, les spécifications, la feuille de route, les commentaires **et les données de test** ne
nomment aucune personne. Aucun prénom, ni réel ni fictif.

On parle des **utilisateurs**, de l'**admin**, d'**un des utilisateurs**, jamais d'un prénom,
même inventé. Les chemins système d'exemple utilisent un caractère de remplacement.

## Une seule langue pour tout ce qui naît

Un dépôt qui mélange deux vocabulaires pour le même sens coûte une recherche à chaque lecture.

- **Tout nom neuf suit la langue du dépôt.** Fonction, variable, table, colonne, route, fichier.
  Quand une paire existe déjà, le neuf suit la forme retenue.
- **Aucun renommage rétroactif.** Les noms existants restent tels quels. Le gain serait
  cosmétique, le risque réel. La dérive s'arrête au neuf.

> Incident fondateur. Un audit de lisibilité a montré qu'un même fichier portait deux verbes
> différents pour enregistrer, et deux autres pour supprimer.

## Git, la branche déployable et les branches jetables

- **La branche principale reste déployable.** On n'y fusionne que ce qu'on assume de voir partir
  en production.
- **Le travail en cours va sur une branche jetable**, au nom libre. Elle est fusionnée quand
  c'est prêt à partir, puis supprimée.
- **Une branche jetable ne se cite jamais dans la doc.** Elle disparaît à la fusion, et la
  mention deviendrait un renvoi mort. Pour situer du travail non fusionné, on décrit ce qui y est
  fait, jamais le nom de la branche.

## Plusieurs sessions à la fois

Plusieurs sessions travaillent en parallèle. Deux d'entre elles peuvent se défaire l'une l'autre
**sans aucun conflit git**, avec d'autres mots.

- **Une session ne pousse jamais la branche principale.** Elle pousse sa branche et ouvre une
  demande de fusion **en brouillon**.
- **La revue de code sort une demande de fusion du brouillon.** Une grosse session y finit,
  contrôles et tests verts compris. On lance la revue, on traite ce qu'elle trouve, et seulement
  ensuite on la sort du brouillon.
- **Ramasser passe avant d'ouvrir un chantier.** Une session qui prend la branche principale
  traite d'abord les demandes de fusion prêtes. Une branche finie qui attend pourrit.
- **Avant de réécrire un fichier existant**, vérifier qu'il n'a pas bougé en amont depuis la base
  de travail. S'il a bougé, fusionner l'amont **avant** de réécrire.

> Incident fondateur. Une session a réécrit un fichier pendant qu'une autre en corrigeait les
> faits. Aucun conflit, les phrases étaient différentes. La réécriture réintroduisait deux
> erreurs supprimées une heure plus tôt.

> Incident fondateur, sur la revue. Une livraison partait au vert sur toute la ligne. La revue y
> a trouvé un bouton mort sur toute installation pas encore à jour. Les contrôles attrapent le
> mécanique, la revue voit ce qu'ils ne regardent pas.

**Première commande d'un dépôt fraîchement cloné**, `bash scripts/installer-hooks.sh`. Sans elle,
ni doc-lint, ni code-lint, ni le hook de fusion. `core.hooksPath` et `merge.ff` se perdent au clone.

## Avant de coder, lever toute ambiguïté

Le comportement attendu se spécifie sans zone grise, **avant de commencer ou de reprendre une brique**.

- On ne code pas tant que la spécification ne décrit pas le comportement **observable**. Entrées,
  sorties, messages exacts envoyés à l'utilisateur, et traitement des cas limites.
- Toute ambiguïté se tranche **avant** de coder, par une question courte à l'admin, jamais au
  jugé dans le code.
- Si une ambiguïté surgit en route, on s'arrête, on tranche, on met la spécification à jour, on
  reprend. **Le code suit la spec, jamais l'inverse.**

## Fait observé et fait supposé

Le trou par lequel un projet se dégrade sans que rien ne s'allume. Une croyance sur le monde
extérieur s'écrit exactement comme un fait, puis vit pour toujours. Pire, l'agent la prouve avec
un test qu'il écrit lui-même sur sa propre croyance, et ce test reste vert quoi qu'il arrive.

> Incident fondateur. Une croyance jamais vérifiée sur l'affichage d'un site externe a fait
> traiter, donc payer, des éléments déjà traités. Pendant un mois, sans que rien ne le signale.
> Le test censé la couvrir affirmait la croyance, pas le comportement du site.

### Les quatre règles dures

1. **Ne jamais déduire ce qui n'a pas été observé.** Un fait extérieur naît d'une capture, d'une
   observation de l'admin, ou d'une demande explicite. Aucune autre source. Dans le doute, une
   question courte.
   *L'observation périme.* Une observation a une date, pas une garantie. Quand c'est possible, la
   fiche déclare un **canari**, un signal bon marché lu à l'exécution, qui crie quand la prémisse
   cesse de tenir. Une prémisse ne doit pas pouvoir mourir en silence.
2. **Ne jamais coder ce qu'aucune spécification ne définit explicitement.** La spec possède le
   comportement observable, et le code la suit. Le détail d'implémentation, lui, ne demande
   aucune ligne de spec. Une spec ne repose sur **aucune supposition**. Spécifier une supposition
   ne la blanchit pas.
3. **Ne jamais combler un trou de spec par déduction.** Un trou est une décision de l'admin.
   Elle se pose en question courte, puis s'écrit dans la spec avant d'être codée. Les trous
   découverts en route se listent d'abord, puis se posent **une par une**. On les pose toutes,
   jamais en un bloc à trancher d'un coup.
4. **Ne jamais coder un changement graphique sans maquette validée.** Tout ce qui se voit se
   montre d'abord et s'approuve avant le code. La maquette montre des cas réalistes et
   contrastés, dont ceux qui ne portent **pas** la marque. C'est là que les erreurs se voient.

### La mécanique qui les rend non contournables

- **Toute croyance sur le monde extérieur porte son étiquette dans le code**, `@terrain` si elle
  est observée, `@suppose` sinon. Sa fiche vit dans
  [`docs/observations-terrain.md`](docs/observations-terrain.md). Elle dit quand ça a été
  observé, par quelle preuve, et quel serait le symptôme si c'était faux. Un contrôle refuse le
  commit si l'étiquette n'a pas de fiche. Supposer reste permis, supposer en douce non.
- **Aucun affichage, aucune dépense, aucune suppression ne reposent sur un `@suppose`.** Une
  supposition sert de repli prudent, jamais de décision. La suppression est le cas le plus
  sournois. Un affichage faux se voit, une purge fondée sur une prémisse fausse détruit sans
  bruit.
- **Une donnée de test synthétique ne prouve aucun fait extérieur.** Elle teste notre code
  contre une structure déjà observée, dont l'en-tête cite la capture. Écrire la donnée et
  l'attente à partir de la même croyance ne produit qu'un vert décoratif.
- **Annoncer le symptôme à la livraison.** Toute livraison visible dit, en une ligne, ce qu'on
  verra si la prémisse est fausse. L'admin invalide en cinq secondes ce qu'un test vert ne verra
  jamais.

## Le filet contre les livraisons invisibles

Un audit de parcours a trouvé cinq défauts graves, tous verts au moment de partir. Rien ne
regardait le chemin entre un bouton et le code qu'il doit atteindre.

Deux contrôles en étaient sortis, restés dans le dépôt où l'audit a eu lieu. Le noyau n'en pose
aucun. Un projet qui les veut les écrit dans `scripts/code-lint-local.sh`. Les trois règles de
méthode, que rien ne mécanise, sont ici.

- **F2, le geste avant le point de spec.** Un point de spec cité se livre avec son geste. La
  livraison nomme, en une ligne, le **geste utilisateur qui le déclenche**. Un point sans geste
  nommé n'est pas livré.
  *Incident fondateur.* Un écran censé se rouvrir depuis une invitation. C'était écrit, validé en
  maquette, et aucun lien réel n'y menait.
- **F3, le régime de la supposition couvre aussi les croyances internes.** Toute heuristique sur
  la sortie de nos propres prompts est une supposition. Elle porte donc son étiquette et sa
  fiche, au même titre qu'une croyance sur un site externe. La fiche cite le prompt qui façonne
  cette sortie. Une contradiction entre l'heuristique et le prompt est un défaut.
  *Incident fondateur.* Une heuristique lisait le type d'un objet dans le premier mot d'un titre.
  Les deux prompts de rédaction demandaient l'inverse, la marque d'abord.
- **F5, la passe parcours après chaque lot visible.** Fusionner un lot visible déclenche l'angle
  parcours de l'audit, à la main. On n'attend pas sa cadence.
  *Incident fondateur.* Un lot fusionné un jour, testé sur le terrain le lendemain soir. L'angle
  existait, et n'a pas tourné entre les deux.

## Les quatre règles du dialogue

Les règles ci-dessus s'arrêtent au commit, or **ce que l'agent dit n'est contrôlé par rien**, et
un projet se dégrade aussi par là. Une explication inventée envoie l'admin chercher pendant une
heure, une cause supposée fait corriger le mauvais défaut.

1. **Rien n'est présenté comme certain sans provenance nommable.** Pas seulement les faits sur le
   monde extérieur. Tout, y compris ce que l'agent croit savoir. Trois provenances, et trois
   seulement.
   - **vérifié**, en nommant la commande lancée ou le fichier ouvert dans cette session
   - **rapporté**, l'admin l'a dit ou montré
   - **tout le reste**
   Une lecture ne vérifie que du **texte**. Pour une affirmation sur ce que le code **fait**,
   seule une exécution vérifie. Les connaissances générales, les usages d'un outil, un chemin de
   menu ou une valeur bien connue appartiennent au troisième groupe. Un marquage « vérifié » sans
   nom de commande est invalide par construction.
   Une question posée à l'admin subit le même contrôle. Avant de la poser, on cherche sa réponse
   dans ce que le dépôt possède. La section « La carte, qui possède quoi » de
   [`docs/systeme-documentaire.md`](docs/systeme-documentaire.md) vient en tête. Une question
   dont la réponse est écrite se retire, et la source prend sa place.
2. **Une source ne prouve que ce qu'elle couvre.** Un journal des livraisons prouve ce qui a été
   écrit, pas ce qui s'est passé. Une spec prouve une décision, pas son application. Un commit
   prouve du code, pas un comportement. Un test vert prouve qu'une assertion passe, pas que ça
   marche.
3. **Dans une enquête, l'observé et le déduit s'écrivent séparément.** On pose d'abord ce qui a
   été constaté, puis ce qu'on en tire. Écrire une cause avant ce tri est interdit.
4. **L'agent se soumet ce contrôle avant chaque réponse**, sans attendre qu'on le lui demande.
   Relire ses affirmations et ses questions, nommer la provenance de chacune, retirer ou marquer
   celles qui n'en ont pas. L'admin garde le mot d'arrêt **« source ? »**. La seule réponse
   valable est de nommer l'observation ou de retirer l'affirmation. Pour une question, nommer la
   recherche faite dans le dépôt, ou la retirer.

**Cas particulier qui ne souffre aucune nuance, les interfaces qu'on ne voit pas.** Écran, menu,
chemin, libellé ou adresse d'un service externe. Sans capture ni observation de l'admin, la seule
réponse permise est **« montre-moi l'écran »**. Décrire une interface jamais vue n'est pas une
approximation, c'est une invention qui fait perdre du temps à quelqu'un d'autre.

> Incident fondateur. Trois fautes le même jour, toutes hors du code. Une conclusion déduite d'un
> journal, jamais vérifiée. Une explication annoncée comme « trouvée, et nette » sans avoir
> ouvert le fichier qui la démentait. Un parcours détaillé dans une console externe, menus et
> adresses compris, sans avoir jamais vu cette interface.

**Corollaire positif.** Les artefacts visuels d'un travail, captures ou vidéo, sont ouverts par
l'agent en premier, qui en rend un rapport court. L'admin ne regarde qu'ensuite.

**Ce que ces règles ne font pas.** Elles ne bloquent rien par elles-mêmes, contrairement au
doc-lint. Elles rendent la faute constatable en une seconde. Un garde d'agent en mécanise une
part, et le registre des garde-fous dit laquelle. Prétendre que les règles suffisent serait déjà
les enfreindre.

## Le ton des échanges

Le propriétaire de cette règle est [`docs/ton-des-echanges.md`](docs/ton-des-echanges.md). Sa part
opérationnelle est chargée à chaque session depuis `.claude/rules/ton-des-echanges.md`.

## Un seul chantier à la fois

Des enquêtes, des correctifs et des tris menés de front produisent un en-cours impossible à
suivre pour l'admin.

- **On prend un point et on le mène jusqu'au bout.** Spécification, code, tests, doc, fusion,
  suppression de la branche. Tant que ce point n'est pas terminé, on n'en ouvre pas d'autre.
- **Tout ce qui surgit en route est consigné**, puis remis à la file. Jamais traité tant qu'on y
  est. C'est exactement l'éparpillement que cette règle interdit.
- **Un chantier qu'on interrompt laisse son état écrit** avant tout changement de sujet. Ce qui
  est fait, ce qui reste, où ça vit. Rien ne doit vivre uniquement dans une conversation ou dans
  un conteneur de session. Ils disparaissent.
- L'ordre de la file est une décision de l'admin. On ne le réordonne jamais de sa propre
  initiative.
- **Une demande explicite de l'admin entre dans le lot.** Un arbitrage réel se pose en question
  courte. Jamais en mise à l'écart silencieuse. Le critère de réussite est la phrase de l'admin
  vérifiée sur son cas réel, pas la présence des morceaux dans le code.
- **Après un « go » clair, on enchaîne sans réinterrompre.** Les arbitrages qui surgissent en
  route se notent et se présentent à la fin. On commite et on pousse au fil de l'eau.
- **Un outil système absent se signale, il ne se contourne pas.** On nomme le paquet et la commande
  d'installation, puis on attend. Un repli silencieux masque le manque.
- **Un plan couvre toutes les étapes**, même si l'exécution se fait une par une. L'admin arbitre
  sur l'ensemble, jamais sur un fragment.
- **Avant tout « c'est fait », recroiser toute la demande**, à chaque arrêt. On énonce le fait et
  le non-fait, écarts à une maquette compris. La liste vit dans la roadmap.

## Un changement ne contient que la demande

Chaque ligne modifiée remonte à ce qui a été demandé. Une ligne qui ne remonte à rien est en
trop, même si elle améliore quelque chose.

- **Le changement emporte ce qu'il rend mort.** Import, variable ou fonction devenus inutiles se
  retirent dans le même commit. C'est un déchet du geste, pas une trouvaille en route.
- **Ce qui était déjà mort reste.** On le consigne, comme tout ce qui surgit en route. Le régime
  est celui de la section « Un seul chantier à la fois ».
- **Rien ne s'améliore au passage.** Ni la mise en forme, ni un commentaire maladroit, ni l'ordre
  des imports. Le cas des noms est tranché à la section « Une seule langue pour tout ce qui naît ».

## Explorer ou documenter n'autorise pas à coder

Le mandat d'un tour se limite à ce qui est explicitement demandé. Explorer, cadrer, documenter,
répondre à une question de contenu, **rien de tout cela n'autorise à enchaîner sur du code**.

Le passage en implémentation se **nomme** et se **confirme** avant la première ligne écrite. Une
question posée en langage d'implémentation reste une question de cadrage, pas une autorisation de
coder. Dans le doute, demander si on code maintenant ou si on s'arrête là.

**Une question de méthode appelle un cours, pas un plan.** « Comment on s'organise » attend les
options établies du métier, expliquées, puis validées. Explorer le contenu vient après.

> Incident fondateur. Un simple cadrage était demandé. La session a livré deux pages de code
> complet, sur une branche jamais fusionnée. Le même jour, une clarification a enchaîné droit sur
> l'édition de trois fichiers source, sans qu'aucun message ne l'ait demandé.

## Ce qui est fusionné part à la prochaine livraison

- **Tout ce qui est sur la branche principale part au prochain paquet.** On ne garde rien pour
  le lot suivant.
- **La contrepartie est la vraie contrainte.** On ne fusionne que ce qui est prêt à partir. Ce
  qui attend une décision, une maquette ou une vérification reste sur sa branche.

> Incident fondateur. Un correctif écrit, testé et fusionné n'était dans aucune version
> installable. Le paquet ne l'avait jamais emporté, et le défaut persistait après mise à jour.
