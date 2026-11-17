/* I.8 Progress that admits uncertainty — a time bar with a finish band that narrows as evidence arrives. */
FT.exhibit({
  id: 'honest-progress', room: 1, num: 8, kind: 'progress', replaces: 'the fake-smooth progress bar',
  title: 'Progress that admits uncertainty',
  hint: 'Start the upload · switch on Shaky network',
  height: 420,
  body: `<p>This bar measures time, not bytes. The solid part is time already spent; the soft band ahead is where the finish will probably land. Early on the band is wide and the label says "about 9–16 s". As the upload builds a track record, the band tightens and the range shrinks to a single number.</p><p>Switch on Shaky network and the band widens again. When no data arrives for a second and a half, the bar says "Waiting for network" and stops pretending. Nothing creeps forward to look busy.</p>`,
  why: `A single ETA is a guess dressed up as a fact, and a bar that creeps while nothing happens is a small lie. Showing the range lets people decide whether to wait, leave or retry. Admitting a stall builds more trust than a spinner that never changes.`,
  flutter: `
class EtaEstimator {
  double _mean = 0, _var = 0;                    // bytes/s, exponentially weighted
  bool _seeded = false;
  static const alpha = 0.18;

  void sample(double bytesPerSecond) {
    if (!_seeded) { _mean = bytesPerSecond; _seeded = true; return; }
    final d = bytesPerSecond - _mean;
    _mean += alpha * d;
    _var = (1 - alpha) * (_var + alpha * d * d);
  }

  /// Plausible finish window for [remaining] bytes, or null while stalled.
  (Duration, Duration)? window(int remaining, {required Duration sinceLastByte}) {
    if (sinceLastByte > const Duration(milliseconds: 1500)) return null;   // say so, don't guess
    final sd = sqrt(_var);
    final fast = _mean + 1.3 * sd, slow = max(_mean - 1.3 * sd, _mean * 0.25);
    return (Duration(milliseconds: (remaining / fast * 1000).round()),
            Duration(milliseconds: (remaining / slow * 1000).round()));
  }
}

class FinishBandPainter extends CustomPainter {
  FinishBandPainter({required this.elapsed, required this.window, required this.scale, required this.colors});
  final Duration elapsed; final (Duration, Duration)? window; final double scale; final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size s) {
    final x = (Duration d) => d.inMilliseconds / 1000 * scale;
    canvas.drawRRect(RRect.fromLTRBR(0, 0, x(elapsed), s.height, const Radius.circular(8)), Paint()..color = colors.primary);
    if (window case (final lo, final hi)) {
      final band = Rect.fromLTRB(x(elapsed + lo), 0, x(elapsed + hi), s.height);
      canvas.drawRect(band, Paint()..shader = LinearGradient(colors: [colors.primary.withOpacity(.05),
          colors.primary.withOpacity(.35), colors.primary.withOpacity(.05)]).createShader(band));
    }
  }
  @override
  bool shouldRepaint(FinishBandPainter o) => o.elapsed != elapsed || o.window != window;
}`,
  a11y: `The bar is a <b>progressbar</b> whose value text is the honest sentence ("About 6 to 9 seconds left", "Waiting for network, no data for 3 seconds"). Updates are announced at most every five seconds and on every state change, so screen readers aren't flooded. Both buttons are ordinary buttons.`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', null, `
      .hp-top{position:absolute;left:18px;right:18px;top:16px;display:flex;justify-content:space-between;align-items:center;gap:8px}
      .hp-top b{font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}
      .hp-top .ft-chip{white-space:nowrap}
      .hp-eta{position:absolute;left:18px;right:18px;top:58px;font-size:22px;font-weight:600;letter-spacing:-.01em;min-height:30px;font-variant-numeric:tabular-nums}
      .hp-eta.wait{color:var(--amber)}
      .hp-sub{position:absolute;left:18px;right:18px;top:90px;font-family:var(--f-mono);font-size:11px;color:var(--muted);font-variant-numeric:tabular-nums}
      .hp-barbox{position:absolute;left:18px;right:18px;top:118px;height:62px}
      .hp-files{position:absolute;left:18px;right:18px;top:196px;display:grid;gap:5px}
      .hp-f{display:grid;grid-template-columns:34px 1fr auto;gap:10px;align-items:center;height:42px;padding:0 12px 0 6px;border-radius:10px;background:var(--surface-2);border:1px solid var(--line)}
      .hp-th{width:30px;height:30px;border-radius:7px}
      .hp-nm{font-size:12.5px;font-weight:500;display:flex;flex-direction:column;gap:4px;min-width:0}
      .hp-nm span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .hp-mini{height:3px;border-radius:2px;background:var(--line);overflow:hidden}
      .hp-mini i{display:block;height:100%;background:var(--accent);width:0}
      .hp-st{font-family:var(--f-mono);font-size:10.5px;color:var(--muted);text-align:right;min-width:58px}
      .hp-st.done{color:var(--ok)}
      .hp-btns{display:flex;gap:6px;align-items:center}
      .hp-btns{flex:none}
      .hp-btns .ft-btn{height:32px;font-size:12.5px;padding:0 13px}
    `));
    const shaky = h('button', { class: 'ft-chip', type: 'button', 'aria-pressed': 'false', 'data-hit': '' }, 'Shaky network');
    const go = h('button', { class: 'ft-btn', type: 'button', 'data-hit': '' }, 'Start upload');
    stage.append(h('div', { class: 'hp-top' }, h('b', null, 'Uploading 4 photos'), h('div', { class: 'hp-btns' }, shaky, go)));
    const eta = h('div', { class: 'hp-eta' });
    const sub = h('div', { class: 'hp-sub' });
    const barbox = h('div', { class: 'hp-barbox', role: 'progressbar', 'aria-label': 'Upload time', 'aria-valuemin': '0', 'aria-valuemax': '100' });
    stage.append(eta, sub, barbox);
    const FILES = [['IMG_2041.heic', 3.2, 'var(--accent)', 'var(--amber)'], ['IMG_2042.heic', 2.8, 'var(--ok)', 'var(--amber-soft)'], ['IMG_2047.heic', 4.1, 'var(--hot)', 'var(--ink-2)'], ['IMG_2051.heic', 3.6, 'var(--line-2)', 'var(--accent-2)']];
    const files = h('div', { class: 'hp-files' });
    const frows = FILES.map(([n, mb, c1, c2]) => {
      const mini = h('i'); const st = h('span', { class: 'hp-st' });
      const r = h('div', { class: 'hp-f' }, h('span', { class: 'hp-th', style: { background: `linear-gradient(135deg, ${c1}, ${c2})` } }), h('div', { class: 'hp-nm' }, h('span', null, `${n} · ${mb} MB`), h('div', { class: 'hp-mini' }, mini)), st);
      files.append(r); return { mini, st, size: mb * 1e6 };
    });
    stage.append(files);
    let ready = false;
    const cv = FT.canvas(barbox, () => ready && draw());

    const TOTAL = FILES.reduce((a, f) => a + f[1] * 1e6, 0);
    let S = null; // run state
    const scale = FT.spring(16, FT.SPRING.gentle);    // seconds shown across the bar
    const bandLo = FT.spring(0, FT.SPRING.smooth), bandHi = FT.spring(0, FT.SPRING.smooth);
    let isShaky = false, lastAnnounce = 0, lastState = '';
    const fresh = () => ({ t: 0, sent: 0, rate: 1.0e6, noise: 0, mean: 0, vari: 0, seeded: false, lastByte: 0, stallUntil: 0, nextStall: 3 + Math.random() * 3, done: false, win: null, acc: 0, accT: 0 });
    const fmt = s => s < 9.95 ? s.toFixed(1) : String(Math.round(s));

    const stepSim = dt => {
      if (!(dt > 0)) return;   // the first frame after waking can report a negative dt
      // a simple network: base rate with an Ornstein–Uhlenbeck wobble, plus stalls when shaky
      const base = isShaky ? 0.85e6 : 1.15e6, sig = isShaky ? 0.55 : 0.16;
      S.noise += -S.noise * 1.4 * dt + sig * Math.sqrt(dt) * (Math.random() * 2 - 1) * 2.2;
      let r = base * Math.max(0.05, 1 + S.noise);
      if (isShaky && S.t > S.nextStall && !S.stallUntil) { S.stallUntil = S.t + 2.2 + Math.random() * 1.8; }
      if (S.stallUntil) { r = 0; if (S.t > S.stallUntil) { S.stallUntil = 0; S.nextStall = S.t + 3 + Math.random() * 4; } }
      const bytes = Math.min(TOTAL - S.sent, r * dt);
      S.sent += bytes; S.t += dt;
      if (bytes > 0) S.lastByte = S.t;
      // estimator: sample throughput every 250 ms
      S.acc += bytes; S.accT += dt;
      if (S.accT >= 0.25) {
        const bps = S.acc / S.accT; S.acc = 0; S.accT = 0;
        if (bps > 0) {
          if (!S.seeded) { S.mean = bps; S.vari = (bps * 0.45) ** 2; S.seeded = true; }
          else { const d = bps - S.mean, a = 0.18; S.mean += a * d; S.vari = (1 - a) * (S.vari + a * d * d); }
        } else if (S.seeded) S.vari *= 1.08;           // silence makes us less sure
      }
      if (S.sent >= TOTAL - 1) { S.sent = TOTAL; S.done = true; }
    };
    const window_ = () => {
      if (!S || !S.seeded || S.done) return null;
      const stalled = S.t - S.lastByte > 1.5;
      const rem = TOTAL - S.sent, sd = Math.sqrt(S.vari) + S.mean * Math.max(0, 0.35 - S.t * 0.03); // young estimates are humbler
      const fast = S.mean + 1.3 * sd, slow = Math.max(S.mean - 1.3 * sd, S.mean * 0.22);
      return { lo: rem / fast, hi: rem / slow, stalled };
    };
    const text = () => {
      if (!S) return ['Ready', `4 photos · ${(TOTAL / 1e6).toFixed(1)} MB`];
      if (S.done) return [`Uploaded in ${fmt(S.t)} s`, `4 of 4 photos · ${(TOTAL / 1e6).toFixed(1)} MB`];
      const w = window_();
      const sent = `${(S.sent / 1e6).toFixed(1)} of ${(TOTAL / 1e6).toFixed(1)} MB · ${fmt(S.t)} s spent`;
      if (!w) return ['Measuring…', sent];
      if (w.stalled) return [`Waiting for network`, `no data for ${fmt(S.t - S.lastByte)} s · ${sent}`];
      if (w.hi < 1.5) return ['Almost done', sent];
      const lo = Math.max(1, Math.round(w.lo)), hi = Math.max(lo, Math.round(w.hi));
      return [hi - lo <= Math.max(1, lo * 0.15) ? `About ${Math.round((w.lo + w.hi) / 2)} s left` : `About ${lo}–${hi} s left`, sent];
    };
    function draw() {
      const { ctx } = cv; cv.clear();
      const W = cv.w, H = 22, y = 22;
      const acc = FT.col('--accent'), line = FT.col('--line'), muted = FT.col('--muted'), amb = FT.col('--amber'), ok = FT.col('--ok');
      const sc = W / Math.max(1, scale.x);
      // rail + second ticks
      ctx.fillStyle = FT.alpha(line, 1); ctx.beginPath(); ctx.roundRect ? ctx.roundRect(0, y, W, H, 8) : ctx.rect(0, y, W, H); ctx.fill();
      const stepS = scale.x > 30 ? 10 : 5;
      ctx.font = '10px "Geist Mono", ui-monospace, monospace'; ctx.fillStyle = FT.alpha(muted, 0.85); ctx.textAlign = 'center';
      for (let s = 0; s <= scale.x + 0.01; s += stepS) {
        const x = s * sc; if (x > W - 4 && s) continue;
        ctx.fillRect(Math.round(x), y + H + 3, 1, 5); ctx.fillText(`${s}s`, FT.clamp(x, 8, W - 10), y + H + 19);
      }
      const t = S ? S.t : 0;
      const stalled = S && !S.done && S.t - S.lastByte > 1.5;
      // band
      const w = window_();
      if (w || bandHi.x > 0.05) {
        const a = (t + bandLo.x) * sc, b = (t + bandHi.x) * sc;
        if (b - a > 0.5) {
          const g = ctx.createLinearGradient(a, 0, b, 0);
          const c = stalled ? amb : acc;
          g.addColorStop(0, FT.alpha(c, 0.05)); g.addColorStop(0.45, FT.alpha(c, 0.42)); g.addColorStop(1, FT.alpha(c, 0.04));
          ctx.fillStyle = g; ctx.fillRect(a, y - 6, Math.min(W, b) - a, H + 12);
          // label above the band
          ctx.fillStyle = stalled ? amb : acc; ctx.font = '600 10px "Geist Mono", ui-monospace, monospace';
          ctx.fillText(stalled ? 'finish? unknown' : 'likely finish', FT.clamp((a + Math.min(W, b)) / 2, 44, W - 44), y - 11);
        }
      }
      // spent time
      if (t > 0) {
        ctx.fillStyle = S && S.done ? ok : acc;
        ctx.beginPath(); ctx.roundRect ? ctx.roundRect(0, y, Math.max(8, t * sc), H, 8) : ctx.rect(0, y, t * sc, H); ctx.fill();
        // stall stretch: hatched, honest about time passing with no data
        if (stalled) {
          const x0 = S.lastByte * sc, x1 = t * sc;
          ctx.save(); ctx.beginPath(); ctx.rect(x0, y, x1 - x0, H); ctx.clip();
          ctx.fillStyle = amb; ctx.fillRect(x0, y, x1 - x0, H);
          ctx.strokeStyle = FT.alpha(FT.col('--bg'), 0.45); ctx.lineWidth = 2;
          for (let k = x0 - H; k < x1 + H; k += 6) { ctx.beginPath(); ctx.moveTo(k, y + H); ctx.lineTo(k + H, y); ctx.stroke(); }
          ctx.restore();
        }
        // "now" notch
        ctx.fillStyle = FT.col('--ink'); ctx.fillRect(Math.min(W - 2, t * sc) - 1, y - 4, 2, H + 8);
      }
      const [a, b] = text();
      eta.textContent = a; eta.classList.toggle('wait', !!stalled);
      sub.textContent = b;
      barbox.setAttribute('aria-valuenow', S ? Math.round(S.sent / TOTAL * 100) : 0);
      barbox.setAttribute('aria-valuetext', a);
      // per-file rows (sequential uploads)
      let left = S ? S.sent : 0;
      frows.forEach(f => {
        const got = FT.clamp(left, 0, f.size); left -= got;
        const p = got / f.size;
        f.mini.style.width = (p * 100).toFixed(1) + '%';
        f.st.textContent = !S ? 'queued' : p >= 1 ? 'done' : got > 0 ? (stalled ? 'waiting' : Math.round(p * 100) + '%') : 'queued';
        f.st.classList.toggle('done', p >= 1);
      });
      const state = !S ? 'idle' : S.done ? 'done' : stalled ? 'stalled' : 'run';
      const now = performance.now();
      if (state !== lastState || (state === 'run' && now - lastAnnounce > 5000)) {
        if (state !== lastState) {
          if (state === 'stalled') { FT.intent('no bytes for 1.5 s: saying so instead of guessing'); FT.haptic('warning'); }
          if (state === 'done') { FT.intent(`finished in ${fmt(S.t)} s`); FT.haptic('success'); }
        }
        if (state !== 'idle') FT.announce(a);
        lastState = state; lastAnnounce = now;
      }
    }
    const loop = FT.loop(dt => {
      let busy = false;
      if (S && !S.done) { stepSim(dt); busy = true; }
      const w = window_();
      if (w) { bandLo.to(w.lo); bandHi.to(w.hi); }
      else if (S && S.done) { bandLo.to(0); bandHi.to(0); }
      const want = S ? Math.max(8, (S.t + (w ? Math.min(w.hi, 60) : 4)) * 1.12) : 16;
      if (Math.abs(want - scale.t) > scale.t * 0.12 || want > scale.t) scale.to(want);
      for (const s of [scale, bandLo, bandHi]) if (!s.step(dt)) busy = true;
      draw();
      return busy;
    });
    const start = () => {
      S = fresh(); scale.set(16); bandLo.set(0); bandHi.set(0); lastState = '';
      go.textContent = 'Restart'; FT.haptic('light'); FT.intent('upload started: estimate is wide until data arrives');
      loop.wake();
    };
    go.addEventListener('click', start);
    shaky.addEventListener('click', () => {
      isShaky = !isShaky; shaky.setAttribute('aria-pressed', String(isShaky));
      if (S && isShaky) S.nextStall = S.t + 1.2;
      FT.haptic('select'); FT.intent(isShaky ? 'network: shaky, expect a wider band' : 'network: steady');
    });
    let auto = false;
    FT.visible(stage, v => { if (v && !auto) { auto = true; setTimeout(start, 400); } });
    FT.onTheme(draw);
    ready = true; draw();
    return { reset() { S = null; isShaky = false; shaky.setAttribute('aria-pressed', 'false'); go.textContent = 'Start upload'; scale.set(16); bandLo.set(0); bandHi.set(0); lastState = ''; draw(); } };
  },
});
