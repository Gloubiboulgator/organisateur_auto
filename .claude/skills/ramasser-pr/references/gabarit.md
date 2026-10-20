# Le gabarit de ramasser-pr

> Ce fichier fait foi sur la forme de ce que rend [`../SKILL.md`](../SKILL.md). La phrase
> d'ouverture, la liste des demandes, le bilan posté et le rendu final. Le fond, le lot et les
> interdits vivent là-bas, leur propriétaire.

## La phrase d'ouverture

Elle sort en premier, en gras, telle quelle. Rien ne la précède, pas même un mot de politesse.

**« Fuuuu....sion!!! »**

Le relevé commence juste après, visible.

## La liste des demandes

Elle sort à la fin du relevé, avant la première demande menée. Un titre, puis une ligne par
demande ouverte, dans l'ordre du lot. Une ligne en italique dit dessous ce que le run prend.

**🗂️ Les demandes ouvertes**

- **#60** · prête, au repos · le partage du carnet passe par un lien de sept jours.
- **#61** · brouillon, au repos · l'export de la liste de courses sort aussi en tableur.
- **#62** · brouillon, au repos · le rappel du soir ne sonne plus deux fois le même jour.
- **#64** · brouillon, déjà tentée, rien de neuf · l'heure des rappels suit le fuseau.
- **#65** · brouillon, active il y a quarante minutes · la recherche lit aussi les notes.
- **#67** · brouillon, bloquée, attend l'admin · le thème sombre suit celui du téléphone.

*Je prends #60, #61 et #62. #64 n'a pas bougé depuis son bilan. #65 reste, une session y
travaille peut-être. #67 attend une décision.*

**Une ligne, une phrase.** Ce que la demande change pour qui s'en sert, jamais comment. Une
phrase qui nomme un fichier ou une fonction décrit le code, pas la demande.

**Un argument change la ligne en italique, pas la liste.** Toutes les demandes restent listées.
L'italique dit alors que seules les demandes nommées sont prises.

**Aucune demande ouverte donne une seule ligne**, « aucune demande ouverte, rien à ramasser ».
Le run s'arrête là, sans rendu final.

## Le bilan posté sur une demande qui ne part pas

Un commentaire sur la demande, en cinq lignes. Le run suivant le lit, l'admin aussi.

```
Bilan de ramasser-pr, tête 3f2a9c1, branche principale 8d41e07.
Cause : revue. Elle revient quand sa tête bouge.
Reste en brouillon : un constat survit à sa correction, la date du rappel décalée d'un jour.
Fait : la correction de l'affichage. Reste : le fuseau horaire.
Revues passées : 2. Vérification : contrôles locaux, verts.
```

**Les deux têtes et la cause disent quand la demande revient.** Tant que rien ne bouge, le
run suivant ne la reprend pas. Refaire deux revues sur le même constat ne fermerait rien.

## Le rendu final

Quatre blocs au plus, dans cet ordre, après le run. Un bloc vide saute.

1. Le bilan, en une ligne. Combien de demandes fusionnées sur combien dans le lot.
2. Les demandes, une ligne chacune, dans l'ordre où elles ont été menées.
3. Les demandes laissées, chacune avec sa raison.
4. Ce qui a été rangé, et la demande de rangement qui le porte.

**🌳 FUSION — 2 fusionnées sur 3**

**Les demandes**

- **#60** fusionnée. Première revue propre, sans CI, contrôles locaux verts.
- **#61** fusionnée. Deux revues, trois constats corrigés, CI verte.
  Symptôme si la prémisse est fausse, l'export sort vide. Passe parcours à lancer.
- **#62** repasse en brouillon. Un constat survit à sa correction, la date du rappel décalée
  d'un jour. Fait, la correction de l'affichage. Reste, le fuseau horaire. Bilan posté.

**Laissées**

- **#64**, déjà tentée, sa tête n'a pas bougé depuis son bilan.
- **#65**, active, dernière mise à jour il y a quarante minutes.
- **#67**, bloquée, sa note de décision porte un abandon.

**Rangé en chemin**

- ⚠️ le calcul du total arrondit deux fois, registre Maintenant, puis plan
- 🧹 un import mort dans le module des rappels, backlog
- les deux dans la demande de rangement **#68**, en brouillon

**Le projet de cet exemple est inventé.** Ses numéros, ses constats et ses symptômes ne
décrivent aucun dépôt. Ils ne se recopient jamais dans un rendu réel.

## Les pièges de mise en forme

**Une ligne de demande dit l'état, puis la raison.** « Reste en brouillon » sans le constat qui
résiste oblige l'admin à rouvrir la revue.

**« Reste » porte l'état, pas l'excuse.** Ce qui est fait, ce qui reste, où ça vit. C'est la
règle du chantier interrompu du `CLAUDE.md`.

**Le symptôme et la passe parcours ne vont qu'aux fusions visibles.** Une demande qui ne change
rien de ce qu'on voit n'en porte pas. Les ajouter partout les rendrait illisibles.

**Le rendu nomme les branches, la doc jamais.** Une branche fusionnée est supprimée, et une
mention dans un fichier suivi deviendrait un renvoi mort.

**Le rendu ne suffit pas à garder l'état.** Il vit dans la conversation, qui disparaît. Ce qui
reste d'une demande non partie vit dans son bilan posté.

**Aucune demande du lot ne manque au rendu.** Une demande absente a été perdue en route.
L'admin ne le verrait pas seul.
