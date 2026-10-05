// vpx: VP8 video for XQ — libvpx called through `declare library`: an encoder for calls (a constant
// rate, no frames held back, a keyframe when asked for) and a decoder, of frames of I420 — a plane of
// luma and two of chroma at half the width and height. The library is the system's: libvpx.so.N on Linux
// (libvpx9 of Ubuntu 24.04 and Debian 13), vpx.dll on PATH or next to the program on Windows. Without it
// the process that calls ends, as any call of a library that is not there ends it.
//
// The library takes its settings and gives its frames in C structures: they are read and written here
// by their offsets on x86-64, the same on Windows and Linux but for `unsigned long`. The settings the
// encoder starts from are the library's own defaults, checked where they are expected, so a library
// whose structures moved is refused rather than misread. The version of the interface (ABI) that
// `vpx_codec_*_init_ver` takes differs from release to release: the first one the library does not
// refuse as a mismatch is it.
import * as ffi from "std/ffi";
import * as os from "std/os";

declare library "vpx" {
  function vpx_codec_vp8_cx(): Pointer;
  function vpx_codec_vp8_dx(): Pointer;
  function vpx_codec_version_str(): string;
  function vpx_codec_enc_config_default(iface: Pointer, cfg: Pointer, usage: u32): i32;
  function vpx_codec_enc_init_ver(
    ctx: Pointer,
    iface: Pointer,
    cfg: Pointer,
    flags: i64,
    ver: i32,
  ): i32;
  function vpx_codec_enc_config_set(ctx: Pointer, cfg: Pointer): i32;
  // `unsigned long` and `long` are 32 bits on Windows and 64 on Linux: they go as 64, of which
  // Windows reads the low half.
  function vpx_codec_encode(
    ctx: Pointer,
    img: Pointer | null,
    pts: i64,
    duration: u64,
    flags: i64,
    deadline: u64,
  ): i32;
  function vpx_codec_get_cx_data(ctx: Pointer, iter: Pointer): Pointer | null;
  // Variadic in C (`vpx_codec_control_(ctx, id, ...)`): every control used here takes one int, which
  // the calling conventions of x86-64 pass as for a function of three arguments.
  function vpx_codec_control_(ctx: Pointer, id: i32, value: i32): i32;
  function vpx_codec_destroy(ctx: Pointer): i32;
  function vpx_codec_dec_init_ver(
    ctx: Pointer,
    iface: Pointer,
    cfg: Pointer,
    flags: i64,
    ver: i32,
  ): i32;
  function vpx_codec_decode(
    ctx: Pointer,
    data: Uint8Array,
    size: u32,
    user: Pointer | null,
    deadline: i64,
  ): i32;
  function vpx_codec_get_frame(ctx: Pointer, iter: Pointer): Pointer | null;
  function vpx_codec_error(ctx: Pointer): string;
  function vpx_img_wrap(
    img: Pointer,
    fmt: i32,
    w: u32,
    h: u32,
    align: u32,
    data: Pointer,
  ): Pointer | null;
}

declare library "c" {
  function malloc(n: usize): Pointer;
  function free(p: Pointer): void;
  function memset(p: Pointer, c: i32, n: usize): Pointer;
  function memcpy(dst: Pointer, src: Uint8Array, n: usize): Pointer;
}

/** Bytes of memory for the library's structures: more than each takes in any release. */
const CTX_BYTES = 256;
const CFG_BYTES = 2048;
const IMG_BYTES = 256;

/** Offsets in `vpx_codec_enc_cfg_t`. */
const G_THREADS = 4;
const G_W = 12;
const G_H = 16;
const G_TIMEBASE = 28;
const G_ERROR_RESILIENT = 36;
const G_LAG = 44;
const RC_END_USAGE = 72;
const RC_TARGET_BITRATE = 112;
const RC_MIN_Q = 116;
const RC_MAX_Q = 120;
const RC_UNDERSHOOT = 124;
const RC_OVERSHOOT = 128;
const RC_BUF = 132;
const RC_BUF_INITIAL = 136;
const RC_BUF_OPTIMAL = 140;
const KF_MODE = 160;
const KF_MAX = 168;

