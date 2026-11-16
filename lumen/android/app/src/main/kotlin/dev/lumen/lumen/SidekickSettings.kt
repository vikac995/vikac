package dev.lumen.lumen

import android.content.Context

/**
 * The Sidekick's own settings, kept and saved here, on Android, from build 176 (step 2a). Until
 * then Prism kept them, each in a small file of its own, and sent them across.
 *
 * - [inApp], [overApps]: where it may be seen, over Prism and over other apps. (The rest timer
 *   follows these two as well, exactly as it always has: step 4 decides about that.)
 * - [gap], [tuck]: its two places at a side of the screen, in points: how far from the edge it
 *   rests, and how much of it shows when tucked in.
 * - [names]: Labels Show | Hide. [prismIcons]: Icons Prism | Regular. [vivid]: Colours Mellow |
 *   Vivid. [look]: which of the six looks its sign has, by id ("" is the first look).
 *
 * The one-time move: the first time this build starts, before anything is shown, the values are
 * read from Prism's old files (Prism's folder is the app's own, so it is read here directly,
 * whether or not Prism has started yet), saved here, and that is written in the flight recorder
 * with every value. Prism is then told, and deletes its old files.
 *
 * Prism still changes them for now, from the Sidekick's part of its settings panel
 * ("sidekickSet", answered with all of them), but they are kept here: Prism only keeps a copy
 * to show them, and asks for it when it starts ("sidekickSettings"). Prism's panel colours are
 * kept here too ([palette]), for the Sidekick's own panel in a later step.
 *
 * Saved in the same SharedPreferences as the Sidekick's menu ("prism_sidekick"), one key each.
 */
object SidekickSettings {
    private const val STORE = "prism_sidekick"
    // Hovering, from build 189: from 60 points past the edge (75% of the Sidekick, its glass, past
    // it; below 0 these are points at its standard size, and scale with it) to 36 from it. The
    // default stays 8. Tucked in: the least that shows is 18 points (8 until 189: about 13% more of
    // the Sidekick now).
    const val GAP_MIN = -60f
    const val GAP_MAX = 36f
    const val TUCK_MIN = 18f
    const val TUCK_MAX = 40f

    var inApp = true
        private set
    var overApps = true
        private set
    var gap = 8f
        private set
    var tuck = 22f
        private set
    var names = true
        private set
    var prismIcons = true
        private set
    var vivid = false
        private set
    var look = ""
        private set

    /** What the one-time move found and took, for the report; "" until it has happened. */
    var moved = ""
        private set

    /** Prism's panel colours, light and dark, as Prism last sent them (names to ARGB). */
    private val palette = HashMap<String, Int>()

    private var loaded = false

    /** Reads them, doing the one-time move first if it has not been done. Then they are in force. */
    fun load(context: Context) {
        if (loaded) return
        loaded = true
        try {
            val p = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
            if (p.getBoolean("settingsOwn", false)) {
                inApp = p.getBoolean("inApp", true)
                overApps = p.getBoolean("overApps", true)
                gap = p.getFloat("gap", 8f).coerceIn(GAP_MIN, GAP_MAX)
                tuck = p.getFloat("tuck", 22f).coerceIn(TUCK_MIN, TUCK_MAX)
                names = p.getBoolean("names", true)
                prismIcons = p.getBoolean("icons", true)
                vivid = p.getBoolean("vivid", false)
                look = p.getString("look", "") ?: ""
                moved = p.getString("settingsMoved", "") ?: ""
                for (k in p.all.keys) if (k.startsWith("palette.")) palette[k.removePrefix("palette.")] = p.getInt(k, 0)
            } else {
                moveFromPrism(context)
            }
        } catch (e: Exception) {
            Trail.add("Sidekick settings: could not be read (${e.javaClass.simpleName}); the defaults are used")
        }
        apply(context)
    }

    /**
     * The one-time move. Each value is what the Sidekick showed until now: its own file if one
     * was ever written, otherwise what it followed (Prism's own Labels, Colours and Look), as
     * Prism worked it out.
     */
    private fun moveFromPrism(context: Context) {
        val found = ArrayList<String>()
        // Prism wrote to the app's files folder, or to its temporary folder where that did not
        // exist yet (Dart's own temporary folder: one of the two cache folders).
        val dirs = listOf("files" to context.filesDir, "cache" to context.cacheDir, "code cache" to context.codeCacheDir)
        fun read(name: String): String? {
            for ((where, dir) in dirs) {
                try {
                    val f = java.io.File(dir, name)
                    if (f.isFile) {
                        found.add("$name in $where")
                        return f.readText().trim()
                    }
                } catch (e: Exception) {}
            }
            return null
        }
        read("prism_floating")?.split(' ')?.let { w ->
            inApp = w.getOrNull(0) != "0"
            overApps = w.getOrNull(1) != "0"
        }
        read("prism_side_spots")?.split(' ')?.let { w ->
            w.getOrNull(0)?.toFloatOrNull()?.let { gap = it.coerceIn(GAP_MIN, GAP_MAX) }
            w.getOrNull(1)?.toFloatOrNull()?.let { tuck = it.coerceIn(TUCK_MIN, TUCK_MAX) }
        }
        val prismNames = read("prism_blob_names")?.let { it != "0" } ?: true
        names = read("prism_blob_names_side")?.let { it != "0" } ?: prismNames
        prismIcons = read("prism_icons_blobs")?.let { it != "0" } ?: true
        // Prism's own look and colours, with the old Vivid looks of builds 134 to 138 read as Prism reads them.
        var prismLook = read("prism_blob_look") ?: ""
        var prismVivid = read("prism_blob_vivid") == "1"
        if (prismLook == "vivid" || prismLook == "vividtriangle" || prismLook == "vividwindow") {
            prismLook = "window"
            prismVivid = true
        }
        look = read("prism_side_look")?.takeIf { it.isNotEmpty() } ?: prismLook
        vivid = read("prism_side_vivid")?.let { it == "1" } ?: prismVivid
        moved = "${describe()}; read from: ${if (found.isEmpty()) "nothing (the defaults)" else found.joinToString(", ")}"
        save(context, now = true)
        Trail.add("Sidekick settings moved from Prism, and kept here from now on: $moved")
    }

