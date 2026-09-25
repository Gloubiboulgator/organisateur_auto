# Les réglages du projet, et la fiche à dicter

> Ce fichier fait foi sur les clés de `apk-test.env` et sur le texte de la fiche d'observation
> que le skill fait ajouter au projet. Les scripts lisent les clés par `scripts/reglages.sh`.

## Le fichier `apk-test.env`

À la racine du projet, des lignes `CLE=valeur`. Toute clé se surcharge par une variable
d'environnement du même nom, ce dont la CI se sert pour ce qu'elle tient en secret. Le chemin
du fichier se surcharge par `APK_TEST_REGLAGES`.

Une clé requise absente arrête le script en la nommant. Aucune valeur par défaut ne désigne un projet réel.

Exemple minimal, à adapter.

```
PAQUET=fr.exemple.app
ACTIVITE_PRINCIPALE=.MainActivity
PARCOURS_KT=app/src/androidTest/java/fr/exemple/app/ParcoursVisuelTest.kt
ECRANS_GLOBS=app/src/main/res/layout/* app/src/main/java/fr/exemple/app/*Activity.kt
ARTEFACT_PARCOURS=parcours
```

## Les clés requises

| Clé | Sert à | Exigée par |
|---|---|---|
| `PAQUET` | `pm grant`, la ligne `Displayed`, `ANR in` | tous les scripts |
| `ACTIVITE_PRINCIPALE` | la ligne `Displayed`, dans la forme d'Android, `.MainActivity` | tous les scripts |
| `PARCOURS_KT` | le fichier Kotlin dont le seuil de captures se dérive | le parcours, les captures |
| `ECRANS_GLOBS` | les motifs git des fichiers d'écran, séparés par des espaces | les captures |
| `ARTEFACT_PARCOURS` | le nom de l'artefact publié par le job | le rapatriement |

## Les clés à défaut

| Clé | Défaut | Sert à |
|---|---|---|
| `PAQUET_TEST` | `$PAQUET.test` | la cible d'`am instrument` |
| `RUNNER` | `androidx.test.runner.AndroidJUnitRunner` | idem |
| `DOSSIER_APPAREIL` | `/sdcard/Android/data/$PAQUET/files/Pictures/parcours` | `adb pull` |
| `NOM_FILM` | `navigation.mp4` | le contrôle du film |
| `TEST_FILME` | `parcoursDeNavigationFilme` | les horodatages du test filmé |
| `TAG_JOURNAL` | `ParcoursVisuel` | les lignes du test sur `screenrecord` |
| `ARG_JETON` | `jetonTest` | l'argument d'instrumentation du jeton |
| `PERMISSIONS` | `android.permission.POST_NOTIFICATIONS` | accordées d'avance, espaces entre elles |
| `TESTS_EXCLUS` | vide | les classes de test lancées ailleurs, `-e notClass` |
| `CROCHET_APRES_INSTALLATION` | vide | un script du projet joué après `adb install` |
| `MOUTURES_SEUIL_DERIVE` | `debug` | les moutures soumises au seuil dérivé |
| `ECRANS_EXCLUS` | vide | les fragments non exigibles, motifs séparés par `\|` |
| `TAG_BASE` | `play/*` | le tag du dernier build publié |
| `SEUIL_CHARGE` | `8` | l'avertissement de charge |
| `MAQUETTES` | vide | le dossier des maquettes, nommées par écran, nommé par le relevé |
| `SEUIL_SCENE` | `0.3` | la sensibilité de la découpe du film |
| `PAS_FILM` | `5` | les secondes entre deux images plancher |

Quatre variables restent des variables d'environnement pures, jamais lues du fichier :
`JETON_TEST`, `COUPLES`, `SORTIE`, `PYTHON_BIN`.

## La fiche d'observation à dicter au projet

Le script du parcours arrête l'enregistreur avant de rapatrier le film. Il repose sur une
croyance jamais mesurée sur un runner : `screenrecord` n'écrit l'atome `moov` d'un MP4 qu'à la
fermeture du fichier. Le noyau ne peut pas la ficher lui-même, son registre des observations
est un gabarit vide chez chaque projet. Le skill la fait donc écrire par le projet, à l'étape 1,
dans son fichier d'observations, sous cette clé et avec ce texte.

```
### screenrecord-moov-a-la-fermeture

`screenrecord` n'écrit l'atome `moov` d'un MP4 qu'à la FERMETURE du fichier. Un enregistrement
tué sans avoir été arrêté laisse donc un fichier non vide et indécodable. Lui envoyer `SIGINT`
puis attendre que sa taille cesse de bouger doit suffire à obtenir un film lisible.

- **Observé :** non, pas sur ce runner. La propriété du conteneur MP4 relève de la connaissance
  générale, pas d'une mesure faite ici.
- **Preuve :** aucune. Le skill apk-test le déclare comme supposition à sa pose.
- **Si c'est faux :** le film reste indécodable après l'arrêt, et le contrôle du film fait
  rougir la chaîne à ce titre. La panne cesse d'être silencieuse.
  Canari : le script imprime ce que `pgrep screenrecord` trouve au moment du rapatriement, et
  la taille à laquelle le fichier s'est stabilisé. Un run où plus aucun processus ne tourne
  alors que le film est illisible invaliderait la prémisse, et le dirait dans le journal.
```

L'étiquette elle-même, `@suppose` suivi de la clé, se pose à l'étape 2 dans la copie du test
Kotlin **du projet**, au-dessus de l'arrêt de l'enregistreur. Le contrôle des étiquettes du
projet la rapproche alors de la fiche. Un projet dont le fichier d'observations a un autre
format adapte la fiche à son format, pas l'inverse.
