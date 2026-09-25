package fr.exemple.app

import android.content.Intent
import android.os.Environment
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assume
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * PARCOURS VISUEL, gabarit du skill apk-test. À copier dans le dossier androidTest du projet,
 * puis à adapter : le paquet, les activités, les identifiants de vues, les noms de captures.
 *
 * Ce test ne vérifie presque rien tout seul : IL DONNE L'APP À VOIR. Il photographie chaque
 * écran et laisse un film du parcours, que l'agent lit en premier et que l'admin regarde ensuite.
 *
 * Pourquoi il existe : des tests qui lisent l'app comme du TEXTE vérifient qu'une ligne est
 * écrite, jamais qu'elle produit son effet. Un correctif clavier est parti vert et inerte chez le
 * projet d'origine, et des cafouillages de navigation n'ont été vus qu'une fois installés.
 *
 * SESSION AUTHENTIFIÉE : sans jeton, l'app s'arrête à l'écran d'accueil et rien d'utile n'est
 * atteignable. Le jeton d'un COMPTE DE TEST dédié est passé par l'argument d'instrumentation
 * `jetonTest`. Absent, les scénarios authentifiés sont IGNORÉS plutôt qu'en échec : un test
 * rouge par manque de configuration finit par être ignoré pour de bon.
 *
 * LE CONTRAT QUE LE SKILL LIT DANS CE FICHIER. Le seuil de captures se dérive de ce code par
 * scripts/captures-attendues.py. Il ne comprend que `photographier("littéral")`, une boucle
 * `repeat(n) { i -> }` dépliée, et des interpolations `${i}` ou `${i + k}`. Toute autre forme
 * est refusée et fait rougir la chaîne. C'est voulu : deviner rouvrirait le trou du plancher
 * à zéro. Un test conditionné au jeton se reconnaît à `assumeTrue` et au nom de l'argument.
 */
@RunWith(AndroidJUnit4::class)
class ParcoursVisuelTest {

    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val device: UiDevice = UiDevice.getInstance(instrumentation)

    /** Où l'émulateur dépose captures et film. Le script les ramasse à cet endroit exact. */
    private val sorties: File
        get() = File(
            instrumentation.targetContext.getExternalFilesDir(Environment.DIRECTORY_PICTURES),
            "parcours"
        ).apply { mkdirs() }

    /** Le jeton du compte de test, ou null. Fourni par `-e jetonTest …` à l'instrumentation. */
    private val jetonTest: String?
        get() = InstrumentationRegistry.getArguments().getString("jetonTest")?.takeIf { it.isNotBlank() }

    @Before
    fun preparerSession() {
        val jeton = jetonTest ?: return
        // À ADAPTER : l'app démarre appairée. On écrit le jeton là où elle le lit, avant toute
        // activité. Chez le projet d'origine, un coffre de jeton exposait un champ `token`.
        JetonStore(instrumentation.targetContext).jeton = jeton
    }

