# vpx

VP8 video for [XQ](https://akainq.github.io/xq/), through libvpx: an encoder for calls — a constant rate, no frames
held back, and after a loss every frame decodable only from the next keyframe, which comes when asked for — and a
decoder, of frames of I420: a plane of luma and two of chroma at half the width and height.

```bash
xq add vpx
```

```ts
import * as vpx from "vpx";

function main(): void {
  // 640 × 360 at 800 kbit/s, a keyframe at least every 600 frames.
  const e = vpx.encoder(640, 360, 800, 600);
  if (!e.ok) panic(e.error);
  const d = vpx.decoder();
  if (!d.ok) panic(d.error);
  const frame = new Uint8Array(vpx.frameBytes(640, 360));
  for (const c of vpx.encode(e.value, frame, 0, 33333, true)) {
    const p = vpx.decode(d.value, c.data);
    if (p !== null) console.log(`a keyframe: ${c.key}, ${p.width} × ${p.height}`);
  }
  vpx.closeEncoder(e.value);
  vpx.closeDecoder(d.value);
}
```

## Functions

| Function | What it does |
|---|---|
| `version(): string` | the release of the library, as it names it |
| `frameBytes(width: int, height: int): int` | the bytes of an I420 frame of that size |
| `encoder(width: int, height: int, kbps: int, keyEvery: int): Result<Encoder>` | an encoder of frames of that size at `kbps` kilobits a second, with a keyframe at least every `keyEvery` frames |
| `setBitrate(e: Encoder, kbps: int): void` | the encoder's rate from now on |
| `encode(e: Encoder, i420: Uint8Array, time: int, duration: int, key: bool): Coded[]` | a frame taken at `time` µs, `duration` µs before the next, a keyframe if `key`: the coded frames that come of it — one, or none if the encoder dropped it |
| `decoder(): Result<Decoder>` | a decoder |
| `decode(d: Decoder, data: Uint8Array): Picture \| null` | a coded frame, decoded; `null` if it did not decode — damaged, or one that needs a frame the decoder has not had |
| `decodeError(d: Decoder): string` | the decoder's last error, as the library says it |
| `closeEncoder(e: Encoder)`, `closeDecoder(d: Decoder)` | the encoder or the decoder closed, its memory freed |

`Coded` is `{ data: Uint8Array; key: bool; time: int }`: the frame's bytes, whether it decodes alone, and when it was
taken. `Picture` is `{ width, height, y, u, v, strideY, strideUV }`: the planes in rows of `strideY` and `strideUV`
bytes, chroma at half the width and height, rounded up.

## The library

The package calls libvpx through `declare library "vpx"`, which has to be there when a program runs:

- Linux: `libvpx.so.N` — `apt install libvpx9` on Ubuntu 24.04 and Debian 13 (`libvpx7` on Debian 12);
- Windows: `vpx.dll` on `PATH` or next to the program, built from the sources of a release
  ([webmproject/libvpx](https://github.com/webmproject/libvpx/releases)).

Without it the process that calls ends, as any call of a library that is not there ends it. The settings and the
frames of libvpx are C structures, read and written here by their offsets on x86-64; the encoder's defaults are
checked where they are expected, so a library whose structures moved is refused rather than misread. The version of
the interface (ABI) the library takes is found by trying. The encoder's controls go through a variadic function of
C, called as a function of three arguments: right on x86-64, where the package is tested (Windows and Linux).

## Tests

```bash
xq test
```

A second of a moving picture is coded at a call's rate — the first frame a keyframe, another when asked for — and
decodes back near the picture; a fresh decoder takes the stream from a keyframe on, but not from a frame between.
Without libvpx the test is skipped.

## License

MIT OR Apache-2.0, at your option: [LICENSE-MIT](LICENSE-MIT), [LICENSE-APACHE](LICENSE-APACHE).
