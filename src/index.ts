import { requireNativeModule } from 'expo';

type PcmPlayerNativeModule = {
  configure: (sampleRate: number, channels: number) => void;
  enqueue: (audio: string) => number;
  flush: () => void;
  dispose: () => void;
};

let PcmPlayer: PcmPlayerNativeModule | null = null;

try {
  PcmPlayer = requireNativeModule<PcmPlayerNativeModule>('PcmPlayer');
} catch {
  PcmPlayer = null;
}

const getPcmPlayer = () => {
  if (!PcmPlayer) {
    throw new Error('PCM player native module is not available in this build.');
  }

  return PcmPlayer;
};

export const configurePcmPlayer = (sampleRate: number, channels = 1) => {
  getPcmPlayer().configure(sampleRate, channels);
};

export const enqueuePcmAudio = (audio: string) => getPcmPlayer().enqueue(audio);

export const flushPcmAudio = () => {
  getPcmPlayer().flush();
};

export const disposePcmPlayer = () => {
  getPcmPlayer().dispose();
};
