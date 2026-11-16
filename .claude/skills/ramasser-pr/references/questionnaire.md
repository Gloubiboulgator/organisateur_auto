# Le questionnaire de fin de run, puis ses réponses

> Ce fichier porte les étapes 6 et 7 de [`../SKILL.md`](../SKILL.md). La forme de la page et du
> bilan vit dans le [gabarit](gabarit.md). Les règles de tout questionnaire vivent dans
> [`../../../rules/ton-des-echanges.md`](../../../rules/ton-des-echanges.md).

## Le questionnaire de fin de run

Il porte ce qui retient les demandes menées qui ne sont pas parties. Ses réponses suffisent à
les fusionner, sans autre question. Il sort après le rendu, qui en donne le lien.

**Il naît quand une demande menée ne part pas**, cause revue, conflit ou vérification. Une
demande qui attend une approbation ou la fusion de l'admin n'y entre pas. Une demande laissée
non plus, active, brouillon ou déjà tentée.

**Une vérification rouge vaut un constat**, son échec cité. Une principale qui bouge encore n'en
est pas un. La demande n'y porte alors que « Ce que je règle seul », la refusion et la
revérification.

**Chaque constat qui reste se trie**, selon la règle des questionnaires de
[`../../../rules/ton-des-echanges.md`](../../../rules/ton-des-echanges.md).

- **Sa réponse change ce que l'admin voit, fait ou paie.** Il devient une question.
- **Un défaut à réparer, ou une mécanique interne.** Il va dans « Ce que je règle seul », avec
  le geste prévu.
- **Un conflit où les deux côtés changent la même logique** devient une question. Chaque option
  garde l'un des deux comportements, ou les marie.

**La page suit le modèle et les règles du projet.** Le modèle vit dans
`modeles/questionnaire.html`. La page tient une partie par demande, dans l'ordre du lot. Sa forme
vit dans le [gabarit](gabarit.md).

**Ce qui se voit se montre sur le produit réel.** La capture vient de la branche de la demande.
Chaque option y est simulée dans la page. Un dessin fait à part ne la remplace pas.

**Même une seule question part dans la page.** Ailleurs, la règle du projet laisse une question
isolée dans l'échange. Ici, la réponse est le feu vert d'une fusion. Elle se donne en un geste,
sur une page qui porte captures et sources, et que le run relit lui-même.

**Une demande sans question garde sa place.** « Ce que je règle seul » suffit alors, et sa
validation est le feu vert.

**Le bloc « Après tes réponses » ferme la page.** Il couvre chaque réponse possible, pas
seulement la recommandée. Une question laissée telle quelle vaut sa
recommandée, et la carte « Ce que je règle seul » vaut « Validé ». Il annonce aussi le refus
probable du harnais, et la commande qui le suivrait.

**La revue de conception passe avant la publication.** Un agent qui a le dépôt juge chaque
option, selon la règle des questionnaires.

**La lecture à froid la suit.** Un agent sans accès au dépôt redit chaque carte. Une carte qu'il
ne sait pas redire se réécrit, puis repasse la lecture. Les gardes du projet sur les
questionnaires tournent aussi.

> Incident fondateur. Le 2026-10-22, la première lecture à froid d'un questionnaire de ce skill
> a rejeté quatre cartes sur cinq. Elle y a trouvé une option écrite pour perdre et une
> contradiction entre un contexte et sa source. Une carte promettait aussi que rien ne
> changerait pour l'admin, à tort.

**Où elle vit.** Une page publiée dans la conversation, qui enregistre les réponses et permet de
les télécharger. Sans l'outil, un fichier HTML autonome, dont l'admin renvoie les réponses
téléchargées.

**Le bilan de chaque demande le dit**, sur une ligne de plus. Elle nomme les questions qui la
portent. Le gabarit en donne la forme.

## Le run des réponses

**Il part quand l'admin dit que la page est remplie.** Il lit les réponses enregistrées, ou le
fichier téléchargé que l'admin renvoie. Il ne pose aucune question.

**Une réponse se lit telle que la page la montre.** Sans réponse enregistrée, c'est la
recommandée. Une précision écrite s'applique avec son choix. « À reprendre » retire le point
nommé de « Ce que je règle seul », ou le remplace par ce que l'admin a écrit.

**Chaque demande se mène comme à l'étape 2 du skill**, une à la fois, dans l'ordre du lot. Un brouillon
passe en prête, la principale à jour se fusionne dans sa branche, et la tête distante se
contrôle avant chaque geste. Elle se compare à la tête que porte son bilan, faute de relevé.

**Une tête changée arrête la demande**, sans rien appliquer, et le rendu le dit. Le bilan déjà
posté perd sa ligne « Questionnaire », et garde ses deux têtes et sa cause. La demande reste en
brouillon. Elle revient au lot quand une session la remet en prête, ou quand l'admin donne son numéro.

**Les réponses s'appliquent, puis se consignent.** Chaque décision s'écrit là où le dépôt range
les siennes, spec, règle ou note de décision. Elle porte « Décidé par l'admin le », sa date, et
« par questionnaire ». La page, elle, ne fait jamais foi.

**Une réponse qui commande un travail, le run le lance.** Une relecture dédiée part dans une
session neuve, que le run attend. Il ouvre ensuite lui-même ses captures, et vérifie ce qu'elle
a changé.

**Une revue courte relit les corrections, et elles seules.** Elle se lance par `/code-review`
sur leur diff, avant le commit, au niveau que fixe [`tri-des-constats.md`](tri-des-constats.md).
Les revues de l'étape 3 du skill ont déjà eu lieu.

- **Un constat neuf qui ne touche aucun choix** va au rangement de fin de run. Il ne bloque pas
  la fusion. Il porte sur du code que les corrections ne changent pas.
- **Un constat qui montre qu'un choix ne marche pas comme prévu** arrête la demande. Elle reçoit
  son bilan, et entre au questionnaire suivant. Un défaut réel que les corrections introduisent
  l'arrête de même, rien ne fusionne avec lui. Un constat de forme sur les corrections part au
  rangement, puisqu'aucune correction ne suit la revue courte. Une forme qui demande une
  décision l'arrête, comme aux revues du run.

**La vérification et la fusion suivent l'étape 4 du skill.** Des contrôles rouges reçoivent une
correction. Au second rouge, la demande s'arrête avec son bilan. Un refus du harnais rend la
commande, dans la forme de [`fusion-admin.md`](fusion-admin.md).

> Décidé par l'admin le 2026-10-22, sur un premier questionnaire. Ses réponses ont suffi à
> fusionner deux demandes restées à l'arrêt après leurs deux revues.

**Le rendu suit le gabarit**, comme celui d'un run ordinaire. Il nomme les décisions consignées,
et le fichier qui porte chacune.
