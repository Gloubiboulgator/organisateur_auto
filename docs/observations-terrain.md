# Ce qu'on croit savoir du monde extérieur, et comment on le sait

> **Ce fichier fait foi** sur les croyances du projet. Chaque croyance qui vit dans le code y a
> sa fiche. Le contrôle 14 du doc-lint refuse le commit si une étiquette n'a pas la sienne.

## Le problème qu'on combat

Une croyance sur le monde extérieur s'écrit exactement comme un fait. Une ligne d'expression
régulière, un sélecteur, un seuil. Puis elle vit pour toujours, et personne ne sait plus si
quelqu'un l'a vérifiée un jour.

Pire, l'agent la prouve avec un test qu'il écrit lui-même sur sa propre croyance. Ce test reste
vert quoi qu'il arrive, y compris quand le monde extérieur a changé.

## Comment ça s'utilise

**Dans le code**, toute croyance porte une étiquette sur sa ligne.

- `@terrain <clé>` quand elle a été **observée**, par une capture ou par l'admin.
- `@suppose <clé>` quand elle ne l'a pas été.

**Ici**, chaque clé a sa fiche. Quatre lignes obligatoires, que le contrôle vérifie.

| Ligne | Ce qu'elle dit |
|---|---|
| `**Observé :**` | quand, et par qui ou par quel moyen |
| `**Preuve :**` | la capture, le fichier, l'observation qui la fonde |
| `**Si c'est faux :**` | le symptôme visible que produirait l'erreur |
| `**Canari :**` | facultatif, le signal lu à l'exécution qui crie quand la prémisse tombe |

**Une fiche réfutée ne se supprime pas.** Elle porte `— RÉFUTÉ` dans son titre, et sa ligne
`**Conséquence :**` remplace `**Si c'est faux :**`. Effacer une croyance fausse fait perdre la
leçon, et quelqu'un la réécrira.

## Les deux règles qui donnent son sens au registre

**Aucun affichage, aucune dépense, aucune suppression ne reposent sur un `@suppose`.** Une
supposition sert de repli prudent, jamais de décision. La suppression est le cas le plus
sournois. Un affichage faux se voit, une purge fondée sur une prémisse fausse détruit sans bruit.

**L'observation périme.** Une observation a une date, pas une garantie. Le monde extérieur change
sans prévenir. C'est le rôle du canari, quand il est possible.

## Le régime couvre aussi nos propres sorties

Toute heuristique sur la sortie de nos propres prompts est une supposition, au même titre qu'une
croyance sur un site externe. Elle porte donc son étiquette et sa fiche. La fiche **cite le
prompt** qui façonne cette sortie. Une contradiction entre l'heuristique et le prompt est un
défaut.

> Incident fondateur. Une heuristique lisait le type d'un objet dans le premier mot d'un titre.
> Les deux prompts de rédaction demandaient l'inverse, la marque d'abord. Un mois de traitement
> faux, sans que rien ne s'allume.

## Fiches

<!-- Un projet neuf démarre sans aucune fiche, et c'est normal. La première naît avec la
     première croyance écrite dans le code. Le gabarit ci-dessous montre la forme attendue.

### exemple-cle-a-remplacer

**Observé :** jamais, cette fiche est un gabarit.
**Preuve :** aucune.
**Si c'est faux :** rien, elle ne sert qu'à montrer la forme.
-->
