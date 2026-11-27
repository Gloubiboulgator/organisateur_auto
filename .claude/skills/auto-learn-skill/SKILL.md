---
name: auto-learn-skill
description: >
  Transforme une dérive observée en session en garde-fou prêt à valider. Analyse
  pourquoi Claude a mal fait ou a laissé passer quelque chose. Fait d'abord valider le
  cadrage, la demande, le rendu, ce qui cloche et le résultat attendu. Vérifie ensuite si un
  garde-fou couvrait déjà ce cas et n'a pas tenu. Élargit au cas et à ses voisins proches, qui
  partagent sa cause. Choisit une ou deux mécaniques parmi les huit du dépôt. Prouve le
  garde-fou en l'exécutant, puis passe tout le projet au crible pour lister ce qui serait à
  corriger. Livre une proposition en français, mesurée au format
  du dépôt. Mène l'analyse dans un sous-agent, puis rend le fil de la tâche interrompue.
  S'invoque UNIQUEMENT sur commande explicite `/auto-learn-skill`. Ne se déclenche
  jamais tout seul sur une simple mention d'erreur.
---

# Auto-learn-skill

## But

Remplacer quatre relances manuelles par un seul passage. L'admin déroulait cette boucle à la
main, en quatre demandes.

- « Analyse pourquoi. »
- « Propose un garde-fou. »
- « Élargis, teste. »
- « Reformule proprement. »

Ce skill fait les quatre à la suite, puis s'arrête. Un seul arrêt les précède, obligatoire, la
validation du cadrage à l'étape 0. Sans elle, rien ne part.

**Il ne prend pas la place de la tâche en cours.** L'admin le lance souvent au milieu d'un autre
travail. Le cadrage et la validation restent dans la conversation. Les étapes 1 à 6 partent dans
un sous-agent, et seule la proposition en revient. La fin rend le fil à la tâche interrompue.

> Vécu le 2026-11-24, rapporté par l'admin. Lancé au milieu d'un autre travail, le skill
> remplissait la conversation de ses recherches. L'admin y perdait l'objectif de départ.

**Il n'écrit rien dans le dépôt avant la validation.** Il produit un texte prêt à coller, et
l'admin décide s'il s'insère. Le feu vert pour l'insérer se donne avec la validation, ou juste
après. L'insertion elle-même est décrite à l'étape 7.

## Quand il s'exécute

Sur commande explicite seule. L'admin vient de pointer, dans la conversation, quelque chose que
Claude a mal fait, mal dit, ou laissé passer.

Par défaut, la dérive à traiter est **celle qui vient de se produire dans cette conversation**.
Ne pas demander à l'admin de la redécrire, elle est déjà là. L'étape 0 lui fait seulement
valider ce que le skill en a compris. Un argument en texte libre remplace
ce choix par une autre dérive, présente ou passée.

**La dérive pointée est le cas fondateur, pas le périmètre.** Le périmètre est sa famille, que
l'étape 3 établit. L'admin attend qu'on règle ce cas et ses voisins proches.

## Étape 0. Le cadrage, validé avant tout

**Le fil d'abord.** Avant le cadrage, la session note la tâche que la commande interrompt. C'est
la tâche en cours au moment de la commande, même quand la dérive s'y est produite. Elle cite sa
demande, nomme sa branche et dit en une ligne où en était le travail.

Sans tâche en cours, elle l'écrit. Cette note sert à l'étape 7.

**Avant toute cause, faire valider le problème.** Quatre points, écrits depuis le journal de la
session. Puis on s'arrête.

1. **La demande de départ**, citée mot pour mot.
2. **Le rendu**, ce que Claude a livré, chaque écart nommé sans euphémisme. La ligne fautive se
   cite mot pour mot.
3. **Le problème que ça montre**, en une ou deux phrases.
4. **Le résultat attendu**, dans les mots de l'admin, cités. Une reformulation se marque comme
   telle.

> Vécu le 2026-11-15. Sans cadrage, le skill a enchaîné cinq propositions sur un problème mal
> cerné. L'une appelait « manque » un rendu que Claude avait refusé seul. L'admin a dû imposer
> ces quatre points lui-même.

**Une dérive passée, nommée en argument, se cite depuis le journal qui la porte.** Une demande
introuvable se dit introuvable, sans paraphrase déguisée en citation. L'admin la redonne à la
validation.

L'admin valide ou corrige. Une correction refait le cadrage, jamais l'analyse. Rien d'autre ne
se cherche avant la validation.

## Le relais vers le sous-agent

