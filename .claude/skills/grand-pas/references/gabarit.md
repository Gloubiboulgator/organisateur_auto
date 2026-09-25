# Le gabarit du run

> Ce fichier fait foi sur la forme de ce que rend [`../SKILL.md`](../SKILL.md). La phrase
> d'ouverture, le menu, la note de décision et le rendu final. Le fond, les portées et les
> interdits vivent là-bas, leur propriétaire.

## La phrase d'ouverture

Elle sort en premier, en gras, telle quelle. Rien ne la précède, pas même un mot de politesse.

**« On met les bottes de 7 lieues ! Laisse moi voir... »**

La réflexion commence juste après, visible. Le menu vient quand le relevé est fait.

## Le menu, et sa ligne d'échappement

Sans argument, trois lignes, une par lettre, puis une ligne en italique. Chaque lettre dit ce
qu'il faut pour la choisir. La section suivante porte le menu d'un argument.

- A, jusqu'où vont les specs.
- B, les décisions produit que le run comblerait, à la louche.
- C, ce qu'il y a à solder.

**Par où on part**

**A** · **le pas sûr** — jusqu'à l'export de la liste de courses, là où les specs s'arrêtent.

**B** · **le pas long** — jusqu'au partage du carnet. Je tranche le format de l'invitation, la
durée du lien, et ce qu'on voit quand le lien est mort.

**C** · **tout solder** — 3 défauts, 7 items de roadmap et 4 issues, sans plafond.

*Ou dis ce que tu veux, par exemple « entre A et B », ou une cible.*

**Venu du départ D, le menu ouvre par un rappel.** Une ligne suffit, « ces lettres sont celles
du pas, pas celles du rapport ». Les deux menus portent A, B et C pour des choses différentes.
Répondre B d'habitude lancerait le pas long au lieu de réparer.

**Aucun compte de décisions.** Un run ne sait pas combien de trous il rencontrera avant d'y
être. Un chiffre donnerait du crédit à une devinette. B nomme les décisions, il ne les compte
pas.

**Le projet de cet exemple est inventé.** Ses caps, ses défauts et ses chiffres ne décrivent
aucun dépôt. Ils ne se recopient jamais dans un menu réel.

**Et il ne cite AUCUN chemin d'apparence interne.** Le contrôle 1 des projets équipés lit
tout `specs/….md` ou `docs/….md` du texte brut, accents graves compris. Il lit aussi tout lien
Markdown relatif vers un autre document, résolu depuis le dossier qui le porte. Les deux
en exigent la cible, et écrire le motif d'un lien suffit à le déclencher.

Un fichier inventé refusait donc tous leurs commits. Ce dépôt ne pouvait pas le voir, son lint
ne rendant un verdict qu'une fois posé dans un projet. Un exemple nomme donc sa source en
toutes lettres, « la spec du carnet ».

## Le menu d'un argument

Deux lignes, A et B, les rangs laissés de côté s'il y en a, puis la ligne d'échappement. Le
titre reprend l'argument tel qu'il a été écrit. Une ligne en italique dit dessous ce que le
dépôt en porte.

**Par où on part, pour « partager le carnet avec un proche »**

*Un item de roadmap, et la spec du carnet qui nomme déjà le lien.*

**A** · **le pas sûr** — jusqu'au lien de partage, sur le format que la spec du carnet nomme
déjà. Je m'arrête à la durée du lien, que rien ne tranche.

**B** · **le pas long** — jusqu'au carnet partagé, invitation comprise. Je tranche la durée du
lien, ce qu'on voit quand il est mort, et ce que le proche invité a le droit de faire.

**⚠️ hors de ce pas, la liste de courses double les articles au retour.**

*Ou dis ce que tu veux, par exemple « entre A et B », ou une limite de temps.*

**La ligne d'échappement n'invite pas à nommer une autre cible.** L'argument est déjà donné,
et une cible dite ici se lirait comme son remplacement. Or le menu est le seul arrêt, donc elle
vaudrait fin prévue.

**Un rang 🛑 ou ⚠️ hors de l'argument se nomme juste sous le menu**, en une ligne comme
ci-dessus. Le lot ne le porte pas, et l'admin doit le voir avant de choisir.

**Les deux lignes visent le bout de l'argument.** Aucune ne propose un premier pas, sinon le
menu rendrait ce que lakitu rend déjà.

**Pas de troisième ligne.** Le C du menu ordinaire vide les rangs, ce qui est exactement ne
rien viser en particulier.

**A vise ce bout sans promettre de l'atteindre.** Sa ligne dit où son régime l'arrête, et ce
point peut être proche. Promettre le bout sans trancher le structurant serait mentir.

**Un argument sans écrit le dit en ligne de tête**, par exemple « rien d'écrit sur ce point ».
Les deux plans sortent quand même, et ils n'inventent aucune spec.

**Venu du départ D, ce menu ouvre par le même rappel**, celui de la section précédente. Les
lettres sont celles du pas, pas celles du rapport.

**Cet exemple est inventé lui aussi**, et il reprend le projet du menu ordinaire.

## La note de décision

Un fichier par run, `docs/decisions/AAAA-MM-JJ-grand-pas.md`. Deux runs le même jour ajoutent un
suffixe, `-2`. Cible de longueur, cent cinquante lignes, celle de tout le dossier.

Elle s'écrit dans cet ordre, et l'en-tête se pose avant le premier point.

