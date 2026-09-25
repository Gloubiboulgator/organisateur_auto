---
name: auto-learn-skill
description: >
  Transforme une dérive observée en session en garde-fou prêt à valider. Analyse
  pourquoi Claude a mal fait ou a laissé passer quelque chose. Vérifie
  d'abord si un garde-fou couvrait déjà ce cas et n'a pas tenu. Choisit une mécanique parmi
  les huit du dépôt. Prouve le garde-fou en l'exécutant, puis passe tout le projet au crible
  pour lister ce qui serait à corriger. Livre une proposition en français, mesurée au format
  du dépôt. S'invoque UNIQUEMENT sur commande explicite `/auto-learn-skill`. Ne se déclenche
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

Ce skill fait les quatre à la suite, puis s'arrête.

**Il n'écrit rien dans le dépôt avant la validation.** Il produit un texte prêt à coller, et
l'admin décide s'il s'insère. Le feu vert pour l'insérer se donne avec la validation, ou juste
après. L'insertion elle-même est décrite à l'étape 6.

## Quand il s'exécute

Sur commande explicite seule. L'admin vient de pointer, dans la conversation, quelque chose que
Claude a mal fait, mal dit, ou laissé passer.

Par défaut, la dérive à traiter est **celle qui vient de se produire dans cette conversation**.
Ne pas demander à l'admin de la redécrire, elle est déjà là. Un argument en texte libre remplace
ce choix par une autre dérive, présente ou passée.

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

## Étape 3. Le garde-fou

Lire [`references/mecaniques.md`](references/mecaniques.md), puis **nommer la mécanique
retenue**. Elle vient de cette liste de huit. Dire aussi pourquoi pas les sept autres, en une
ligne chacune, sans bloc vague.

Une étape 3 qui nomme une mécanique absente de la liste est invalide.

« Faire plus attention » n'est jamais un garde-fou. La question à laquelle il doit répondre est
précise : qu'est-ce qui, la prochaine fois, **empêcherait concrètement** de refaire cette
erreur ?

La huitième mécanique, la règle écrite, porte trois questions d'entrée dans la référence. Le
premier non ferme la porte. C'est le seul rempart contre un `CLAUDE.md` qui grossit à chaque
dérive.

## Étape 4. La preuve

Lire [`references/preuve.md`](references/preuve.md) et suivre son protocole. En résumé, et le
détail fait foi là-bas.

1. Écrire le contrôle candidat dans le répertoire temporaire de session, **jamais dans le
   dépôt**.
2. Le lancer sur le **cas fondateur**, qui doit rougir. Sinon il n'existe pas, et on s'arrête.
3. Le lancer sur au moins **trois cas légitimes tirés du vrai dépôt**, qui doivent rester verts.
4. Le lancer sur **tout le dépôt**, en lecture seule, pour obtenir la liste d'impact.

Quand la mécanique retenue est une règle écrite, il n'y a rien à exécuter. Le dire, et passer à
l'étape 5. Ne pas fabriquer une recherche décorative pour remplir la case.

## Étape 5. La proposition

Dix blocs, dans cet ordre.

1. **Ce qui s'est passé** — le symptôme, la citation exacte, la date du jour.
2. **Observé et déduit** — deux listes séparées, chaque ligne avec sa provenance.
3. **Ce qui existait déjà** — le verdict A, B ou C, et ce qui a été lu pour l'établir.
4. **Cause** — passée par les deux tests, ou bien « cause non établie ».
5. **Garde-fou proposé** — la mécanique nommée, et pourquoi pas les sept autres.
6. **Ce qu'il coûte** — la liste exacte des fichiers à toucher pour que ça tienne.
7. **Testé contre** — un tableau à trois colonnes : cas, attendu, obtenu.
8. **Passe sur le dépôt** — N fichiers balayés, M à corriger, et la liste.
9. **Prêt à coller** — l'item de backlog des findings, et la ligne du registre.
10. **Verdict** — PRÊTE ou PAS PRÊTE, avec la raison.

**Mesurer la proposition avant de la montrer.** L'écrire dans le répertoire temporaire, puis
lancer `scripts/doc-mesure.py` et `scripts/liens-glossaire.py --lint` dessus, en chemin absolu.
Corriger jusqu'aux compteurs de prose à zéro. Ce texte est destiné à devenir du texte du dépôt.
S'il n'est pas au format, c'est l'admin qui fait la mise en forme, et c'est exactement le geste
qu'on voulait lui épargner.

Deux nuances pour ne pas sur-interpréter le chiffre. La cible de longueur ne veut rien dire pour
une proposition de quarante lignes, seuls les compteurs de prose comptent. Les tableaux et les
blocs de code sont exclus de la mesure, donc libres de leur ponctuation.

## Une onzième issue, permise et assumée

Conclure que **ce cas ne mérite pas de garde-fou**, avec la raison. Une boucle qui ne sait pas
dire non produit des garde-fous de complaisance, et chacun coûte de l'entretien pour toujours.

## Étape 6. La validation

Présenter, puis s'arrêter. Ne rien écrire, ne rien committer, tant que l'admin n'a pas répondu.

Un ajustement demandé reprend à l'étape concernée, jamais de zéro. Une fois validée, le rôle du
skill s'arrête et l'insertion commence, sur le feu vert de l'admin. Sans ce feu vert, le texte
reste prêt à coller.

L'insertion couvre les fichiers du bloc 6 et les deux blocs prêts à coller du bloc 9. La session
les trie en deux tas.

- Les fichiers du projet s'éditent ici, puis suivent le chemin ordinaire d'un chantier. Branche
  jetable, demande de fusion en brouillon, revue.
- Les fichiers du noyau, ceux que liste `.noyau-empreintes`, se corrigent dans leur source, sur
  une branche du dépôt du noyau, puis se rediffusent. Édités sur place, `scripts/verifier-noyau.sh`
  refuse le commit. Si la source est hors d'atteinte, le dire, et laisser ces fichiers prêts à
  coller.