/** Offsets in `vpx_codec_cx_pkt_t` (`flags` comes after an `unsigned long`) and `vpx_image_t`. */
const PKT_BUF = 8;
const PKT_SIZE = 16;
const PKT_PTS = 24;
const IMG_D_W = 24;
const IMG_D_H = 28;
const IMG_PLANES = 48;
const IMG_STRIDES = 80;

/** Values of the library's enums and flags. */
const VPX_CBR = 1;
const VPX_KF_AUTO = 1;
const VPX_CODEC_ABI_MISMATCH = 3;
const VPX_CODEC_CX_FRAME_PKT = 0;
const VPX_FRAME_IS_KEY = 1;
const VPX_EFLAG_FORCE_KF = 1;
const VPX_DL_REALTIME = 1;
const VPX_IMG_FMT_I420 = 0x102;
const VPX_ERROR_RESILIENT_DEFAULT = 1;
const VP8E_SET_CPUUSED = 13;
const VP8E_SET_NOISE_SENSITIVITY = 15;
const VP8E_SET_STATIC_THRESHOLD = 17;
const VP8E_SET_MAX_INTRA_BITRATE_PCT = 26;

/** The interface versions of libvpx 1.16 — tried first — and the range tried after. */
const ENCODER_ABI = 39;
const DECODER_ABI = 12;
const MOST_ABI = 200;

/** Times are in µs. */
const TIMEBASE = 1000000;

export type Encoder = {
  ctx: Pointer;
  cfg: Pointer;
  img: Pointer;
  buf: Pointer;
  iter: Pointer;
  width: int;
  height: int;
  /** Bytes of a frame, and where a coded frame's flags are (after an `unsigned long`). */
  size: int;
  flagsAt: int;
};

/** A coded frame: its bytes, whether it is a keyframe (one that decodes alone), and when it was taken,
 * µs. */
export type Coded = { data: Uint8Array; key: bool; time: int };

export type Decoder = { ctx: Pointer; iter: Pointer };

/** A decoded frame: `width` × `height` of luma in rows of `strideY` bytes, chroma in rows of `strideUV`
 * (half the width and height, rounded up). */
export type Picture = {
  width: int;
  height: int;
  y: Uint8Array;
  u: Uint8Array;
  v: Uint8Array;
  strideY: int;
  strideUV: int;
};

/** The release of the library, as it names it. */
export function version(): string {
  return vpx_codec_version_str();
}

/** The bytes of an I420 frame of `width` × `height`. */
export function frameBytes(width: int, height: int): int {
  const cw = (width + 1) >> 1;
  const ch = (height + 1) >> 1;
  return width * height + 2 * cw * ch;
}

/** An encoder of `width` × `height` frames for a call: `kbps` kilobits a second at a constant rate,
 * no frames held back, every frame decodable after a loss of the ones before it only from the next
 * keyframe, which comes when asked for (`encode` with `key`) and at least every `keyEvery` frames. */
