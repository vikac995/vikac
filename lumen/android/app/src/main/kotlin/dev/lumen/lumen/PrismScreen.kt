package dev.lumen.lumen

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * There is only ever one Prism screen (one [MainActivity], with one engine and one copy of
 * Prism). Every way Prism is brought forward goes through here.
 *
 * Why: Prism is the phone's home screen. Android keeps the screen it opens as the home screen
 * (the home button or gesture) in a task of its own, apart from the same screen opened any other
 * way (an app icon, the installer's "Open", or Prism's own "bring Prism forward"). Opened those
 * other ways while the home one is alive, Android made a second Prism screen, with a second
 * engine and a second copy of Prism; the Sidekick then talked to one while the other was on the
 * screen, and the two together held twice the memory (build 172's engine history: "#1 made",
 * five seconds later "#2 made").
 *
 * So every way Prism brings itself forward goes through [bringForward], which reaches the one
 * Prism screen with the same kind of launch that made it: the home screen's (Android hands it to
 * the home screen that is there) or an ordinary one (handed to the ordinary one that is there).
 * Either way it is the same screen, told what to do; no second one is made. With none alive, it
 * is started as the home screen if Prism is the home screen, so that the home gesture finds that
 * same one later. The app icon and the installer's "Open" go to [PrismLauncher], which does the
 * same. And should a second screen be made all the same, [MainActivity] closes one of the two at
 * once.
 */
object PrismScreen {
    /** The one Prism screen alive, if there is one. */
    var current: java.lang.ref.WeakReference<MainActivity>? = null

    fun alive(): MainActivity? = current?.get()?.takeIf { !it.isFinishing && !it.isDestroyed }

    /** Whether [intent] is a launch of Prism as the home screen (the home button or gesture, or Prism's own). */
    fun isHomeIntent(intent: Intent?): Boolean =
        intent != null && intent.action == Intent.ACTION_MAIN &&
            intent.categories?.contains(Intent.CATEGORY_HOME) == true

    /** Whether Prism is the phone's home screen just now. */
    fun isDefaultHome(context: Context): Boolean = try {
        val r = context.packageManager.resolveActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
            android.content.pm.PackageManager.MATCH_DEFAULT_ONLY,
        )
        r?.activityInfo?.packageName == context.packageName
    } catch (e: Exception) {
        false
    }

    /**
     * Brings Prism forward, with [action] for it to do ([Floater.OPEN_TRAIN],
     * [Floater.OPEN_ACTION] with [index], or [Floater.OPEN_ONLY] / null for nothing). [why] is for
     * the flight recorder.
     */
    /** How often Prism has been brought forward since it started: for the test report. */
    var forwards = 0
        private set

    fun bringForward(context: Context, action: String?, index: Int = 0, why: String) {
        forwards++
        val act = alive()
        val asHome = act?.isHomeScreen ?: isDefaultHome(context)
        Trail.add(
            "Prism brought forward ($why): " + when {
                act == null -> "no Prism screen alive, started ${if (asHome) "as the home screen" else "by name"}"
                asHome -> "the home screen that is there (engine #${act.engineNo})"
                else -> "the screen that is there (engine #${act.engineNo})"
            },
        )
        start(context, action, index, asHome)
    }

    /**
     * Starts or reaches Prism's screen. [asHome]: with the home screen's launch, for Prism alone,
     * carrying what to do in [OPEN] (so that it is not taken for the home button). Otherwise by
     * name, as Prism always did.
     */
    fun start(context: Context, action: String?, index: Int, asHome: Boolean) {
        val i = if (asHome) {
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).setPackage(context.packageName)
                .putExtra(OPEN, action ?: Floater.OPEN_ONLY)
        } else {
            Intent(context, MainActivity::class.java).setAction(action ?: Floater.OPEN_ONLY)
        }
        i.putExtra("index", index)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        try {
            context.startActivity(i)
        } catch (e: Exception) {
            Trail.add("Prism could not be brought forward: ${e.javaClass.simpleName}")
        }
    }

    /** What Prism is to do, on a launch sent as the home screen's (see [start]). */
    const val OPEN = "dev.lumen.PRISM_OPEN"

    /** What [intent] asks Prism to do: the one carried by [OPEN], or Prism's own action. */
    fun actionOf(intent: Intent?): String? = intent?.getStringExtra(OPEN) ?: intent?.action

    /** A short description of how a screen was opened, for the flight recorder. */
    fun describe(intent: Intent?): String = when {
        intent == null -> "nothing"
        intent.hasExtra(OPEN) -> "Prism itself, as the home screen"
        isHomeIntent(intent) -> "the home button or gesture"
        intent.categories?.contains(Intent.CATEGORY_LAUNCHER) == true -> "an app icon"
        intent.action == Floater.OPEN_TRAIN || intent.action == Floater.OPEN_ACTION || intent.action == Floater.OPEN_ONLY -> "Prism itself, by name (${intent.action?.substringAfterLast('.')})"
        else -> intent.action ?: "no action"
    }
}

/**
 * The app icon, and the installer's "Open": no screen of its own. It brings the one Prism
 * screen forward (or starts it, as the home screen if Prism is it) and is gone at once, so that
 * opening Prism this way never makes a second Prism screen.
 */
class PrismLauncher : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Trail.start(applicationContext)
        PrismScreen.bringForward(this, null, why = "an app icon or the installer's Open")
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }
}
