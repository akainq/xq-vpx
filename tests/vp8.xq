// needs: vpx
// VP8 through libvpx: a second of a moving picture is coded at a call's rate — the first frame a
// keyframe, another when asked for — and decodes back near the picture; a fresh decoder takes the stream
// from a keyframe on, but not a frame between.
import * as vpx from "../lib";

const W = 320;
const H = 240;

/** Frame `n` of a picture that moves: diagonal bands of luma sliding right, chroma changing across. */
function picture(n: int): Uint8Array {
  const cw = W / 2;
  const ch = H / 2;
  const y = range(0, W * H).map((i) => ((i % W) + i / W + n * 3) & 255);
  const u = range(0, cw * ch).map((i) => 64 + (((i % cw) + n) & 127));
  const v = range(0, cw * ch).map((i) => 192 - ((i / cw) & 127));
  return Uint8Array.from([...y, ...u, ...v]);
}

/** The mean difference of luma between picture `p` and frame `f`. */
function lumaDiff(p: vpx.Picture, f: Uint8Array): float {
  const sum = range(0, H).reduce(
    (s, row) =>
      range(0, W).reduce((t, x) => t + Math.abs(p.y[row * p.strideY + x] - f[row * W + x]), s),
    0,
  );
  return toFloat(sum) / toFloat(W * H);
}

function main(): void {
  console.log("libvpx:", vpx.version().length > 0);
  const e = vpx.encoder(W, H, 500, 1000);
  if (!e.ok) panic(e.error);
  const d = vpx.decoder();
  if (!d.ok) panic(d.error);
  const pictures = range(0, 30).map((n) => picture(n));
  // 30 frames, 30 a second; the 15th a keyframe asked for.
  const frames = pictures.map((p, n) => vpx.encode(e.value, p, n * 33333, 33333, n === 15));
  console.log(
    "a coded frame for each picture:",
    frames.every((f) => f.length === 1),
  );
  console.log(
    "keyframes:",
    frames.map((f, n) => (f.length > 0 && f[0].key ? n : -1)).filter((n) => n >= 0),
  );
  const bytes = frames.reduce((s, f) => s + f.reduce((t, c) => t + c.data.length, 0), 0);
  console.log("a second of them within twice the rate:", bytes > 0 && bytes < (2 * 500 * 1000) / 8);
  const decoded = frames.map((f) => (f.length > 0 ? vpx.decode(d.value, f[0].data) : null));
  const near = decoded.every((p, n) => {
    if (p === null || p.width !== W || p.height !== H) return false;
    return lumaDiff(p, pictures[n]) < 4.0;
  });
  console.log("each decodes near its picture:", near);
  const fresh = vpx.decoder();
  if (!fresh.ok) panic(fresh.error);
  const between = vpx.decode(fresh.value, frames[16][0].data);
  const fromKey = vpx.decode(fresh.value, frames[15][0].data);
  const next = vpx.decode(fresh.value, frames[16][0].data);
  console.log(
    "a fresh decoder: a frame between",
    between === null ? "does not decode" : "decodes",
    "| from the keyframe on:",
    fromKey !== null && next !== null && lumaDiff(next, pictures[16]) < 4.0,
  );
  vpx.closeEncoder(e.value);
  vpx.closeDecoder(d.value);
  vpx.closeDecoder(fresh.value);
}