**Les étapes 1 à 6 se mènent dans un sous-agent**, de type `general-purpose`. C'est là que vit
le bruit, lectures, journaux et preuves. La session ne refait aucune de ces recherches.

Le sous-agent ne voit pas la conversation. Sa consigne porte donc tout ce qu'il ne peut pas
retrouver seul.

- le cadrage validé, tel quel
- la citation exacte de la faute, et le passage qui l'entoure
- le chemin du journal de la session en cours, pour les citations de l'étape 2 et les voisins de
  l'étape 3
- le chemin de ce skill, à suivre de l'étape 1 à l'étape 6
- le sens de « cette session » à l'étape 2. Ce que le journal montre lancé ou ouvert par la
  session de l'admin compte comme vérifié, citation du journal à l'appui.

**Le journal est le fichier `.jsonl` le plus récent** de `~/.claude/projects/<dossier du
projet>/`. La session le désigne par son chemin absolu. Introuvable, elle le dit, et la consigne
porte alors en entier les passages que les étapes 2 et 3 citeront.

**Il rend la main avec la proposition et son état.** La proposition est déjà mesurée, sortie des
deux outils jointe. L'état porte les verdicts, la cause, la famille, et les chemins du contrôle
candidat et de ses cas. La session vérifie que ces fichiers existent, puis montre la proposition
telle quelle à l'étape 7.

Un ajustement demandé relance le même sous-agent, à l'étape concernée. S'il ne peut pas
reprendre, un sous-agent neuf repart avec la consigne, l'état et l'ajustement.

**Sans sous-agent disponible, la session mène les étapes elle-même**, et le rendu le dit.

## Étape 1. La porte de l'existant

**Avant toute proposition.** La vraie question est rarement « quelle règle ajouter ». C'est
souvent « qu'est-ce qui existait déjà, et pourquoi ça n'a pas tenu ».

Lire le registre [`docs/garde-fous.md`](../../../docs/garde-fous.md), qui liste tout ce qui
protège le projet. Puis chercher les termes distinctifs de la dérive dans les endroits que le
registre désigne. Le `CHANGELOG.md` complète la vue, en disant si le cas a déjà été traité une
fois.

Le balayage débouche sur un **verdict écrit, obligatoire**, en trois branches.

- **A. Rien ne couvrait ce cas.** C'est le seul verdict où « ajouter quelque chose » est une
  réponse légitime.
- **B. Une règle écrite existait et n'a pas tenu.** Le sujet devient sa **mécanisation**.
  Proposer une deuxième règle écrite est interdit dans cette branche.
- **C. Un contrôle mécanique existait et n'a pas rougi.** C'est un trou de contrôle. Le livrable
  devient son **élargissement**, plus la preuve qu'il rougit maintenant.

Une étape 1 sans verdict nommé est invalide et se refait.

> Le motif de l'interdiction en B, écrit une fois pour toutes. Écrire une règle de plus dans un
> fichier qui vient de prouver que ses règles ne suffisent pas rend ce fichier plus long, donc
> moins lu. Le dépôt l'a formulé à sa façon en tête d'un de ses gardes : une règle écrite ne
> retient rien.

## Étape 2. La cause

**Trier avant de conclure.** Deux listes séparées, écrites avant toute cause : ce qui a été
**observé**, et ce qui en est **déduit**. Chaque ligne porte sa provenance, et il n'y en a que
trois valables.

- **vérifié**, en nommant la commande lancée ou le fichier ouvert dans cette session
- **rapporté**, l'admin l'a dit ou montré
- **tout le reste**, y compris ce que Claude croit savoir

Conséquence dure. **Une cause bâtie uniquement sur le troisième groupe n'est pas une cause.**

Écrire alors « cause non établie », et dire ce qu'il faudrait ouvrir pour l'établir. Une
explication annoncée comme trouvée, sans vérification, a déjà fait chercher l'admin
pendant une heure.

Deux tests avant de retenir une cause.

- **Substitution.** Remplacer la cause par « je n'ai pas fait assez attention ». Si la phrase
  reste vraie, ce n'est pas une cause, c'est le symptôme reformulé.
- **Moment.** La cause doit nommer l'instant où la mauvaise décision a été prise, et ce qui
  était disponible à cet instant sans être consulté. Sans ça, on ne saura pas où poser le
  garde-fou.

Citer le passage exact de la conversation, jamais une paraphrase.

## Étape 3. La famille

**Un garde-fou taillé au seul cas fondateur rate sa cible.** L'admin doit alors relancer, et
c'est cette relance que le skill devait lui épargner.