    private fun describe(): String =
        "in this app ${onOff(inApp)}, over other apps ${onOff(overApps)}, distance ${fmt(gap)}, tucked ${fmt(tuck)}, " +
            "labels ${if (names) "show" else "hide"}, icons ${if (prismIcons) "Prism" else "regular"}, " +
            "colours ${if (vivid) "vivid" else "mellow"}, look ${look.ifEmpty { "(the first)" }}"

    private fun onOff(b: Boolean) = if (b) "on" else "off"
    private fun fmt(v: Float) = if (v == Math.floor(v.toDouble()).toFloat()) "${v.toInt()}" else String.format(java.util.Locale.ROOT, "%.1f", v)

    /** [now]: written before this returns (the move: Prism deletes its old files once told). */
    private fun save(context: Context, now: Boolean = false) {
        try {
            val e = context.getSharedPreferences(STORE, Context.MODE_PRIVATE).edit()
                .putBoolean("settingsOwn", true)
                .putBoolean("inApp", inApp).putBoolean("overApps", overApps)
                .putFloat("gap", gap).putFloat("tuck", tuck)
                .putBoolean("names", names).putBoolean("icons", prismIcons)
                .putBoolean("vivid", vivid).putString("look", look)
                .putString("settingsMoved", moved)
            for ((k, v) in palette) e.putInt("palette.$k", v)
            if (now) e.commit() else e.apply()
        } catch (e: Exception) {
            Trail.add("Sidekick settings: not saved (${e.javaClass.simpleName})")
        }
    }

    /** Puts them in force: the Sidekick, and the timer for the two switches and the distances, exactly as Prism's messages did. */
    private fun apply(context: Context) {
        for (b in Floaters) {
            b.floatIn = inApp
            b.floatOut = overApps
            b.restGap = gap
            b.tuckOut = tuck
        }
        RestBubble.blobNames = names
        RestBubble.look = look
        RestBubble.vivid = vivid
    }

    /**
     * Prism's settings panel changed some of them ([a]: any of the keys of [state]). [show]
     * ("rest" or "tuck") puts the Sidekick in that place now, while a distance is being chosen.
     * [keep] false: in force at once but not saved yet (a slider still being dragged).
     */
    fun set(context: Context, a: Map<*, *>, show: String?, keep: Boolean, fromPanel: Boolean = false) {
        load(context)
        val was = describe()
        (a["inApp"] as? Boolean)?.let { inApp = it }
        (a["overApps"] as? Boolean)?.let { overApps = it }
        (a["gap"] as? Number)?.let { gap = it.toFloat().coerceIn(GAP_MIN, GAP_MAX) }
        (a["tuck"] as? Number)?.let { tuck = it.toFloat().coerceIn(TUCK_MIN, TUCK_MAX) }
        (a["names"] as? Boolean)?.let { names = it }
        (a["prismIcons"] as? Boolean)?.let { prismIcons = it }
        (a["vivid"] as? Boolean)?.let { vivid = it }
        (a["look"] as? String)?.let { look = it }
        apply(context)
        for (b in Floaters) {
            if (show != null) b.showSpot(show == "tuck")
        }
        if (a.containsKey("inApp") || a.containsKey("overApps")) {
            for (b in Floaters) b.refresh(context)
            // (Switched on again, the Sidekick is there again.)
            RestBubble.showSide(context, false)
        } else {
            RestBubble.redraw()
        }
        if (!keep) return
        save(context)
        val now = describe()
        // (Prism is told them in the answer to its own change: see the "sidekickSet" handler. A
        // change in the Sidekick's own panel is told to Prism here, for its copy.)
        if (now != was) Trail.add("Sidekick settings changed by ${if (fromPanel) "its own panel" else "Prism's panel"}: $now")
        if (fromPanel) RestBubble.toPrism("sidekickSettings", state(context))
    }

    /** One of Prism's panel colours ("light.surface", "dark.ink", …), or "dark": 1 if Prism is dark; null if not sent yet. */
    fun paletteColour(name: String): Int? = palette[name]

    /** Prism's panel colours ([a]: "light.surface", "dark.ink" and so on, to ARGB), kept for the Sidekick's own panel. */
    fun setPalette(context: Context, a: Map<*, *>) {
        load(context)
        var changed = false
        for ((k, v) in a) {
            val key = k as? String ?: continue
            val c = (v as? Number)?.toInt() ?: continue
            if (palette[key] != c) {
                palette[key] = c
                changed = true
            }
        }
        if (changed) {
            save(context)
            Trail.add("Sidekick: Prism's panel colours kept (${palette.size} colours)")
        }
    }

    /** What they are now, as told to Prism and written in the test report. */
    fun state(context: Context): HashMap<String, Any?> {
        load(context)
        return hashMapOf(
            "inApp" to inApp, "overApps" to overApps, "gap" to gap.toDouble(), "tuck" to tuck.toDouble(),
            "names" to names, "prismIcons" to prismIcons, "vivid" to vivid, "look" to look,
            "moved" to moved, "palette" to palette.size,
        )
    }
}
