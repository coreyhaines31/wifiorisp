import {Easing, interpolate, interpolateColors, useCurrentFrame, useVideoConfig} from 'remotion';
import {INK, INK_2} from './OgVideo';

// WiFi or ISP times the router and the internet together: the router stays at 7 ms while the internet climbs to 400 ms,
// the verdict lands, then the internet settles back to where it starts, so the loop has no seam.
const W = 372;
const H = 56;
const MAX = 440;
const BASE = 24;
const PEAK = 400;
const GOOD = '#1f9d55';

const STANDARD = Easing.bezier(0.4, 0, 0.2, 1);
const IN_OUT = Easing.bezier(0.65, 0, 0.35, 1);
const OUT_EASE = Easing.bezier(0, 0, 0.2, 1);

const smoothstep = (v: number) => {
  const c = Math.min(1, Math.max(0, v));
  return c * c * (3 - 2 * c);
};
// Jitter that scrolls a whole number of cycles per loop (scroll runs 0 → 1), so the sparklines look live and the last frame matches the first.
const jitter = (u: number, scroll: number, seed: number) =>
  0.55 * Math.sin(2 * Math.PI * (7 * u + 3 * scroll) + seed) + 0.45 * Math.sin(2 * Math.PI * (13 * u + 5 * scroll) + seed * 2.3);
// Square-root scale, so the few-ms wobble near the floor still shows next to a 400 ms spike.
const yOf = (ms: number) => H - 3 - Math.sqrt(Math.max(0, Math.min(ms, MAX)) / MAX) * (H - 8);
const line = (value: (u: number) => number) => {
  let d = '';
  for (let px = 0; px <= W; px += 3) d += `${px === 0 ? 'M' : ' L'}${px} ${yOf(value(px / W)).toFixed(2)}`;
  return d;
};

export const LatencyCard = ({accentInk, accentFill}: {accentInk: string; accentFill: string}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = frame / fps;
  const ease = (input: number[], output: number[], easing: (n: number) => number) =>
    interpolate(t, input, output, {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing});

  // 0.4–2.6s internet climbs · 1.05–1.45s Fast → Slow as it passes ~100 ms · 2.75–3.0s verdict in · hold to 4.5s · 4.5–4.68s verdict out · 4.6–5.8s settles
  const level = ease([0.4, 2.6], [0, 1], IN_OUT) * (1 - ease([4.6, 5.8], [0, 1], IN_OUT));
  const internet = BASE + (PEAK - BASE) * level;
  const slowOut = ease([1.05, 1.21], [0, 1], STANDARD);
  const slowIn = ease([1.19, 1.45], [0, 1], OUT_EASE);
  const fastBackOut = ease([5.3, 5.46], [0, 1], STANDARD);
  const fastBackIn = ease([5.44, 5.7], [0, 1], OUT_EASE);
  const fastOpacity = 1 - slowOut + fastBackIn;
  const fastY = fastBackIn > 0 ? (1 - fastBackIn) * 6 : -5 * slowOut;
  const slowOpacity = slowIn - fastBackOut;
  const slowY = fastBackOut > 0 ? -5 * fastBackOut : (1 - slowIn) * 6;
  // Text swaps overlap only briefly, so two lines never sit on top of each other at half opacity.
  const verdictIn = ease([2.8, 3.05], [0, 1], OUT_EASE);
  const shown = verdictIn * ease([4.5, 4.68], [1, 0], STANDARD);
  const comparing = 1 - ease([2.7, 2.88], [0, 1], STANDARD) + ease([4.62, 4.82], [0, 1], STANDARD);

  const scroll = ease([0, 5.8], [0, 1], IN_OUT);
  const router = (u: number) => 7 + 2 * jitter(u, scroll, 0.7);
  // Recent samples (the right edge) carry the climb; older ones stay near the baseline.
  const net = (u: number) => {
    const recent = smoothstep((u - 0.25) / 0.7);
    const ms = BASE + (internet - BASE) * recent;
    return ms + (3 + ms * 0.08) * jitter(u, scroll, 2.1);
  };
  const internetColor = interpolateColors(level, [0, 0.5, 1], [INK, accentInk, accentInk]);

  const label = (text: string) => <div style={{fontSize: 22, fontWeight: 600, letterSpacing: '-0.015em', color: INK}}>{text}</div>;
  const pill = (text: string, color: string, opacity: number, y: number) => (
    <span style={{position: 'absolute', left: 0, top: 0, fontSize: 18, fontWeight: 600, color, opacity, transform: `translateY(${y}px)`}}>{text}</span>
  );
  const spark = (d: string, color: string) => (
    <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} style={{display: 'block', overflow: 'visible', marginTop: 6}}>
      <line x1={0} y1={H - 3} x2={W} y2={H - 3} stroke="rgba(0,0,0,0.1)" strokeWidth={2} />
      <path d={`${d} V${H - 3} H0 Z`} fill={color} opacity={0.14} />
      <path d={d} fill="none" stroke={color} strokeWidth={3.5} strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );

  return (
    <div
      style={{width: '100%', height: '100%', boxSizing: 'border-box', padding: '28px 32px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between', borderRadius: 30, background: 'rgba(251,251,253,0.9)',
        boxShadow: '0 0 0 1px rgba(0,0,0,0.06), 0 2px 6px rgba(0,0,0,0.05), 0 16px 36px rgba(14,22,48,0.12)', fontVariantNumeric: 'tabular-nums'}}
    >
      <div style={{fontSize: 20, color: INK_2}}>Timing both sides at once</div>
      <div>
        <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end'}}>
          <div>
            {label('Router')}
            <div style={{position: 'relative', height: 24}}>{pill('Fast', GOOD, 1, 0)}</div>
          </div>
          <div style={{fontSize: 44, fontWeight: 700, letterSpacing: '-0.035em', color: GOOD, lineHeight: 1}}>7 ms</div>
        </div>
        {spark(line(router), GOOD)}
      </div>
      <div>
        <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end'}}>
          <div>
            {label('Internet')}
            <div style={{position: 'relative', height: 24}}>
              {pill('Fast', GOOD, fastOpacity, fastY)}
              {pill('Slow', accentInk, slowOpacity, slowY)}
            </div>
          </div>
          <div style={{fontSize: 44, fontWeight: 700, letterSpacing: '-0.035em', color: internetColor, lineHeight: 1}}>{Math.round(internet)} ms</div>
        </div>
        {spark(line(net), accentFill)}
      </div>
      <div style={{position: 'relative', height: 74}}>
        <div style={{position: 'absolute', left: 0, top: 8, fontSize: 30, fontWeight: 600, letterSpacing: '-0.02em', color: '#8e8e93', opacity: comparing}}>
          Comparing…
        </div>
        <div style={{position: 'absolute', left: 0, top: 0, opacity: shown, transform: `translateY(${(1 - verdictIn) * 8}px)`}}>
          <div style={{fontSize: 38, fontWeight: 700, letterSpacing: '-0.03em', color: accentInk, whiteSpace: 'nowrap'}}>It's your ISP</div>
          <div style={{fontSize: 22, color: INK_2, marginTop: 2, whiteSpace: 'nowrap'}}>Your Wi‑Fi is fine</div>
        </div>
      </div>
    </div>
  );
};