> Vécu le 2026-11-15. Le skill a d'abord visé un dessin fait en code à la place d'un outil de
> génération. L'admin a dû demander deux fois si le problème n'était pas plus large. La vraie
> faute était de choisir à sa place sans le montrer. Elle comptait cinq cas, dont trois sans
> aucun dessin.

**Nommer la faute au niveau de la décision, pas de l'outil.** C'est le test d'outil.
Remplacer l'outil ou le support de la faute par un autre. Si la phrase décrit encore une
faute, la famille est la phrase sans l'outil. « J'ai redessiné en code » devient « j'ai
tranché seul, en silence ».

**La cause de l'étape 2 borne la famille.** Un voisin en fait partie si la même cause
l'explique, au même moment de décision. Une faute qui demande une autre cause est une autre
dérive. Elle se note dans la proposition, elle ne s'absorbe pas.

**Une faute de silence appelle de la visibilité, pas une interdiction.** Quand la cause est un
choix caché, le garde-fou oblige à le montrer. Interdire l'outil qui a servi frappe aussi ses
usages légitimes. Le résultat attendu de l'étape 0 fait foi, jamais sa version durcie.

> Vécu le même jour. Le skill a voulu interdire tout dessin, puis tout ce qui ne venait pas de
> l'outil de génération. L'admin voulait un ordre de priorité, où un dessin reste possible s'il
> est signalé.

**Les voisins réels se cherchent avant d'en inventer.** Trois sources, dans cet ordre.

- le journal de la session en cours, en entier, pas seulement le dernier échange
- les journaux des autres sessions, par recherche ciblée sur les termes de la famille
- le `CHANGELOG.md` et le registre, pour les cas proches déjà traités

Les journaux des autres sessions ne se lisent jamais en entier. Le résultat est une liste
écrite. Chaque voisin porte sa citation ou son fichier, et sa provenance. Aucun voisin réel
trouvé se dit, avec ce qui a été balayé, puis se revérifie une fois, avec d'autres termes.

**Un secret ou une donnée personnelle ne sort jamais du journal.** Un journal peut porter un
jeton collé ou l'adresse d'une personne. La recherche compte d'abord ses lignes, puis n'ouvre que
les passages utiles.

Une citation coupe ce qui est sensible. Si rien ne reste, la provenance nomme
la session et sa date, sans renvoyer à la ligne. La proposition est faite pour entrer dans le
dépôt.

**La porte de l'existant se rejoue sur la famille.** L'étape 1 n'a jugé que le cas fondateur. Elle
se relance avec les termes de la famille, et chaque voisin reçoit son verdict A, B ou C. Un
voisin en B ne reçoit pas de seconde règle écrite. Un voisin en C fait élargir le contrôle qui l'a
manqué, jamais naître un contrôle parallèle.

## Étape 4. Le garde-fou

Lire [`references/mecaniques.md`](references/mecaniques.md), puis **nommer la mécanique
retenue**, ou les deux. Elles viennent de cette liste de huit. Dire aussi pourquoi pas les
autres, en une ligne chacune, sans bloc vague.

Une étape 4 qui nomme une mécanique absente de la liste est invalide.

**Le garde-fou répond au résultat attendu, point par point.** Chaque point du résultat attendu,
le quatrième du cadrage, reçoit ce qui le fait respecter. Ou bien rien, avec la raison.

**Le garde-fou se taille à la famille.** Pour chaque voisin de l'étape 3, dire s'il
l'attrape. Un voisin laissé passer porte sa raison, et la mécanique qui le couvrirait. Quand
une mécanique ne suffit pas, en proposer deux plutôt que de rétrécir la famille.

« Faire plus attention » n'est jamais un garde-fou. La question à laquelle il doit répondre est
précise : qu'est-ce qui, la prochaine fois, **empêcherait concrètement** de refaire cette
erreur ?

La huitième mécanique, la règle écrite, porte trois questions d'entrée dans la référence. Le
premier non ferme la porte. C'est le seul rempart contre un `CLAUDE.md` qui grossit à chaque
dérive.

## Étape 5. La preuve

Lire [`references/preuve.md`](references/preuve.md) et suivre son protocole. En résumé, et le
détail fait foi là-bas.

1. Écrire le contrôle candidat dans le répertoire temporaire de session, **jamais dans le
   dépôt**.
2. Le lancer sur le **cas fondateur**, qui doit rougir. Sinon il n'existe pas, et on s'arrête.
3. Le lancer sur **chaque voisin** de l'étape 3, et sur trois cas trop restreints inventés. Ils
   doivent rougir aussi, sauf le voisin que l'étape 4 laisse passer avec sa raison écrite.
