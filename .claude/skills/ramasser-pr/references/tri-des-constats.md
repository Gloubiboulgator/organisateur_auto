# Le tri des constats de revue

> Ce fichier porte le tri de l'étape 3 de [`../SKILL.md`](../SKILL.md), après la règle du premier
> genre. Celle-ci reste là-bas, son propriétaire. Il porte aussi le niveau de chaque revue, et
> l'agent de la troisième.

## Le niveau de chaque revue

**Chaque revue nomme son niveau.** Sans niveau nommé, `/code-review` reprend le dernier que
l'admin a tapé. La sévérité changerait alors d'un run à l'autre.

- **La première et la seconde revue** tournent au niveau `medium`.
- **La troisième revue** tourne au niveau `low`.
- **Une revue courte** tourne au niveau `low`. Elle relit des corrections seules, une fois, au
  run des réponses, après la troisième revue ou après la revue unique. Après l'une ou l'autre, une
  seule revue courte relit ensemble les corrections qui suivent, conflit et vérification rouge
  compris.

**Une zone sensible garde le niveau `high`.** Une demande qui touche un chemin listé dans
`scripts/zones-sensibles.txt` passe ses deux premières revues à ce niveau. La troisième et les
revues courtes restent en `low`.

La liste qui fait foi est celle de la branche principale. Ce fichier appartient au projet. Absent
ou vide, il ne change rien.

## Le nombre de revues

**Le nombre de revues suit ce que change la demande.** Il se fixe avant la première.

- **Du code qui touche aux données ou au comportement**, ou un mélange : les trois revues.
- **Tout autre code**, comme des tests ou un outil : les trois revues aussi.
- **De la documentation seule, ou des données déjà vérifiées** : une seule revue, au niveau
  `low`, sans seconde passe. Ses constats se corrigent, puis la demande continue.
- **Un fichier que les agents suivent** : les trois revues, même sans code. C'est le cas de
  `CLAUDE.md`, de `.claude/`, et de `noyau/` et `gabarits/` dans le dépôt qui les diffuse. Seuls
  une rediffusion et un texte court du noyau y échappent.

**Le doute va au régime complet**, quel que soit le cas.

**La revue unique remplace les points 2 et 3 de la liste de l'étape 3.** Sa correction passe les
contrôles seuls. La vérification de l'étape 4 suit, et la session ne lance aucun agent.

**Pour l'étape 4, elle est la dernière revue.** Un conflit ou une vérification rouge passe une
revue courte. Un constat sans correction, ou une forme qui demande une décision, retient la
demande.

**Une rediffusion du noyau ne relit pas ses copies.** Ce sont les fichiers de
`.noyau-empreintes`, déjà relus dans son dépôt. Décidé par l'admin le 2026-10-30.

**Le run compare chaque empreinte de `.noyau-empreintes` à celle du fichier sous `noyau/`.** Il
lit le noyau au commit que note `# version-noyau:`. Le run relance aussi
`scripts/verifier-noyau.sh` sur la tête, qui ne suffit pas, car il ne lit que les empreintes de
la demande. Un écart, un bricolage, un retard ou une comparaison impossible rendent aux copies le
régime complet.

**Les autres fichiers passent une revue `low`**, sans seconde passe. Sans autre fichier, la
demande ne passe aucune revue. Une zone sensible ne vise que ces fichiers-là.

**Un texte court du noyau passe la revue unique.** Il ne touche que `noyau/docs/`,
`gabarits/docs/` et `CHANGELOG.md`. Il change trente lignes au plus, ajoutées et retirées
comprises. Décidé par l'admin le 2026-10-30, après une règle de 24 lignes qui a pris dix minutes
et trois revues. Le seuil de trente lignes est un choix de l'agent.

**Un skill, une règle, un script ou un `CLAUDE.md` gardent les trois revues**, car ils pilotent
les agents. Une page dont un bloc se recopie dans `.claude/rules/` les garde donc aussi.

**Une zone sensible prime sur la revue unique.** Une demande qui en touche une passe ses trois
revues, même sans code.

**Des données déjà vérifiées** sont des fichiers de données seuls, dont la description de la
demande nomme le contrôle qui les a vérifiées. Ce contrôle est un script que la branche principale
porte déjà, jamais une commande libre ni un outil que la demande ajoute. Le run le relance sur la
tête de la demande. Sans contrôle nommé, ou s'il ne repasse pas, elles passent les trois revues.

> Décidé par l'admin le 2026-10-30, par questionnaire, après un audit de l'usage. Chez un projet
> équipé, douze revues de documentation avaient relevé dix-huit constats, et six n'avaient rien
> trouvé. Sur du code, une revue en relevait plus de quatre.

## Ce qui se corrige

