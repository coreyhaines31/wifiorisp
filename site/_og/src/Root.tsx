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
        accent: '#0b8fb3',
        accentInk: '#875b10',
        accentFill: '#d9921a',
      } satisfies OgVideoProps
    }
  />
);
