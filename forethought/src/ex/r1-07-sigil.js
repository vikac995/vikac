/* I.7 A password you can recognise — a low-entropy sigil that catches typos before you submit. */
FT.exhibit({
  id: 'password-sigil', room: 1, num: 7, kind: 'text field',
  title: 'A password you can recognise',
  hint: 'Type maple-river-42 · then try a typo',
  height: 400,
  body: `<p>Password fields hide what you type, so a typo only shows up as "wrong password" after you submit. Here, from the fourth character on, the field draws a small sigil from what you've typed. The same password always draws the same sigil. After a few sign-ins you know yours by sight, and a typo shows up as a stranger before you press anything.</p><p>The sigil carries only 12 bits, one of 4,096 shapes. Thousands of passwords share each one, so it tells an onlooker almost nothing. A per-device salt means the same password draws a different sigil on another device.</p>`,
  why: `Feedback should arrive while the mistake is still cheap. Masking protects the secret but throws away the one signal the user needs. A sigil gives back recognition without giving back the characters.`,
  source: `the anti-spoofing "hieroglyphs" in Lotus Notes / HCL Notes password prompts (<a href="https://help.hcl-software.com/domino/14.0.0/admin/conf_passwordprotectionfornotesanddominoids_c.html" target="_blank" rel="noopener">HCL documentation</a>), which drew a picture from the typed password so users could notice a fake prompt`,
  flutter: `
/// 12 bits from a salted hash: shape is recognisable, useless for guessing.
SigilSpec sigilFor(String password, List<int> deviceSalt) {
  if (password.length < 4) return SigilSpec.empty;
  final digest = sha256.convert([...deviceSalt, ...utf8.encode(password)]);
  final bits = (digest.bytes[0] << 4) | (digest.bytes[1] >> 4);   // 12 bits
  return SigilSpec(
    folds: 3 + (bits & 3),                 // 3–6 petals
    depth: 0.28 + ((bits >> 2) & 3) * 0.12,
    twist: ((bits >> 4) & 3) / 4,
    ring: (bits >> 6) & 1 == 1,
    dots: (bits >> 7) & 3,
    hue: (bits >> 9) & 3,                  // index into four theme colours
    hollow: (bits >> 11) & 1 == 1,
  );
}

class SigilField extends StatefulWidget {
  const SigilField({super.key});
  @override State<SigilField> createState() => _SigilFieldState();
}

class _SigilFieldState extends State<SigilField> {
  SigilSpec spec = SigilSpec.empty;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: TextField(obscureText: true, autofillHints: const [AutofillHints.password],
      onChanged: (v) => setState(() => spec = sigilFor(v, salt)))),
    ExcludeSemantics(                       // decorative to screen readers: never read the shape aloud
      child: TweenAnimationBuilder<SigilSpec>(       // every parameter morphs, so keystrokes animate
        tween: SigilSpecTween(end: spec), duration: const Duration(milliseconds: 380), curve: Curves.easeOutBack,
        builder: (_, s, __) => CustomPaint(size: const Size.square(120), painter: SigilPainter(s)))),
  ]);
}`,
  a11y: `The field is a normal password input with a visible label. The sigil is decorative and hidden from screen readers; the match line ("Same sigil as last time") is announced instead, so non-visual users get the typo check without the shape.`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', null, `
      .sg-form{position:absolute;left:18px;right:18px;top:18px}
      .sg-form label{display:block;font-size:13px;font-weight:600;margin-bottom:6px}
      .sg-field{display:flex;align-items:center;height:48px;border-radius:12px;border:1.5px solid var(--line-2);background:var(--surface-2);padding:0 6px 0 14px;transition:border-color .2s,box-shadow .2s}
      .sg-field:focus-within{border-color:var(--accent);box-shadow:0 0 0 4px var(--accent-wash)}
      .sg-field input{flex:1;min-width:0;border:0;background:none;font:500 16px var(--f-mono);color:var(--ink);letter-spacing:.06em;outline:none;height:100%}
      .sg-eye{width:38px;height:38px;border:0;background:none;color:var(--muted);cursor:pointer;border-radius:9px;display:grid;place-items:center}
      .sg-eye[aria-pressed="true"]{color:var(--accent)}
      .sg-pair{position:absolute;left:18px;right:18px;top:104px;bottom:58px;display:grid;grid-template-columns:1.35fr 1fr;gap:12px}
      .sg-box{position:relative;border-radius:14px;border:1px solid var(--line);background:var(--surface-2);min-width:0}
      .sg-box .ft-label{position:absolute;left:12px;top:10px}
      .sg-box canvas{position:absolute;inset:0}
      .sg-ref{opacity:.92}
      .sg-status{position:absolute;left:18px;right:18px;bottom:16px;display:flex;align-items:center;justify-content:space-between;gap:10px;font-size:13px;color:var(--muted);min-height:30px}
      .sg-status .ok{color:var(--ok);font-weight:600;display:flex;align-items:center;gap:6px}
      .sg-status .ft-chip{flex:none}
    `));
    const input = h('input', { id: 'sigil-pw', type: 'password', autocomplete: 'off', spellcheck: 'false', autocapitalize: 'off', 'aria-describedby': 'sigil-status', 'data-hit': '' });
    const eye = h('button', { class: 'sg-eye', type: 'button', 'aria-pressed': 'false', 'aria-label': 'Show password', 'data-hit': '' });
    eye.innerHTML = `<svg width="20" height="20" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z" fill="none" stroke="currentColor" stroke-width="1.7"/><circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" stroke-width="1.7"/></svg>`;
    eye.addEventListener('click', () => { const show = input.type === 'password'; input.type = show ? 'text' : 'password'; eye.setAttribute('aria-pressed', String(show)); eye.setAttribute('aria-label', show ? 'Hide password' : 'Show password'); });
    stage.append(h('div', { class: 'sg-form' }, h('label', { for: 'sigil-pw' }, 'Password'), h('div', { class: 'sg-field' }, input, eye)));
    const live = h('div', { class: 'sg-box', 'aria-hidden': 'true' }, h('span', { class: 'ft-label' }, 'Your sigil'));
    const ref = h('div', { class: 'sg-box sg-ref', 'aria-hidden': 'true' }, h('span', { class: 'ft-label' }, 'Last time'));
    stage.append(h('div', { class: 'sg-pair' }, live, ref));
    const msg = h('span', { id: 'sigil-status' });
    const demo = h('button', { class: 'ft-chip', type: 'button', 'data-hit': '' }, 'Type it for me');
    stage.append(h('div', { class: 'sg-status' }, msg, demo));

    const SALT = 'device:7f3a-forethought';
    const hash = str => { // xmur3 → 32-bit
      let hh = 1779033703 ^ str.length;
      for (let i = 0; i < str.length; i++) { hh = Math.imul(hh ^ str.charCodeAt(i), 3432918353); hh = hh << 13 | hh >>> 19; }
      hh = Math.imul(hh ^ hh >>> 16, 2246822507); hh = Math.imul(hh ^ hh >>> 13, 3266489909);
      return (hh ^= hh >>> 16) >>> 0;
    };
    const COLS = ['--accent', '--amber', '--ok', '--hot'];
    const spec = pw => {
      if (pw.length < 4) return null;
      const b = hash(SALT + pw) & 4095;
      return { folds: 3 + (b & 3), depth: 0.28 + ((b >> 2) & 3) * 0.12, twist: ((b >> 4) & 3) / 4, ring: (b >> 6) & 1, dots: (b >> 7) & 3, hue: (b >> 9) & 3, hollow: (b >> 11) & 1, bits: b };
    };
    const REF = spec('maple-river-42');
    const keys = ['folds', 'depth', 'twist', 'ring', 'dots', 'hollow', 'presence'];
    const S = {}; keys.forEach(k => S[k] = FT.spring(k === 'folds' ? 4 : 0, FT.SPRING.bouncy));
    let hueFrom = 0, hueTo = 0, hueT = FT.spring(1, FT.SPRING.gentle), cur = null;

    const mix = (a, b, t) => { const p = c => { const n = parseInt(c.replace('#', '').slice(0, 6), 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; }; const A = p(a), B = p(b); return `rgb(${A.map((v, i) => Math.round(v + (B[i] - v) * t)).join(',')})`; };
    function drawSigil(c, p, col, empty) {
      const { ctx } = c; c.clear();
      const cx = c.w / 2, cy = c.h / 2 + 10, R = Math.min(c.w, c.h - 30) * 0.36;
      const muted = FT.col('--muted');
      if (empty > 0.01) {
        ctx.globalAlpha = empty;
        ctx.strokeStyle = FT.alpha(muted, 0.5); ctx.setLineDash([4, 5]); ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(cx, cy, R * 0.8, 0, 7); ctx.stroke(); ctx.setLineDash([]);
        ctx.fillStyle = muted; ctx.font = '11px "Geist Mono", ui-monospace, monospace'; ctx.textAlign = 'center';
        ctx.fillText('after 4 characters', cx, cy + 4);
        ctx.globalAlpha = 1;
      }
      const pr = p.presence; if (pr < 0.01) return;
      ctx.save(); ctx.translate(cx, cy); ctx.scale(pr, pr); ctx.globalAlpha = FT.clamp(pr, 0, 1);
      ctx.rotate(p.twist * Math.PI * 2 / Math.max(3, p.folds));
      // rose
      ctx.beginPath();
      for (let i = 0; i <= 360; i++) {
        const t = i / 360 * Math.PI * 2;
        const r = R * (1 - p.depth + p.depth * Math.cos(p.folds * t));
        const x = r * Math.cos(t), y = r * Math.sin(t);
        i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
      }
      ctx.closePath();
      ctx.fillStyle = col.replace('rgb(', 'rgba(').replace(')', `,${0.16 + 0.7 * (1 - p.hollow)})`);
      ctx.fill(); ctx.strokeStyle = col; ctx.lineWidth = 2.2; ctx.lineJoin = 'round'; ctx.stroke();
      // inner ring
      if (p.ring > 0.02) { ctx.globalAlpha = FT.clamp(pr, 0, 1) * p.ring; ctx.strokeStyle = col; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(0, 0, R * 0.32, 0, 7); ctx.stroke(); ctx.globalAlpha = FT.clamp(pr, 0, 1); }
      // satellite dots
      const nd = p.dots;
      for (let i = 0; i < 3; i++) {
        const a = FT.clamp(nd - i, 0, 1); if (a < 0.02) continue;
        const ang = -Math.PI / 2 + (i - 1) * 0.55;
        ctx.globalAlpha = a * FT.clamp(pr, 0, 1);
        ctx.fillStyle = col; ctx.beginPath(); ctx.arc(Math.cos(ang) * R * 1.18, Math.sin(ang) * R * 1.18, 3.4, 0, 7); ctx.fill();
      }
      ctx.restore();
    }
    let ready = false;
    const cLive = FT.canvas(live, () => ready && draw());
    const cRef = FT.canvas(ref, () => ready && draw());
    function draw() {
      const p = {}; keys.forEach(k => p[k] = S[k].x);
      const col = mix(FT.col(COLS[hueFrom]), FT.col(COLS[hueTo]), FT.clamp(hueT.x, 0, 1));
      drawSigil(cLive, p, col, 1 - FT.clamp(p.presence, 0, 1));
      const rp = { ...REF, presence: 1 };
      drawSigil(cRef, rp, mix(FT.col(COLS[REF.hue]), FT.col(COLS[REF.hue]), 0), 0);
    }
    const loop = FT.loop(dt => { let busy = false; keys.forEach(k => { if (!S[k].step(dt)) busy = true; }); if (!hueT.step(dt)) busy = true; draw(); return busy; });
    let lastMatch = false;
    const update = () => {
      const sp = spec(input.value);
      if (sp) {
        ['folds', 'depth', 'twist', 'ring', 'dots', 'hollow'].forEach(k => S[k].to(sp[k]));
        S.presence.to(1);
        if (!cur || cur.hue !== sp.hue) { hueFrom = cur ? cur.hue : sp.hue; hueTo = sp.hue; hueT.set(0).to(1); }
        // a keystroke always gives the shape a small push, so you see it react
        S.twist.kick(0.6); S.depth.kick(0.8);
      } else S.presence.to(0);
      cur = sp;
      const match = !!sp && sp.bits === REF.bits;
      if (match) { msg.innerHTML = `<span class="ok"><svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true"><path d="M3 8.5l3 3 7-7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>Same sigil as last time</span>`; }
      else if (sp) msg.textContent = 'Not the sigil you saw last time';
      else msg.textContent = input.value.length ? `${4 - input.value.length} more to see the sigil` : 'Your sigil appears after 4 characters';
      if (match !== lastMatch) {
        if (match) { FT.haptic('success'); FT.intent('sigil matches the remembered one'); FT.announce('Same sigil as last time'); }
        lastMatch = match;
      }
      if (sp) FT.intent(`sigil #${sp.bits.toString(16).padStart(3, '0')} (12 bits)`);
      loop.wake();
    };
    input.addEventListener('input', update);
    let demoT = [];
    demo.addEventListener('click', () => {
      demoT.forEach(clearTimeout); demoT = [];
      const seq = []; const typo = 'maple-rivr-42', good = 'maple-river-42';
      for (let i = 1; i <= typo.length; i++) seq.push(typo.slice(0, i));
      seq.push('__pause__', '__pause__', '__pause__');
      for (let i = typo.length - 1; i >= 9; i--) seq.push(typo.slice(0, i));
      for (let i = 10; i <= good.length; i++) seq.push(good.slice(0, i));
      input.value = ''; update(); input.focus();
      seq.forEach((v, k) => demoT.push(setTimeout(() => { if (v !== '__pause__') { input.value = v; update(); } }, 140 * (k + 1))));
    });
    FT.onTheme(draw);
    ready = true; update(); draw();
    return { reset() { demoT.forEach(clearTimeout); input.value = ''; cur = null; update(); } };
  },
});
