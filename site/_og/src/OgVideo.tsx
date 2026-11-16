import {loadFont as loadBarlow} from '@remotion/google-fonts/Barlow';
import {loadFont as loadDisplay} from '@remotion/google-fonts/BarlowSemiCondensed';
import {AbsoluteFill, Img, staticFile} from 'remotion';
import {LatencyCard} from './LatencyCard';

loadBarlow('normal', {weights: ['400', '500', '600'], subsets: ['latin']});
loadDisplay('normal', {weights: ['300', '600', '700'], subsets: ['latin']});

export type OgVideoProps = {
  name: string;
  icon: string;
  headline: string;
  headlineAccent: string;
  // Longer headlines can step down from 84 px and let the light phrase wrap.
  headlineSize?: number;
  accentWraps?: boolean;
  sub: string;
  // The app's pilot light: the only place the accent shows.
  accent: string;
  // Status readings (caution) for the slow side.
  accentInk: string;
  accentFill: string;
};

export const FONT = 'Barlow, "Helvetica Neue", system-ui, sans-serif';
export const DISPLAY = '"Barlow Semi Condensed", "Helvetica Neue", system-ui, sans-serif';
export const INK = '#161616';
export const INK_2 = '#3d3f41';

// Brushed aluminium, as in the site kit's --bx-brush.
const BRUSH = [
  'repeating-linear-gradient(0deg, rgba(255,255,255,.22) 0 1px, rgba(0,0,0,.035) 1px 2px, transparent 2px 3px)',
  'repeating-linear-gradient(0deg, rgba(0,0,0,.035) 0 1px, transparent 1px 7px)',
  'linear-gradient(100deg, rgba(255,255,255,0) 18%, rgba(255,255,255,.5) 40%, rgba(255,255,255,0) 64%)',
  'linear-gradient(180deg, #e7e8e9, #c3c5c7)',
].join(', ');

// The family shell: a brushed plate, brand and headline on the left, the app's instrument mounted on the right.
export const OgVideo = (props: OgVideoProps) => (
  <AbsoluteFill style={{background: BRUSH, color: INK, fontFamily: FONT, WebkitFontSmoothing: 'antialiased'}}>
    <div style={{position: 'absolute', left: 84, top: 80, width: 540, height: 470, display: 'flex', flexDirection: 'column', justifyContent: 'space-between'}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 18, fontFamily: DISPLAY, fontSize: 36, fontWeight: 700}}>
        <Img src={staticFile(props.icon)} style={{width: 84, height: 84, filter: 'drop-shadow(0 6px 10px rgba(0,0,0,0.25))'}} />
        {props.name}
      </div>
      <div>
        <span style={{display: 'inline-flex', alignItems: 'center', gap: 12, fontFamily: DISPLAY, fontWeight: 600, fontSize: 16, letterSpacing: '0.26em', textTransform: 'uppercase', background: '#1b1b1b', color: '#d8d9da', padding: '9px 14px 9px 12px', borderRadius: 2}}>
          <i style={{width: 9, height: 9, borderRadius: '50%', background: props.accent, boxShadow: `0 0 7px ${props.accent}`}} />
          Free for Mac
        </span>
        <div style={{fontFamily: DISPLAY, fontSize: props.headlineSize ?? 84, lineHeight: 0.96, fontWeight: 600, marginTop: 22}}>
          {props.headline} <span style={{fontWeight: 300, whiteSpace: props.accentWraps ? 'normal' : 'nowrap'}}>{props.headlineAccent}</span>
        </div>
      </div>
      <div style={{fontSize: 26, color: INK_2}}>{props.sub}</div>
    </div>
    <div style={{position: 'absolute', left: 664, top: 80, width: 452, height: 470}}>
      <LatencyCard accentInk={props.accentInk} accentFill={props.accentFill} />
    </div>
  </AbsoluteFill>
);