4. Le lancer sur au moins **trois cas légitimes tirés du vrai dépôt**, qui doivent rester verts.
5. Le lancer sur **tout le dépôt**, en lecture seule, pour obtenir la liste d'impact.

Une règle écrite n'a rien à exécuter. Seule, elle le dit, et le skill passe à l'étape 6. Ne pas
fabriquer une recherche décorative pour remplir la case.

Avec deux mécaniques, chacune passe sa propre preuve. Un contrôle qui accompagne une règle écrite
passe les quatre lancements. Chaque voisin dit alors laquelle des deux le couvre.

## Étape 6. La proposition

Onze blocs, dans cet ordre.

1. **Ce qui s'est passé** — le cadrage validé à l'étape 0, la citation exacte de la faute, et
   la date du jour.
2. **Observé et déduit** — deux listes séparées, chaque ligne avec sa provenance.
3. **Ce qui existait déjà** — le verdict A, B ou C du cas fondateur et de chaque voisin. Puis
   ce qui a été lu pour les établir.
4. **Cause** — passée par les deux tests, ou bien « cause non établie ».
5. **La famille** — la faute nommée sans l'outil, et la liste des voisins avec leur source.
6. **Garde-fou proposé** — la mécanique nommée, ou les deux, pourquoi pas les autres, et les
   voisins qu'il laisse passer.
7. **Ce qu'il coûte** — la liste exacte des fichiers à toucher pour que ça tienne.
8. **Testé contre** — un tableau à trois colonnes : cas, attendu, obtenu.
9. **Passe sur le dépôt** — N fichiers balayés, M à corriger, et la liste.
10. **Prêt à coller** — l'item de backlog des findings, et la ligne du registre.
11. **Verdict** — PRÊTE ou PAS PRÊTE, avec la raison.

**Mesurer la proposition avant de la montrer.** L'écrire dans le répertoire temporaire, puis
lancer `scripts/doc-mesure.py` et `scripts/liens-glossaire.py --lint` dessus, en chemin absolu.
Corriger jusqu'aux compteurs de prose à zéro. Ce texte est destiné à devenir du texte du dépôt.
S'il n'est pas au format, c'est l'admin qui fait la mise en forme, et c'est exactement le geste
qu'on voulait lui épargner.

Deux nuances pour ne pas sur-interpréter le chiffre. La cible de longueur ne veut rien dire pour
une proposition de quarante lignes, seuls les compteurs de prose comptent. Les tableaux et les
blocs de code sont exclus de la mesure, donc libres de leur ponctuation.

## Une issue de plus, permise et assumée

Conclure que **ce cas ne mérite pas de garde-fou**, avec la raison. Une boucle qui ne sait pas
dire non produit des garde-fous de complaisance, et chacun coûte de l'entretien pour toujours.

## Étape 7. La validation

Présenter, puis s'arrêter. Ne rien écrire, ne rien committer, tant que l'admin n'a pas répondu.

**Rendre le fil à chaque arrêt.** Le message qui présente la proposition finit par la tâche
interrompue, notée à l'étape 0. Il la cite, et dit où elle en était. Le message qui clôt
l'insertion fait de même. La session reprend cette tâche dès que l'admin le dit, sans
redemander le contexte.

Un ajustement demandé reprend à l'étape concernée, jamais de zéro. Une fois validée, le rôle du
skill s'arrête et l'insertion commence, sur le feu vert de l'admin. Sans ce feu vert, le texte
reste prêt à coller.

**L'insertion part aussi dans le sous-agent**, dans un worktree à part, jamais dans le dossier de
la tâche interrompue. Sa branche et ses changements non commités restent donc intacts. Le
sous-agent rend la main avec les demandes de fusion ouvertes.

L'insertion couvre les fichiers du bloc 7 et les deux blocs prêts à coller du bloc 10. La session
les trie en deux tas.

- Les fichiers du projet s'éditent ici, puis suivent le chemin ordinaire d'un chantier. Branche
  jetable, demande de fusion en brouillon, puis prête, et la revue.
- Les fichiers du noyau, ceux que liste `.noyau-empreintes`, se corrigent dans leur source, sur
  une branche du dépôt du noyau, puis se rediffusent. Édités sur place, `scripts/verifier-noyau.sh`
  refuse le commit. Si la source est hors d'atteinte, le dire, et laisser ces fichiers prêts à
  coller.