export function encoder(width: int, height: int, kbps: int, keyEvery: int): Result<Encoder> {
  const iface = vpx_codec_vp8_cx();
  const cfg = zeroed(CFG_BYTES);
  if (vpx_codec_enc_config_default(iface, cfg, 0) !== 0) {
    free(cfg);
    return { ok: false, error: "vpx: no default settings of the encoder" };
  }
  const defaults = ffi.readBytes(cfg, CFG_BYTES);
  // VP8's own defaults where this module expects them: 320 × 240, 1/30 s, 256 kbit/s.
  const known =
    get32(defaults, G_W) === 320 &&
    get32(defaults, G_H) === 240 &&
    get32(defaults, G_TIMEBASE) === 1 &&
    get32(defaults, G_TIMEBASE + 4) === 30 &&
    get32(defaults, RC_TARGET_BITRATE) === 256;
  if (!known) {
    free(cfg);
    return {
      ok: false,
      error: `vpx: the encoder's settings of libvpx ${version()} are not where expected`,
    };
  }
  const pixels = width * height;
  const threads = pixels >= 1280 * 720 ? 4 : pixels >= 640 * 360 ? 2 : 1;
  const set: [int, int][] = [
    [G_THREADS, threads],
    [G_W, width],
    [G_H, height],
    [G_TIMEBASE, 1],
    [G_TIMEBASE + 4, TIMEBASE],
    [G_ERROR_RESILIENT, VPX_ERROR_RESILIENT_DEFAULT],
    [G_LAG, 0],
    [RC_END_USAGE, VPX_CBR],
    [RC_TARGET_BITRATE, kbps],
    [RC_MIN_Q, 2],
    [RC_MAX_Q, 56],
    [RC_UNDERSHOOT, 100],
    [RC_OVERSHOOT, 15],
    [RC_BUF, 1000],
    [RC_BUF_INITIAL, 500],
    [RC_BUF_OPTIMAL, 600],
    [KF_MODE, VPX_KF_AUTO],
    [KF_MAX, keyEvery],
  ];
  const settings = set.reduce((b, [at, v]) => put32(b, at, v), defaults);
  memcpy(cfg, settings, CFG_BYTES);
  const ctx = zeroed(CTX_BYTES);
  const rc = initialized((ver) => vpx_codec_enc_init_ver(ctx, iface, cfg, 0, ver), ENCODER_ABI, 0);
  if (rc !== 0) {
    free(ctx);
    free(cfg);
    return { ok: false, error: `vpx: the encoder did not start (${rc})` };
  }
  vpx_codec_control_(ctx, VP8E_SET_CPUUSED, -6);
  vpx_codec_control_(ctx, VP8E_SET_STATIC_THRESHOLD, 1);
  vpx_codec_control_(ctx, VP8E_SET_NOISE_SENSITIVITY, 0);
  // A keyframe at most nine times the size of the others: one does not stall the call.
  vpx_codec_control_(ctx, VP8E_SET_MAX_INTRA_BITRATE_PCT, 900);
  const size = frameBytes(width, height);
  const buf = zeroed(size);
  const img = zeroed(IMG_BYTES);
  vpx_img_wrap(img, VPX_IMG_FMT_I420, width, height, 1, buf);
  return {
    ok: true,
    value: {
      ctx,
      cfg,
      img,
      buf,
      iter: zeroed(8),
      width,
      height,
      size,
      flagsAt: os.platform() === "windows" ? 36 : 40,
    },
  };
}

/** The encoder at `kbps` kilobits a second from now on. */
export function setBitrate(e: Encoder, kbps: int): void {
  memcpy(e.cfg, put32(ffi.readBytes(e.cfg, CFG_BYTES), RC_TARGET_BITRATE, kbps), CFG_BYTES);
  vpx_codec_enc_config_set(e.ctx, e.cfg);
}

/** Frame `i420` taken at `time` µs, `duration` µs before the next, a keyframe if `key`: the coded
 * frames that come of it — one, or none if the encoder dropped it. */
export function encode(e: Encoder, i420: Uint8Array, time: int, duration: int, key: bool): Coded[] {
  if (i420.length < e.size) return [];
  memcpy(e.buf, i420, e.size);
  const flags = key ? VPX_EFLAG_FORCE_KF : 0;
  if (vpx_codec_encode(e.ctx, e.img, time, duration, flags, VPX_DL_REALTIME) !== 0) return [];
  memset(e.iter, 0, 8);
  return coded(e, []);
}

