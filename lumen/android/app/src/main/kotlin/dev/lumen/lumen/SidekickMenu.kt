package dev.lumen.lumen

import android.content.Context

/**
 * The Sidekick's own blob menu: what each of its five places holds. It is kept and saved
 * here, on Android, and nowhere else. Prism has a menu of its own and never changes this one.
 *
 * A place holds a key: "app:<package>", "action:<n>", "screen:<n>", "phone:shade",
 * "phone:side", or "empty:" when it holds nothing. The blobs always stand together: the
 * empty places are always the last ones.
 *
 * Everything done to it is done here: Remove, Change, Add, Add Blob, and putting the blobs in
 * a new order by dragging them. (For Change and Add, Prism's app list is still used to choose
 * from, for now: Prism only sends back the key that was chosen, and it is put in here.)
 *
 * What Prism does for it, one way: it draws the pictures. Whenever this menu changes, Prism is
 * told its keys ("sidekickKeys"), and answers with the name, colour and picture of each
 * ("sidekickPictures"). Prism keeps only the last keys it was told, to draw them and for the
 * flight recorder's report.
 *
 * Saved in Android's own settings for Prism (SharedPreferences "prism_sidekick"): "keys", the
 * five keys, one per line; "moved", what was taken over from Prism the one time it was.
 */
object SidekickMenu {
    const val PLACES = 5
    private const val EMPTY = "empty:"
    private const val STORE = "prism_sidekick"

    private var keys = Array(PLACES) { EMPTY }
    private var loaded = false

    /** Whether a menu has been saved here. Until the one-time move from Prism, none has. */
    private var own = false

    /** What was taken over from Prism, the one time it was; empty if that is not known. */
    private var moved = ""

    /** The pictures Prism last sent, by key. */
    private val pictures = HashMap<String, Floater.Pin>()

    /** The plus that stands alone in a menu with nothing in it. */
    private val plus = Floater.Pin("empty:0", "empty", 0, "", "", 0x00FFFFFF, null, false, 0, "", 0)

    private fun load(context: Context) {
        if (loaded) return
        loaded = true
        try {
            val p = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
            val saved = p.getString("keys", null)
            if (saved != null) {
                own = true
                keys = packed(saved.split('\n'))
            }
            moved = p.getString("moved", "") ?: ""
        } catch (e: Exception) {}
    }

    /** The places with the blobs together and the empty ones last, always five. */
    private fun packed(from: List<String>): Array<String> {
        val full = from.map { it.trim() }.filter { it.isNotEmpty() && !it.startsWith(EMPTY) }.take(PLACES)
        return Array(PLACES) { if (it < full.size) full[it] else EMPTY }
    }

    /** [now]: written before this returns (for the one-time move, after which Prism deletes its old copy). */
    private fun save(context: Context, now: Boolean = false) {
        try {
            val e = context.getSharedPreferences(STORE, Context.MODE_PRIVATE).edit()
                .putString("keys", keys.joinToString("\n")).putString("moved", moved)
            if (now) e.commit() else e.apply()
        } catch (e: Exception) {}
    }

    /** Its five keys, or null if it has none of its own yet (the one-time move has not happened). */
    fun keys(context: Context): List<String>? {
        load(context)
        return if (own) keys.toList() else null
    }

    /** The key in place [slot] ("empty:" for none). */
    fun keyAt(context: Context, slot: Int): String {
        load(context)
        return keys.getOrElse(slot) { EMPTY }
    }

    /**
     * The one-time move: the menu the Sidekick showed until now, worked out by Prism (its own
     * saved set if it had one, otherwise Prism's), is taken over. Only if there is none here
     * yet; after that it is ignored. Answers with the keys it has now.
     */
    fun adopt(context: Context, from: List<String>): List<String> {
        load(context)
        if (!own) {
            keys = packed(from)
            own = true
            moved = keys.joinToString(", ")
            Trail.add("Sidekick: its menu moved over from Prism, and kept here from now on: $moved")
            changed(context, now = true)
        }
        return keys.toList()
    }

    /** "Remove" in a blob's small menu: the others close up round the middle at once. */
    fun remove(context: Context, slot: Int) {
        load(context)
        if (!own || slot !in 0 until PLACES) return
        Trail.add("Sidekick: blob removed (${keys[slot]})")
        keys[slot] = EMPTY
        keys = packed(keys.toList())
        changed(context)
    }

    /** Change: place [slot] is given [key] ("empty:" takes it away, and the others close up). */
    fun put(context: Context, slot: Int, key: String) {
        load(context)
        if (!own || slot !in 0 until PLACES) return
        Trail.add("Sidekick: place ${slot + 1} given $key (it had ${keys[slot]})")
        keys[slot] = key
        keys = packed(keys.toList())
        changed(context)
    }

    /** Add: [key] goes right after the blob in place [slot]; the ones after it move along. Only while there is room. */
    fun addAfter(context: Context, slot: Int, key: String) {
        load(context)
        if (!own || key.startsWith(EMPTY) || keys.none { it == EMPTY }) return
        val list = keys.filter { it != EMPTY }.toMutableList()
        list.add((slot + 1).coerceIn(0, list.size), key)
        Trail.add("Sidekick: $key added after place ${slot + 1}")
        keys = packed(list)
        changed(context)
    }

    /**
     * The blobs were put in a new order by dragging: [slots] are the places they were in, as
     * they now stand. Those same places are handed out again in the new order.
     */
    fun arrange(context: Context, slots: List<Int>) {
        load(context)
        if (!own || slots.any { it !in 0 until PLACES }) return
        val was = keys.copyOf()
        val places = slots.sorted()
        for (j in slots.indices) keys[places[j]] = was[slots[j]]
        Trail.add("Sidekick: blobs put in a new order")
        changed(context)
    }

    /** Prism's pictures for the keys it was last told: the name, colour and picture of each. */
    fun pictures(context: Context, from: List<Floater.Pin>) {
        load(context)
        pictures.clear()
        for (p in from) pictures[p.key] = p
        show()
    }

    /** For the button test only: the menu set as it asks, to be put back as it was afterwards. */
    fun testPut(context: Context, from: List<String>) {
        load(context)
        keys = packed(from)
        own = true
        changed(context)
    }

    /** For the test report: what is kept here. */
    fun state(context: Context, into: HashMap<String, Any?>) {
        load(context)
        into["sidekickKeys"] = keys.toList()
        into["sidekickOwn"] = own
        into["sidekickMoved"] = moved
    }

    /** Saved, shown, and Prism told the keys, so that it sends their pictures. */
    private fun changed(context: Context, now: Boolean = false) {
        save(context, now)
        show()
        try { RestBubble.channel?.invokeMethod("sidekickKeys", keys.toList()) } catch (e: Exception) {}
    }

    /**
     * What the Sidekick's menu shows: each place that holds something whose picture has come,
     * in order, knowing which place it is in. (One whose picture has not come yet is shown once
     * it has.) With nothing in any place: one plus. Before the one-time move there is no menu
     * yet, and nothing is shown (not even the plus, which would invite a change before the move).
     */
    private fun show() {
        val shown = ArrayList<Floater.Pin>()
        if (!own) {
            RestBubble.setBlobs(shown)
            return
        }
        for (i in 0 until PLACES) {
            if (keys[i] == EMPTY) continue
            val p = pictures[keys[i]] ?: continue
            shown.add(p.inPlace(i))
        }
        if (keys.all { it == EMPTY }) shown.add(plus)
        RestBubble.setBlobs(shown)
    }
}
