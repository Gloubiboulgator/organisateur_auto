# Les pièges de l'émulateur en intégration continue

> Ce fichier fait foi sur ce qui a coûté un run chez un projet équipé, entre le 2026-08-10 et
> le 2026-08-21. Chaque piège porte le numéro du run qui l'a révélé. Les scripts et gabarits
> du skill les parent déjà. Ce fichier dit pourquoi, pour qu'on ne défasse pas la parade.

## Le bloc `script:` est découpé ligne par ligne

Run 31428980946. L'action `reactivecircus/android-emulator-runner` n'exécute pas le bloc
`script:` comme un programme. Elle le fend à chaque retour à la ligne et lance chaque morceau
séparément. Une boucle `for` s'y retrouve amputée dès sa première ligne, et l'interpréteur
répond qu'il manque un `done`.

Le message est d'autant plus troublant que le script est
parfaitement correct.

Parade : le bloc `script:` ne contient qu'un appel à un fichier, où la logique peut respirer.

## La place sur le disque

Premier démarrage, 2026-08-10. Le téléphone virtuel se taille par défaut une réserve de 7,4 Go.
La machine prêtée n'en avait que 5,2 de libres, le SDK et les images système ayant mangé le
reste. Il ne démarrait pas, et l'outil qui lui parle tournait en boucle vingt minutes, à
chercher un appareil inexistant.

Parade : effacer les outils préinstallés dont le projet n'a aucun usage, ce qui libère une
vingtaine de gigaoctets, et demander `disk-size: 4096M`.

## La cible de l'image système

Trois cibles essayées, une observation datée par cible, chez un seul projet.

- `google_apis` tuait l'app en collatéral d'un ANR de `gms.persistent`, dont elle dépendait
  pour son fournisseur de polices. Trois runs, la même ligne à chaque fois.
- `aosp_atd` ne rendait pas l'écran du tout. Neuf captures noires, identiques au hachage près,
  et un film jamais fermé. Run 32238947304.
- `default`, AOSP pur, rend des captures distinctes et lisibles. Run de preuve 32251967011.

Parade : `target: default`. C'est une observation, pas une loi. Une app qui dépend de services
Google devra revérifier.

## Un dialogue recouvre tout le parcours

Runs 31471955570, 31478214175 et 31505523569. Trois boîtes distinctes ont bloqué le parcours,
chacune à son tour.

La demande de permission des notifications au démarrage. Une boîte de l'app elle-même,
proposant un accès système. Un bandeau d'Android, « Viewing full screen ».

Dans les trois cas, `taper()` renvoie faux en silence, par design, et les captures
photographient la boîte en boucle. Le run reste vert.

Parades, cumulées. `hide_error_dialogs 1` masque les boîtes d'erreur des autres apps. Les
permissions du réglage `PERMISSIONS` sont accordées d'avance par `pm grant`. Le gabarit Kotlin
écarte les boîtes connues avant chaque geste et avant chaque photo.

Et le verdict exige la ligne `Displayed` du journal système.

Un accès accordé par `adb` doit être RELU après coup. Au run 31505523569, la commande passait
sans erreur, et Android n'enregistrait que ses propres écouteurs. Le service valide la liste et
écarte ce qu'il n'a pas approuvé. Ce genre de geste vit dans `CROCHET_APRES_INSTALLATION`.

## Le jeton vide qui évapore un argument

Run 31431701893. Écrire `-e jeton "$JETON"` avec une valeur vide ne transmet pas une valeur
vide. La commande traverse un second interpréteur, celui du téléphone, qui fait disparaître
l'argument.

Le nom du robot est alors avalé comme valeur du jeton, et Android refuse la commande par sa
page d'aide. Aucun test ne tourne.

Parade : l'argument n'est construit que si le jeton existe.

## Le journal d'une mouture couvre la suivante

Sans `adb logcat -c` avant chaque instrumentation, un `Displayed` d'une mouture réussie
couvrirait à tort l'échec de la suivante. Le script vide le journal, puis le relit après.

## Le film abandonné

Run 32254733286. Le parcours durait 77 secondes pour une limite demandée de 120. L'enregistreur
tournait donc encore quand le test s'achevait, et rien ne l'arrêtait. Le fichier n'était jamais
fermé, gros et sans une image décodable, et il est parti comme artefact valide.

Parade, en deux endroits. Le gabarit Kotlin envoie `SIGINT` à `screenrecord` dans un `finally`,
puis attend le fil. Le script envoie le même signal avant de rapatrier, et attend que la taille
du fichier cesse de bouger. La croyance derrière, l'atome `moov` écrit à la fermeture, est une
supposition : le projet la fiche, voir [`reglages-et-fiches.md`](reglages-et-fiches.md).

## `ffprobe` absent ne faisait qu'avertir

Le contrôle du film n'a jamais tourné pendant des semaines : l'outil manquait sur le runner, et
son absence n'était qu'un avertissement. Parade : `ffmpeg` s'installe dans une étape à part, et
son absence fait rougir.

## `git rev-parse` écrit son argument

Run 32254733286. Quand il ne sait pas résoudre `HEAD~1`, `git rev-parse` écrit la chaîne
`HEAD~1` sur sa sortie standard, puis sort en erreur. Une substitution capturait donc une base
jamais vide, et le garde « aucune base » restait inatteignable. Le clone d'une chaîne ne portant
qu'un commit, c'est arrivé à chaque run.

Parade, en deux endroits qui vont ensemble : `--verify --quiet` dans le script, et
`fetch-depth: 0` dans le job. L'un sans l'autre laisse le trou, ou crie à chaque run.

## Un job sauté en amont annule l'aval

Quand on reprend un build existant, le job de compilation est sauté. GitHub considère par
défaut qu'un job sauté en amont annule tout l'aval, et une reprise ne testerait jamais rien.
Parade : une condition `always()` jointe à « amont réussi ou sauté », ce qui n'exclut que
l'échec. Le gabarit du job la porte.

## La capture qui échoue en silence

Run 31509968766. Le retour de `takeScreenshot()` était ignoré. Une capture manquait à l'appel,
sans une ligne dans aucun journal, et le run est resté vert. Parade : une seconde tentative,
puis une ligne de journal qui le dit.
