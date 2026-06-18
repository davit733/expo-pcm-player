# expo-pcm-player

A small native streaming PCM audio player for Expo and React Native, implemented with the Expo Modules API.

## Supported audio format

- Signed 16-bit PCM
- Little-endian samples
- Base64-encoded chunks
- Mono or stereo
- Configurable sample rate

## Installation

Install directly from GitHub:

```sh
npm install github:davit733/expo-pcm-player
```

This package contains native code. Rebuild your development client or application after installing it; it is not available in Expo Go.

## Usage

```ts
import {
  configurePcmPlayer,
  disposePcmPlayer,
  enqueuePcmAudio,
  flushPcmAudio,
} from 'expo-pcm-player';

configurePcmPlayer(24_000, 1);

const durationSeconds = enqueuePcmAudio(base64PcmChunk);

flushPcmAudio();
disposePcmPlayer();
```

## API

### `configurePcmPlayer(sampleRate, channels?)`

Configures playback. `channels` defaults to `1` and supports mono (`1`) or stereo (`2`).

### `enqueuePcmAudio(audio)`

Queues a Base64-encoded PCM16 chunk and returns its duration in seconds.

### `flushPcmAudio()`

Immediately discards queued audio.

### `disposePcmPlayer()`

Stops playback and releases native audio resources.

## Platform support

- Android
- iOS 16.4+

## License

MIT
