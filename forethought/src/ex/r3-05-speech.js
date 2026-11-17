/* III.5 Scrub a voice message by its words — the waveform bars are the words. */
FT.exhibit({
  id: 'word-scrub', room: 3, num: 5, kind: 'proposal · audio', replaces: 'the waveform',
  title: 'Scrub a voice message by its words',
  hint: 'Tap a word to play from it · drag to seek · hold a word, then drag to quote',
  height: 500,
  body: `<p>In this voice message every bar of the waveform is one word. Its width is how long the word takes to say and its height is how loudly it was said. Drag along the bars and the word under your finger rises above it, so you seek to "bread", not to 0:14.</p><p>The transcript underneath is the same timeline. Tap any word to play from there. Hold a word and drag across a phrase to quote exactly that part in your reply.</p>`,
  why: `A waveform shows loudness, which nobody searches by. People remember what was said, so the timeline should be made of words. Seeking, replaying and quoting then all target the thing you actually remember.`,
  flutter: `
class WordBar { WordBar(this.text, this.start, this.end, this.loudness); final String text; final Duration start, end; final double loudness; }

class WordWave extends StatelessWidget {
  const WordWave({super.key, required this.words, required this.position, required this.onSeek});
  final List<WordBar> words;                       // from on-device speech recognition timestamps
  final Duration position;
  final ValueChanged<Duration> onSeek;

  int _wordAt(double dx, double width) {
    final t = words.last.end * (dx / width).clamp(0.0, 1.0);
    return words.indexWhere((w) => w.end >= t);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    void seek(double dx) {
      final i = _wordAt(dx, box.maxWidth);
      if (words[i].start != position) HapticFeedback.selectionClick();   // one tick per word
      onSeek(words[i].start);                                             // snap to word starts
    }
    return Semantics(
      label: 'Voice message, \${words.length} words',
      value: words.firstWhere((w) => w.end >= position).text,
      child: GestureDetector(
        onTapUp: (d) => seek(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
        child: CustomPaint(size: Size(box.maxWidth, 56), painter: WordWavePainter(words, position)),
      ),
    );
  });
}
// Audio: just_audio's AudioPlayer.seek(words[i].start). The transcript below is a Wrap of
// GestureDetectors sharing the same WordBar list; long-press + drag selects a quote range.`,
  a11y: `The player is a slider that moves word by word: <b>← →</b> step one word, <b>Home/End</b> jump, <b>Space</b> plays or pauses, and the current word is announced. Every transcript word is a button; <b>Shift + Enter</b> on a word starts or ends a quote.`,
  mount(stage) {
    const { h } = FT;
    const css = h('style', null, `
.ws{position:absolute;inset:14px 14px 14px;display:flex;flex-direction:column;gap:10px}
.ws-bub{border-radius:20px 20px 20px 6px;padding:12px 14px 12px 12px;display:flex;flex-direction:column;gap:8px}
.ws-row{display:flex;align-items:center;gap:10px}
.ws-play{flex:none;width:40px;height:40px;border-radius:50%;border:0;background:var(--accent);color:var(--accent-ink);display:grid;place-items:center;cursor:pointer}
.ws-wave{position:relative;flex:1;height:56px;min-width:0;cursor:pointer;outline-offset:3px;border-radius:8px}
.ws-meta{display:flex;justify-content:space-between;font-size:11px;color:var(--muted);padding-left:50px}
.ws-tip{position:absolute;top:-30px;transform:translateX(-50%);background:var(--ink);color:var(--bg);font-size:12px;font-weight:600;padding:3px 8px;border-radius:8px;white-space:nowrap;pointer-events:none;opacity:0;transition:opacity .15s}
.ws-tip.on{opacity:1}
.ws-tx{font-size:14px;line-height:1.75;padding:2px 4px;touch-action:none;user-select:none;-webkit-user-select:none}
.ws-w{border:0;background:none;font:inherit;padding:1px 2px;margin:0 -1px;border-radius:5px;color:var(--muted);cursor:pointer;transition:color .15s,background .15s}
.ws-w.done{color:var(--ink)}
.ws-w.now{background:var(--accent);color:var(--accent-ink)}
.ws-w.sel{background:var(--amber-soft);color:var(--ink)}
.ws-reply{margin-top:auto;display:flex;flex-direction:column;gap:6px;padding:10px 12px;border-radius:16px;background:var(--surface-2);border:1px solid var(--line)}
.ws-q{display:none;font-size:12.5px;line-height:1.35;padding:6px 8px 6px 10px;border-left:3px solid var(--amber);background:var(--amber-soft);border-radius:4px 8px 8px 4px;align-items:flex-start;gap:6px}
.ws-q.on{display:flex}
.ws-q span{flex:1;min-width:0}
.ws-q button{border:0;background:none;cursor:pointer;color:var(--muted);font-size:14px;line-height:1;padding:0 2px}
.ws-in{border:0;background:none;font:inherit;font-size:13.5px;color:var(--ink);outline:none;padding:2px 0}
.ws-in::placeholder{color:var(--faint)}
`);
    const TEXT = "Hey, it's Mira. So about Saturday: I think we should leave at eight, not nine, because the lake gets busy by ten. I'll bring coffee and the big blanket. Can you grab bread from the bakery near you? Oh, and Tomo might join, but only after lunch. Call me tonight if that doesn't work.";
    const STRESS = new Set(['saturday:', 'eight,', 'nine,', 'ten.', 'coffee', 'blanket.', 'bread', 'tomo', 'lunch.', 'tonight']);
    let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    let t = 0, ci = 0;
    const words = TEXT.split(' ').map(w => {
      const len = w.replace(/[^\p{L}']/gu, '').length;
      const dur = 0.15 + 0.058 * len;
      const pause = /[.?]$/.test(w) ? 0.42 : /[,:]$/.test(w) ? 0.2 : 0.05;
      const o = { text: w, start: t, end: t + dur, char: ci, loud: STRESS.has(w.toLowerCase()) ? 0.85 + rnd() * 0.15 : 0.3 + rnd() * 0.4 };
      t += dur + pause; ci += w.length + 1;
      return o;
    });
    const TOTAL = t;
    const fmt = s => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
    const ICON_PLAY = '<svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true"><path d="M4 2.5v11l9.5-5.5z" fill="currentColor"/></svg>';
    const ICON_PAUSE = '<svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true"><rect x="3.5" y="2.5" width="3.2" height="11" rx="1" fill="currentColor"/><rect x="9.3" y="2.5" width="3.2" height="11" rx="1" fill="currentColor"/></svg>';
    const play = h('button', { class: 'ws-play', type: 'button', 'data-hit': '', 'aria-label': 'Play voice message', html: ICON_PLAY });
    const wave = h('div', { class: 'ws-wave', 'data-hit': '' });
    const tip = h('div', { class: 'ws-tip' });
    wave.append(tip);
    const meta = h('div', { class: 'ws-meta ft-mono' }, h('span'), h('span', null, 'Mira · 08:14'));
    const tx = h('div', { class: 'ws-tx', 'aria-label': 'Transcript' });
    const btns = words.map((w, i) => { const b = h('button', { class: 'ws-w', type: 'button', 'data-i': i, tabindex: '-1' }, w.text); tx.append(b, ' '); return b; });
    btns[0].tabIndex = 0;
    const qText = h('span'), qX = h('button', { type: 'button', 'aria-label': 'Remove quote' }, '×');
    const quote = h('div', { class: 'ws-q' }, qText, qX);
    const input = h('input', { class: 'ws-in', id: 'ws-reply-input', type: 'text', placeholder: 'Reply to Mira…', 'aria-label': 'Reply' });
    stage.append(css, h('div', { class: 'ws' },
      h('div', { class: 'ws-bub ft-card' }, h('div', { class: 'ws-row' }, play, wave), meta, tx),
      h('div', { class: 'ws-reply' }, quote, input)));

    let pos = 0, playing = false, cur = 0, selA = -1, selB = -1, hover = -1;
    const idxAt = time => { for (let i = 0; i < words.length; i++) if (words[i].end + 0.06 >= time) return i; return words.length - 1; };
    let cv = null;
    cv = FT.canvas(wave, () => { if (cv) draw(); });
    function draw() {
      if (!cv) return;
      const { ctx, w: W, h: H } = cv;
      cv.clear();
      const acc = FT.col('--accent'), mut = FT.col('--line-2'), amb = FT.col('--amber');
      const sx = W / TOTAL, mid = H / 2;
      words.forEach((w, i) => {
        const x = w.start * sx + 0.6, bw = Math.max(1.6, (w.end - w.start) * sx - 1.2), bh = Math.max(4, w.loud * (H - 6));
        const inSel = selA >= 0 && i >= Math.min(selA, selB) && i <= Math.max(selA, selB);
        ctx.fillStyle = inSel ? amb : i < cur || (i === cur && pos > w.start) ? acc : i === hover ? FT.alpha(acc, 0.55) : mut;
        if (i === cur && pos > w.start && pos < w.end) { ctx.fillStyle = mut; }
        ctx.beginPath(); ctx.roundRect ? ctx.roundRect(x, mid - bh / 2, bw, bh, Math.min(2, bw / 2)) : ctx.rect(x, mid - bh / 2, bw, bh); ctx.fill();
        if (i === cur && pos > w.start && pos < w.end) { // partially played word
          ctx.save(); ctx.beginPath(); ctx.rect(x, 0, (pos - w.start) * sx, H); ctx.clip();
          ctx.fillStyle = acc; ctx.beginPath(); ctx.roundRect ? ctx.roundRect(x, mid - bh / 2, bw, bh, Math.min(2, bw / 2)) : ctx.rect(x, mid - bh / 2, bw, bh); ctx.fill(); ctx.restore();
        }
      });
    }
    const paintWords = () => {
      btns.forEach((b, i) => {
        const inSel = selA >= 0 && i >= Math.min(selA, selB) && i <= Math.max(selA, selB);
        b.className = 'ws-w' + (inSel ? ' sel' : i === cur && (playing || pos > 0) ? ' now' : i < cur ? ' done' : '');
      });
      meta.firstChild.textContent = `${fmt(pos)} / ${fmt(TOTAL)}`;
      wave.setAttribute('aria-valuenow', cur); wave.setAttribute('aria-valuetext', `${fmt(pos)}, word ${cur + 1} of ${words.length}: ${words[cur].text}`);
    };
    // --- playback: a clock drives the highlight; speech (if any) follows and resyncs it ---
    const synth = window.speechSynthesis;
    let clockBase = 0, posBase = 0, lastBoundary = 0;
    const speakFrom = i => {
      if (!synth) return;
      try {
        synth.cancel();
        const u = new SpeechSynthesisUtterance(words.slice(i).map(w => w.text).join(' '));
        u.rate = 1.02; u.pitch = 1.08; u.lang = 'en-GB';
        const offset = words[i].char;
        u.onboundary = ev => {
          if (ev.name && ev.name !== 'word') return;
          const ch = ev.charIndex + offset;
          let k = words.findIndex(w => w.char >= ch); if (k < 0) k = words.length - 1;
          lastBoundary = performance.now();
          if (Math.abs(words[k].start - pos) > 0.25) { pos = words[k].start; posBase = pos; clockBase = performance.now(); }
        };
        synth.speak(u);
      } catch (e) { /* speech not available: the clock carries on silently */ }
    };
    const loop = FT.loop(() => {
      if (!playing) return false;
      pos = posBase + (performance.now() - clockBase) / 1000;
      if (pos >= TOTAL) { pos = TOTAL; stop(true); }
      const c = idxAt(pos);
      if (c !== cur) cur = c;
      draw(); paintWords();
      return playing;
    });
    const start = () => {
      if (pos >= TOTAL - 0.05) { pos = 0; cur = 0; }
      playing = true; posBase = pos; clockBase = performance.now();
      play.innerHTML = ICON_PAUSE; play.setAttribute('aria-label', 'Pause');
      speakFrom(cur); loop.wake();
      FT.intent(`play from “${words[cur].text}” (${fmt(pos)})`);
    };
    function stop(ended) {
      playing = false; try { synth && synth.cancel(); } catch (e) { /* ok */ }
      play.innerHTML = ICON_PLAY; play.setAttribute('aria-label', 'Play voice message');
      if (ended) { FT.intent('message ended'); }
      draw(); paintWords();
    }
    const seekWord = (i, how, quiet) => {
      i = FT.clamp(i, 0, words.length - 1);
      const changed = i !== cur;
      cur = i; pos = words[i].start; posBase = pos; clockBase = performance.now();
      if (changed && !quiet) FT.haptic('select');
      if (playing) speakFrom(i);
      draw(); paintWords();
      if (changed) FT.intent(`${how} → “${words[i].text}” at ${fmt(pos)}`);
    };
    play.addEventListener('click', () => { playing ? stop() : start(); FT.haptic('light'); });
    // wave: drag to seek by word, tooltip shows the word under the finger
    const showTip = (i, x) => { tip.textContent = words[i].text.replace(/[.,:?]$/, ''); tip.style.left = FT.clamp(x, 24, cv.w - 24) + 'px'; tip.classList.add('on'); };
    let wasPlaying = false;
    FT.drag(wave, {
      start(s) { wasPlaying = playing; if (playing) { playing = false; try { synth && synth.cancel(); } catch (e) { /* ok */ } } const i = idxAt(s.x / cv.w * TOTAL); seekWord(i, 'seek'); showTip(i, s.x); },
      move(s) { const i = idxAt(FT.clamp(s.x, 0, cv.w) / cv.w * TOTAL); hover = i; seekWord(i, 'scrub'); showTip(i, s.x); },
      end() { tip.classList.remove('on'); hover = -1; draw(); if (wasPlaying) start(); else FT.announce(`${words[cur].text}, ${fmt(pos)}`); },
    }, { axis: 'x', slop: 2 });
    wave.tabIndex = 0; wave.setAttribute('role', 'slider'); wave.setAttribute('aria-label', 'Voice message position, by word');
    wave.setAttribute('aria-valuemin', 0); wave.setAttribute('aria-valuemax', words.length - 1);
    wave.addEventListener('keydown', e => {
      const map = { ArrowRight: 1, ArrowLeft: -1, ArrowUp: 1, ArrowDown: -1 };
      if (e.key in map) seekWord(cur + map[e.key], 'key');
      else if (e.key === 'Home') seekWord(0, 'key'); else if (e.key === 'End') seekWord(words.length - 1, 'key');
      else if (e.key === ' ' || e.key === 'Enter') { playing ? stop() : start(); }
      else return;
      e.preventDefault(); if (!playing) FT.announce(words[cur].text);
    });
    // transcript: tap = play from word; drag = seek; hold then drag = quote
    const wordAt = (cx, cy) => { const el = document.elementFromPoint(cx, cy); return el && el.classList && el.classList.contains('ws-w') ? +el.dataset.i : -1; };
    let holdT = 0, quoting = false;
    const setQuote = () => {
      const a = Math.min(selA, selB), b = Math.max(selA, selB);
      const q = words.slice(a, b + 1).map(w => w.text).join(' ').replace(/[,:]$/, '');
      qText.textContent = `“${q}”`; quote.classList.add('on');
      FT.haptic('success'); FT.intent(`quoted ${b - a + 1} word${b > a ? 's' : ''}: “${q}”`);
      FT.announce(`Quoted: ${q}`);
    };
    FT.drag(tx, {
      start(s, e) {
        const i = wordAt(e.clientX, e.clientY); if (i < 0) return false;
        quoting = false; clearTimeout(holdT);
        holdT = setTimeout(() => { quoting = true; selA = selB = i; FT.haptic('medium'); FT.intent(`hold on “${words[i].text}”: drag to extend the quote`); draw(); paintWords(); }, 420);
      },
      move(s, e) {
        const i = wordAt(e.clientX, e.clientY);
        if (!quoting && s.moved) clearTimeout(holdT);
        if (i < 0) return;
        if (quoting) { if (i !== selB) { selB = i; FT.haptic('select'); draw(); paintWords(); } }
        else if (s.moved) seekWord(i, 'transcript scrub');
      },
      tap(s, e) {
        clearTimeout(holdT);
        const i = wordAt(e.clientX, e.clientY); if (i < 0) return;
        selA = selB = -1; seekWord(i, 'tap word', true); if (!playing) start(); else speakFrom(i);
      },
      end() { clearTimeout(holdT); if (quoting) { quoting = false; setQuote(); input.focus({ preventScroll: true }); } },
    }, { axis: 'both', slop: 6 });
    let kbQuote = -1;
    tx.addEventListener('keydown', e => {
      const b = e.target.closest('.ws-w'); if (!b) return;
      const i = +b.dataset.i;
      if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
        e.preventDefault(); const j = FT.clamp(i + (e.key === 'ArrowRight' ? 1 : -1), 0, words.length - 1);
        b.tabIndex = -1; btns[j].tabIndex = 0; btns[j].focus();
        if (kbQuote >= 0) { selB = j; draw(); paintWords(); }
      } else if (e.key === 'Enter' && e.shiftKey) {
        e.preventDefault();
        if (kbQuote < 0) { kbQuote = i; selA = selB = i; FT.announce(`Quote starts at ${words[i].text}. Move, then Shift Enter to finish.`); }
        else { selB = i; kbQuote = -1; setQuote(); }
        draw(); paintWords();
      } else if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault(); seekWord(i, 'key word', true); if (!playing) start(); else speakFrom(i);
      }
    });
    qX.addEventListener('click', () => { quote.classList.remove('on'); selA = selB = -1; draw(); paintWords(); FT.announce('Quote removed'); });
    FT.onTheme(draw);
    draw(); paintWords();
    return { reset() { stop(); pos = 0; cur = 0; selA = selB = -1; kbQuote = -1; quote.classList.remove('on'); input.value = ''; draw(); paintWords(); } };
  },
});