    /**
     * Ouvre un écran de l'app et attend qu'il soit là.
     *
     * Lancement par Intent plutôt que par `ActivityScenario` : cette classe vient d'une
     * bibliothèque de test que le projet ne déclare pas forcément, et parier sur une dépendance
     * indirecte a fait échouer le premier run réel du projet d'origine. Ici, rien que du
     * Android standard.
     */
    private fun ouvrir(ecran: Class<*>) {
        val ctx = instrumentation.targetContext
        ctx.startActivity(Intent(ctx, ecran).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP))
        device.waitForIdle()
    }

    /**
     * Tape sur un élément par son identifiant.
     *
     * UiAutomator plutôt qu'Espresso : une app faite de WebView se pilote mal avec Espresso, qui
     * attend la fin des animations et ne voit pas le contenu web. UiAutomator agit au niveau du
     * système, comme un doigt.
     *
     * Renvoie faux si l'élément n'apparaît pas dans le délai. Un écran qui tarde ne doit pas
     * faire tomber tout le parcours, il doit se voir sur les images.
     */
    private fun taper(idVue: String, delaiMs: Long = 8000): Boolean {
        ecarterDialogue()
        val cible = By.res(PAQUET, idVue)
        if (!device.wait(Until.hasObject(cible), delaiMs)) return false
        device.findObject(cible)?.click() ?: return false
        device.waitForIdle()
        return true
    }

    /**
     * Attend qu'un écran NATIF soit dessiné, en guettant une de ses vues.
     *
     * POURQUOI (run 31967863064 du projet d'origine) : la capture partait 600 ms après le geste,
     * et le journal système dit combien c'était court, jusqu'à cinq secondes entre le lancement
     * d'une activité et son affichage sur une machine chargée. Deux écrans réputés vus n'avaient
     * jamais été regardés.
     *
     * On guette une VUE de l'écran, son identifiant, pas un texte : le texte bouge à chaque
     * retouche de libellé, l'identifiant tient.
     */
    private fun attendreEcran(idVue: String, delaiMs: Long = 15000): Boolean =
        device.wait(Until.hasObject(By.res(PAQUET, idVue)), delaiMs)

    /**
     * Écarte une boîte de dialogue MODALE qui recouvrirait le parcours, avant chaque geste.
     *
     * POURQUOI (runs 31478214175 et 31505523569 du projet d'origine) : une boîte proposée par
     * l'app reste tant que personne n'y touche, et elle avale tous les taps suivants. Le parcours
     * se fige, mais rien ne le signale : `taper()` renvoie faux en silence, par design, et les
     * captures photographient la boîte en boucle. Deux runs ont été perdus comme ça.
     *
     * « Got it » couvre un bandeau SYSTÈME (run 31509968766) : Android affiche « Viewing full
     * screen » quand l'app passe en plein écran. Il recouvre le tiers HAUT de l'écran. Invisible
     * sur toutes les captures, c'est le FILM qui l'a révélé, entre deux photos.
     *
     * À ADAPTER : les libellés des boutons qui ferment les boîtes de CE projet.
     */
    private fun ecarterDialogue() {
        for (libelle in listOf("Plus tard", "Got it")) {
            val bouton = By.text(libelle)
            if (device.hasObject(bouton)) {
                device.findObject(bouton)?.click()
                device.waitForIdle()
                Thread.sleep(400)   // laisse la boîte se refermer avant le geste suivant
            }
        }
    }

    /**
     * Une capture nommée. Le nom compte : c'est lui qu'on lit dans le rapport, et c'est sur lui
     * que s'appuie le contrôle « tout écran modifié est photographié ». Il doit contenir le nom
     * de l'écran tel que verifier-captures.sh le dérive du fichier : « 04-creation » couvre
     * `activity_creation.xml` comme `CreationActivity.kt`.
     */
    private fun photographier(nom: String) {
        device.waitForIdle()
        Thread.sleep(600)   // laisse retomber les animations de transition
        // La boîte peut s'ouvrir APRÈS le tap qui l'a déclenchée : l'écarter seulement avant
        // les gestes ne suffit pas, elle serait encore là au moment de la photo.
        ecarterDialogue()
        val fichier = File(sorties, "$nom.png")
        // Le retour de takeScreenshot() était IGNORÉ (run 31509968766) : une capture manquait à
        // l'appel sans une ligne dans aucun journal, et le run est resté vert. On réessaie une
        // fois, puis on le DIT.
        if (!device.takeScreenshot(fichier)) {
            Thread.sleep(800)
            if (!device.takeScreenshot(fichier)) {
                android.util.Log.w("ParcoursVisuel", "capture « $nom » ÉCHOUÉE (deux tentatives)")
            }
        }
    }

    /**
     * LE PARCOURS DE NAVIGATION, filmé.
     *
     * Un aller simple ne montre pas les cafouillages : ce sont les RETOURS et les REBASCULES qui
     * déclenchent les flashs et les sauts. D'où les allers-retours répétés ci-dessous.
     *
     * À ADAPTER : les écrans, les identifiants d'onglets, les noms de captures. Garder la forme
     * des appels, c'est le contrat du seuil dérivé.
     */
    @Test
    fun parcoursDeNavigationFilme() {
        Assume.assumeTrue("aucun jeton de test fourni, parcours authentifié ignoré", jetonTest != null)

        val film = File(sorties, "navigation.mp4")
        // screenrecord tourne en fond pendant tout le parcours. Les deux issues du `try`
        // journalisent : au run 32254733286 du projet d'origine, AUCUNE des deux lignes n'est
        // apparue, ce qui ne laisse qu'une explication, la mort du processus d'instrumentation
        // pendant que le fil attendait encore.
        val debutFilm = System.currentTimeMillis()
        val enregistrement = Thread {
            try {
                val sortie = device.executeShellCommand(
                    "screenrecord --time-limit 120 --bit-rate 4000000 ${film.absolutePath}")
                val ecoule = (System.currentTimeMillis() - debutFilm) / 1000
                android.util.Log.w("ParcoursVisuel",
                    "screenrecord a rendu la main après ${ecoule}s, sortie: « ${sortie.trim()} »")
            } catch (e: Exception) {
                val ecoule = (System.currentTimeMillis() - debutFilm) / 1000
                android.util.Log.w("ParcoursVisuel",
                    "screenrecord INTERROMPU après ${ecoule}s : ${e.javaClass.simpleName}, ${e.message}")
            }
        }
        enregistrement.start()
        Thread.sleep(1500)   // laisse l'enregistrement démarrer avant le premier geste

        try {
            ouvrir(MainActivity::class.java).also {
                // On attend une vue de l'écran principal : l'app est alors dessinée.
                attendreEcran("ongletPremier")
                photographier("01-demarrage")

                // Aller simple : chaque destination une fois.
                taper("ongletPremier");  attendreEcran("listePremier"); photographier("02-premier")
                taper("ongletSecond");   attendreEcran("listeSecond");  photographier("03-second")
                // Un écran qui est une ACTIVITÉ à part se dessine plus tard qu'un onglet :
                // on attend une de ses vues avant la photo, sinon elle montre l'écran d'avant.
                taper("ongletCreer");    attendreEcran("saisie");       photographier("04-creation")

                // RETOURS et REBASCULES, la partie qui révèle les cafouillages.
                repeat(3) { tour ->
                    taper("ongletPremier")
                    taper("ongletSecond")
                    taper("ongletPremier")
                    attendreEcran("listePremier")
                    photographier("05-rebascule-tour${tour + 1}")
                }
            }
        } finally {
            // LE FILM S'ARRÊTE, IL NE S'ABANDONNE PAS (run 32254733286). `SIGINT` demande à
            // screenrecord de fermer son fichier, donc d'y écrire l'atome `moov`. Sans cette
            // ligne, `join()` expirait sur un enregistrement qui avait encore quarante secondes
            // à courir, et le processus mourait avec l'instrumentation.
            //
            // Dans un `finally` : une assertion tombée dans le parcours sautait l'arrêt, et le
            // film restait indécodable précisément quand on en avait besoin.
            device.executeShellCommand("pkill -INT screenrecord")
            enregistrement.join(20_000)
            if (enregistrement.isAlive) {
                // `join()` ne dit RIEN quand il abandonne, et c'est ce silence qui a coûté un run.
                android.util.Log.w("ParcoursVisuel",
                    "screenrecord n'a pas rendu la main 20 s après SIGINT, film probablement tronqué")
            }
        }
    }

    /**
     * L'écran d'accueil, atteignable SANS jeton, donc toujours photographié, même quand aucun
     * compte de test n'est configuré. C'est le filet minimal : si la chaîne ne produit que cette
     * image, c'est que la session n'a pas été fournie.
     */
    @Test
    fun accueilNonAppaire() {
        ouvrir(WelcomeActivity::class.java).also {
            attendreEcran("btnCommencer")
            photographier("00-accueil-non-appaire")
        }
    }

    private companion object {
        // À ADAPTER : le paquet de l'app, celui du réglage PAQUET de apk-test.env.
        const val PAQUET = "fr.exemple.app"
    }
}