**Un défaut réel se corrige toujours.** Un défaut réel est ce que la demande fait de faux. Un
bug, une donnée perdue ou abîmée, une faille. Un garde ou un contrôle qui ne fait pas ce qu'il
dit. Un fait faux écrit dans la doc.

**La forme se corrige aussi.** Une unité mal choisie, une redite en prose, une lenteur sans
effet visible, ou un risque à venir. Ce risque ne casse encore aucun cas réel. Une forme à
corriger passe par la passe de correction, puis par la revue suivante.

**Une forme qui demande une décision retient la demande**, à chaque revue. Elle reçoit son bilan,
et entre au questionnaire suivant.

## La troisième revue et son agent

**La session lance l'agent de la troisième revue.** Le run se mène dans un sous-agent, qui n'a
pas toujours l'outil Agent. Il rend donc la main à la session avant la troisième revue, comme
le dit [`sous-agent.md`](sous-agent.md).

**La session lance l'agent par l'outil Agent**, avec le paramètre `model` à `fable`. Elle lui
nomme son dossier de travail, le clone où le run a préparé la branche de la demande. Elle
relance ensuite le run avec son résultat.

**L'agent lance la revue au niveau `low`, puis corrige ses constats.** Il corrige tout constat
neuf du premier genre, forme comprise. Il rend la liste de ce qu'il a corrigé, et de ce qu'il
n'a pas pu corriger.

**Il commite sur la branche de la demande, sans pousser.** Avant chaque commit, il fait
l'impact-grep du `CLAUDE.md` sur les termes changés. Ses commits passent les hooks du projet. Le
message suit l'usage, « Traiter la revue de la NN ».

**Le run pousse lui-même les commits de l'agent.** Cette tête devient celle qu'il a poussée,
la référence de son contrôle avant chaque geste. Une poussée de l'agent ferait croire à une
autre session encore active.

**Ce qu'il ne sait pas corriger sans décision retient la demande.** Elle reçoit son bilan, et
entre au questionnaire suivant. Un constat hors du changement part au rangement, comme aux
autres revues.

**Ses corrections passent les contrôles seuls**, puis la vérification de l'étape 4. Aucune revue
ne les relit. C'est l'une des exceptions à la revue propre qu'exige le rendu final.

**Un constat resté sans correction retient aussi**, quelle que soit la revue qui l'a rendu. Toute
revue courte suit la règle que [`questionnaire.md`](questionnaire.md) donne à
celle du run des réponses.

## D'où vient le tri

Décidé par l'admin le 2026-10-27, après un run où trois demandes sur trois sont reparties en
brouillon. Chaque revue rendait huit à dix constats, et un seul détail de forme suffisait à
retenir une demande.

> Décidé par l'admin le 2026-10-27, par questionnaire. Trois revues au plus, deux au niveau
> `medium` puis une au niveau `low`. Tout constat neuf de la seconde revue compte, forme
> comprise. Une forme à corriger passe par la correction, puis par la revue suivante.

> Décidé par l'admin le 2026-10-27 : « et la 3e en niveau bas se fait avec fable, qui corrigera
> ces findings ».

> Décidé par l'admin le 2026-10-27, par questionnaire. La session lance l'agent de la troisième
> revue. Ses corrections passent les contrôles seuls, et la règle du rendu final l'admet. Une
> forme qui demande une décision retient la demande, à chaque revue.

> Décidé par l'admin le 2026-10-27, par questionnaire. Après la troisième revue, une vérification
> rouge reçoit sa seule correction, relue par une revue courte. Un conflit à la refusion de la
> branche principale suit la même règle. Dix retouches de cohérence, validées sans changement.

> Décidé par l'admin le 2026-10-30 : « Troisième en low ». En zone sensible, les deux premières
> revues tournent en `high`, et chaque correction y est relue par la suivante. La troisième et les
> revues courtes restent en `low`. Les corrections de la troisième ne sont relues par personne, et
> une revue `high` en produirait davantage, ou retiendrait la demande sur des détails.

**La valeur `fable` est observée.** La session l'a lue le 2026-10-27 parmi les valeurs permises
du paramètre `model`, dans la définition de son outil Agent.

**Deux lectures complètent ces réponses**, faute d'une réponse qui les tranche. Elles suivent le
texte de l'admin au plus près.

- **La règle choisie pour la seconde revue se lit forme comprise.** Une passe de correction suit
  désormais chaque revue. Aucun constat neuf n'est donc laissé de côté parce qu'il n'est que de la
  forme. À la troisième revue, l'agent le corrige au lieu de retenir la demande.
- **Une revue courte garde le niveau `low`** que la demande lui donnait. Les réponses n'en parlent
  pas. Celle du run des réponses garde sa règle sur la forme, que la troisième question ne visait
  pas.