function coded(e: Encoder, got: Coded[]): Coded[] {
  const p = vpx_codec_get_cx_data(e.ctx, e.iter);
  if (p === null) return got;
  const buf = ffi.readPointer(p, PKT_BUF);
  if (ffi.readI32(p, 0) !== VPX_CODEC_CX_FRAME_PKT || buf === null) return coded(e, got);
  const frame: Coded = {
    data: ffi.readBytes(buf, ffi.readI64(p, PKT_SIZE)),
    key: (ffi.readU32(p, e.flagsAt) & VPX_FRAME_IS_KEY) !== 0,
    time: ffi.readI64(p, PKT_PTS),
  };
  return coded(e, got.append(frame));
}

export function closeEncoder(e: Encoder): void {
  vpx_codec_destroy(e.ctx);
  [e.ctx, e.cfg, e.img, e.buf, e.iter].forEach((p) => free(p));
}

export function decoder(): Result<Decoder> {
  const iface = vpx_codec_vp8_dx();
  // `vpx_codec_dec_cfg_t`: one thread, the size from the stream.
  const cfg = zeroed(16);
  memcpy(cfg, put32(new Uint8Array(16), 0, 1), 16);
  const ctx = zeroed(CTX_BYTES);
  const rc = initialized((ver) => vpx_codec_dec_init_ver(ctx, iface, cfg, 0, ver), DECODER_ABI, 0);
  free(cfg);
  if (rc !== 0) {
    free(ctx);
    return { ok: false, error: `vpx: the decoder did not start (${rc})` };
  }
  return { ok: true, value: { ctx, iter: zeroed(8) } };
}

/** Coded frame `data`, decoded: the picture, or null if it did not decode (damaged, or a frame that
 * needs one the decoder has not had). */
export function decode(d: Decoder, data: Uint8Array): Picture | null {
  if (vpx_codec_decode(d.ctx, data, data.length, null, 0) !== 0) return null;
  memset(d.iter, 0, 8);
  const img = vpx_codec_get_frame(d.ctx, d.iter);
  if (img === null) return null;
  const width = ffi.readU32(img, IMG_D_W);
  const height = ffi.readU32(img, IMG_D_H);
  const strideY = ffi.readI32(img, IMG_STRIDES);
  const strideUV = ffi.readI32(img, IMG_STRIDES + 4);
  const py = ffi.readPointer(img, IMG_PLANES);
  const pu = ffi.readPointer(img, IMG_PLANES + 8);
  const pv = ffi.readPointer(img, IMG_PLANES + 16);
  if (py === null || pu === null || pv === null) return null;
  const ch = (height + 1) >> 1;
  return {
    width,
    height,
    y: ffi.readBytes(py, strideY * height),
    u: ffi.readBytes(pu, strideUV * ch),
    v: ffi.readBytes(pv, strideUV * ch),
    strideY,
    strideUV,
  };
}

/** The last error of a decoder, as the library says it. */
export function decodeError(d: Decoder): string {
  return vpx_codec_error(d.ctx);
}

export function closeDecoder(d: Decoder): void {
  vpx_codec_destroy(d.ctx);
  free(d.ctx);
  free(d.iter);
}

/** `start` and then every interface version up to `MOST_ABI` (after `tried` of them), until the
 * library takes one: what `init` returns for it — 0, or the error — or the mismatch. */
function initialized(init: (ver: int) => int, start: int, tried: int): int {
  const ver = tried === 0 ? start : tried;
  const rc = init(ver);
  if (rc !== VPX_CODEC_ABI_MISMATCH || tried >= MOST_ABI) return rc;
  return initialized(init, start, tried + 1);
}

/** `n` bytes of C memory, zeroed. */
function zeroed(n: int): Pointer {
  const p = malloc(n);
  memset(p, 0, n);
  return p;
}

/** The unsigned 32-bit number at `at` of `b` (little-endian), and `b` with `v` there. */
function get32(b: Uint8Array, at: int): int {
  return b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24);
}

function put32(b: Uint8Array, at: int, v: int): Uint8Array {
  return b
    .with(at, v & 255)
    .with(at + 1, (v >> 8) & 255)
    .with(at + 2, (v >> 16) & 255)
    .with(at + 3, (v >> 24) & 255);
}
