package dev.lumen.lumen

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas

/**
 * One thing a Sidekick blob can be (build 200): its kind ("app", and later "action" or "screen"),
 * its key as the blob menus keep it ("app:com.whatsapp", "action:2", "screen:1"), what it is
 * called, and for an app its package (for its icon). Nothing here assumes it is an app beyond that.
 */
internal data class Choice(val kind: String, val key: String, val label: String, val pkg: String = "")

/**
 * The things the Sidekick's own app list offers (build 200, "the Sidekick's own app list"): every
 * app on the home screen, A to Z, and the most used of them first ("Suggested").
 *
 * - **Most used:** by how long each was in front over the last 14 days, from Android's usage stats,
 *   when Prism may read them (it may, for screen time); otherwise by how often each was opened from
 *   Prism or the Sidekick (counted here, from build 200); otherwise A to Z.
 * - **Icons:** drawn from each app's own, as wanted, away from the main thread, and kept only while
 *   the list is open (at most about 12 MB).
 */
internal object AppChoices {
    /** Every app, A to Z. */
    @Volatile var all: List<Choice> = emptyList()
        private set

    /** The most used, at most [SUGGESTED]. */
    @Volatile var suggested: List<Choice> = emptyList()
        private set

    /** How "most used" was decided: "use" (Android's usage stats), "opens" (counted here) or "names" (A to Z). */
    @Volatile var rankedBy = ""
        private set

    @Volatile var loaded = false
        private set

    const val SUGGESTED = 8
    private const val OPENS = "prism_sidekick_opens"

    private val worker = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val main = android.os.Handler(android.os.Looper.getMainLooper())

    /** Reads every app and ranks them, away from the main thread; [done] on the main thread. */
    fun load(context: Context, done: () -> Unit) {
        val app = context.applicationContext
        worker.execute {
            try {
                val pm = app.packageManager
                val intent = android.content.Intent(android.content.Intent.ACTION_MAIN).addCategory(android.content.Intent.CATEGORY_LAUNCHER)
                val seen = HashSet<String>()
                val list = ArrayList<Choice>()
                for (r in pm.queryIntentActivities(intent, 0)) {
                    val pkg = r.activityInfo.packageName
                    // (Not Prism itself, and each app once, however many ways in it has.)
                    if (pkg == app.packageName || !seen.add(pkg)) continue
                    list.add(Choice("app", "app:$pkg", r.loadLabel(pm).toString(), pkg))
                }
                val collator = java.text.Collator.getInstance()
                collator.strength = java.text.Collator.PRIMARY
                list.sortWith { a, b -> collator.compare(a.label, b.label) }
                val (ranked, by) = rank(app, list)
                main.post {
                    all = list
                    suggested = ranked
                    rankedBy = by
                    loaded = true
                    done()
                }
            } catch (e: Exception) {
                main.post {
                    loaded = true
                    done()
                }
            }
        }
    }

    private fun rank(context: Context, list: List<Choice>): Pair<List<Choice>, String> {
        // 1. How long each was in front over the last 14 days, if Prism may read it.
        try {
            val um = context.getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
            val now = System.currentTimeMillis()
            val use = um.queryAndAggregateUsageStats(now - 14L * 24 * 3600 * 1000, now)
            if (use.isNotEmpty()) {
                val byTime = list.filter { (use[it.pkg]?.totalTimeInForeground ?: 0L) > 0L }
                    .sortedByDescending { use[it.pkg]?.totalTimeInForeground ?: 0L }
                if (byTime.isNotEmpty()) return fill(byTime, list) to "use"
            }
        } catch (e: Exception) {}
        // 2. How often each was opened from Prism or the Sidekick.
        try {
            val p = context.getSharedPreferences(OPENS, Context.MODE_PRIVATE)
            val byOpens = list.filter { p.getInt(it.pkg, 0) > 0 }.sortedByDescending { p.getInt(it.pkg, 0) }
            if (byOpens.isNotEmpty()) return fill(byOpens, list) to "opens"
        } catch (e: Exception) {}
        // 3. A to Z.
        return list.take(SUGGESTED) to "names"
    }

    /** The first [SUGGESTED], each once; filled up from A to Z if fewer were used. */
    private fun fill(first: List<Choice>, rest: List<Choice>): List<Choice> {
        val out = LinkedHashMap<String, Choice>()
        for (c in first) {
            if (out.size >= SUGGESTED) break
            out[c.key] = c
        }
        for (c in rest) {
            if (out.size >= SUGGESTED) break
            if (!out.containsKey(c.key)) out[c.key] = c
        }
        return out.values.toList()
    }

    /** An app was opened from Prism or the Sidekick: counted, for "most used" without usage access. */
    fun opened(context: Context, pkg: String) {
        if (pkg.isEmpty()) return
        try {
            val p = context.applicationContext.getSharedPreferences(OPENS, Context.MODE_PRIVATE)
            p.edit().putInt(pkg, p.getInt(pkg, 0) + 1).apply()
        } catch (e: Exception) {}
    }

    // ---- Icons: drawn when first wanted, away from the main thread; [ready] when one is.
    private val icons = object : android.util.LruCache<String, Bitmap>(12 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }
    private val wanted = HashSet<String>()

    /** [pkg]'s icon at [px] pixels, if it is ready; if not, it is drawn and [ready] called when it is. */
    fun icon(context: Context, pkg: String, px: Int, ready: () -> Unit): Bitmap? {
        val key = "$pkg@$px"
        icons.get(key)?.let { return it }
        if (!wanted.add(key)) return null
        val app = context.applicationContext
        worker.execute {
            val bmp = try {
                val d = app.packageManager.getApplicationIcon(pkg)
                val b = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
                d.setBounds(0, 0, px, px)
                d.draw(Canvas(b))
                b
            } catch (e: Exception) {
                null
            }
            main.post {
                wanted.remove(key)
                if (bmp != null) {
                    icons.put(key, bmp)
                    ready()
                }
            }
        }
        return null
    }

    /** The list has closed: its icons go. */
    fun forget() {
        icons.evictAll()
        wanted.clear()
    }
}