```
# Grand pas du AAAA-MM-JJ

Portée choisie : B, le pas long.
Fin prévue : le partage du carnet, invitation comprise.

## Les décisions

| Trou | Tranché | Raison | Provenance |
|---|---|---|---|
| format de l'invitation | un lien, pas un code | la spec du carnet parle déjà de lien | lu, la spec du carnet |
| durée du lien | sept jours | aucun écrit, une durée courte se prolonge, l'inverse non | tranché, l'autre choix était sans limite |

## Rangé en chemin

- ⚠️ la liste de courses double les articles au retour, registre Maintenant, puis plan
- 🧹 deux branches fusionnées traînent, backlog

## Abandonné

- l'aperçu avant impression, deux chemins tentés, le moteur de rendu manque.
  Fait : la spec. Reste : le code.
  À installer : le paquet « rendu-pdf », par `apt install rendu-pdf`.
```

**Un argument porte sa propre ligne d'en-tête**, juste avant la portée choisie. Il s'y recopie
tel quel, jamais reformulé, par exemple « Argument : partager le carnet avec un proche. »

Le reformuler en tête de note ferait disparaître la demande au profit de ce que le run en a
compris. C'est justement l'écart que l'admin vient vérifier.

**La note ne nomme jamais la branche.** Elle est jetable, et le `CLAUDE.md` interdit de citer
une branche jetable dans la doc. Un contrôle du doc-lint refuserait tout commit du projet une
fois la branche supprimée.

**Le rendu final la nomme, lui.** Il vit dans la conversation, pas dans un fichier suivi. Le
`CLAUDE.md` demande justement de situer le travail par son nom de branche, dans un échange.

**La provenance est le mot qui compte dans la table.** Une ligne « tranché » se relit. Une
ligne « lu » se vérifie en ouvrant le fichier. Sans elle, l'admin relit tout.

**« Abandonné » porte l'état, pas l'excuse.** Ce qui est fait, ce qui reste, où ça vit. C'est
la règle du chantier interrompu, et le run est le cas où personne ne peut la rappeler.

**Un outil manquant se nomme dans sa ligne d'abandon.** Le paquet et la commande d'installation,
en clair. Pointer « ci-dessus » vers une section que la note n'a pas laisse l'admin sans le
seul renseignement qui débloque.

## Le rendu final

Cinq blocs au plus, dans cet ordre, après le run. Les blocs 3 et 4 sautent quand ils sont
vides, comme le dit le dernier piège.

1. La fin prévue, et si elle est atteinte. Sinon, le bord touché, en une ligne.
2. Les décisions prises, la table de la note recopiée telle quelle.
3. Ce qui a été rangé, et où.
4. Ce qui a été abandonné, avec l'état laissé.
5. La livraison. La branche, le verdict de la revue, et l'état de la demande de fusion.

**🥾 LE PAS — atteint, le partage du carnet, invitation comprise**

**Les décisions**

*(la table de la note, sans une ligne de moins)*

**Rangé en chemin**

- ⚠️ la liste de courses double les articles au retour, registre Maintenant, puis plan
- 🧹 deux branches fusionnées traînent, backlog

**Abandonné**

- l'aperçu avant impression, deux chemins tentés, le moteur de rendu manque

**Livraison**

- branche `le-partage-du-carnet`, poussée
- revue de code passée deux fois, trois constats corrigés, la dernière est propre
- demande de fusion prête, la fusion est à toi

**Un run sous argument le nomme dans sa première ligne.** L'admin y relit ce qu'il a demandé,
pas seulement ce qui a été fait. « 🥾 LE PAS — partager le carnet avec un proche, atteint,
invitation comprise ».

**Un bord touché sous argument cumule les deux règles.** L'argument d'abord, le bord ensuite.
« 🥾 LE PAS — partager le carnet avec un proche, arrêté à la durée du lien, décision en A ».

**Un bord touché se rend comme un pas atteint.** La première ligne change, le reste non.
« 🥾 LE PAS — arrêté au choix du format d'invitation, décision structurante en portée A ».

**Une demande restée en brouillon se rend telle quelle.** Deux passes de revue qui ne
suffisent pas ferment le run sans « prête ». Un projet sans `/code-review` aussi. Le bloc
« Livraison » le dit, et les constats non corrigés vivent dans « Abandonné ».

- branche `le-partage-du-carnet`, poussée
- revue de code passée deux fois, deux constats corrigés, le troisième résiste
- demande de fusion **en brouillon**, le constat qui reste est en abandon

**Le brouillon n'est pas un échec à cacher.** Il dit à l'admin où ça coince. Une demande prête
que la revue n'a pas nettoyée lui coûte plus cher.

## Les pièges de mise en forme

**La phrase d'ouverture n'attend rien.** Elle sort avant la première lecture, sinon elle
raconte une réflexion déjà faite.

**Elle ouvre ce que grand pas rend, pas le tour entier.** Venu du départ D, le rapport de
lakitu précède donc légitimement. Ce qui est interdit, c'est qu'une lecture ou un constat de
grand pas sorte avant sa phrase. Le réalignement de la roadmap, lui, est son premier point de
run, et il sort après.

**Le menu ne rétrécit jamais de lui-même.** Trois lettres sans argument, même quand le relevé
est vide. A devient alors « rien à avancer », et B et C disent ce qu'ils iraient chercher.

**Deux lettres avec un argument, et jamais moins.** Le nombre suit la demande, pas ce que le
relevé a trouvé. Un menu à une seule ligne ne laisse plus rien à choisir.

**La fin prévue est une chose, pas un verbe.** « Jusqu'au partage du carnet », jamais
« avancer autant que possible ».

**La table ne se résume pas dans le rendu.** Elle se recopie entière. Résumer efface
précisément la ligne que l'admin aurait contestée.

**Une question dans le rendu est une faute.** Le rendu clôt. Ce qui reste ouvert vit dans
« Abandonné », avec son état, et l'admin décide seul de la suite.

**Un rang vide ne se mentionne pas.** « Rien rangé » et « rien abandonné » sont du bruit, le
bloc saute.
