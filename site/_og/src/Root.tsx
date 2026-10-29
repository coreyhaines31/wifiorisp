import {Composition} from 'remotion';
import {OgVideo, type OgVideoProps} from './OgVideo';

// 6 s at 60 fps. Frame 225 (3.75 s) is the resting frame, rendered as the og:image still.
export const RemotionRoot = () => (
  <Composition
    id="OgVideo"
    component={OgVideo}
    durationInFrames={360}
    fps={60}
    width={1200}
    height={630}
    defaultProps={
      {
        name: 'WiFi or ISP',
        icon: 'icon.png',
        headline: 'Is it your Wi\u2011Fi or',
        headlineAccent: 'your ISP?',
        sub: 'Free for macOS · wifiorisp.com',
        accent: '#e8930c',
        accentInk: '#a8650a',
        accentFill: '#f5a623',
        field: ['#ffd98a', '#ffeab8', '#c9dcff', '#ffe0b0'],
      } satisfies OgVideoProps
    }
  />
);
