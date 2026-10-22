// Generates facade textures for the Cover Story cityscape as PNGs (no dependencies).
// Every texture is a 512 x 512 tile of 8 x 8 window cells (64 px each). All three facades leave the same inner pane
// (x 16..48, y 20..56 in a cell) as glass, so the lit-window overlays line up with any of them.
const fs = require("fs");
const zlib = require("zlib");
const path = require("path");
const OUT = process.argv[2] || __dirname; // where the PNGs go; upload them and put the ids in City.luau
const SIZE = 512, CELL = 64;

const crcTable = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function writePng(name, px) {
  const raw = Buffer.alloc((SIZE * 4 + 1) * SIZE);
  for (let y = 0; y < SIZE; y++) {
    raw[y * (SIZE * 4 + 1)] = 0;
    px.copy(raw, y * (SIZE * 4 + 1) + 1, y * SIZE * 4, (y + 1) * SIZE * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(SIZE, 0);
  ihdr.writeUInt32BE(SIZE, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
  fs.writeFileSync(path.join(OUT, name), png);
}
function rng(seed) {
  let s = seed >>> 0;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}
function canvas() { return Buffer.alloc(SIZE * SIZE * 4); }
function set(px, x, y, r, g, b, a = 255) {
  const i = (y * SIZE + x) * 4;
  px[i] = r; px[i + 1] = g; px[i + 2] = b; px[i + 3] = a;
}
function fill(px, x1, y1, x2, y2, f) {
  for (let y = y1; y < y2; y++) for (let x = x1; x < x2; x++) set(px, x, y, ...f(x, y));
}
const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)));
// Dark night glass: blue-black with a faint diagonal sky reflection and a little noise.
function glass(rand) {
  return (x, y) => {
    const refl = Math.max(0, Math.sin((x + y) * 0.012) * 10);
    const n = (rand() - 0.5) * 4;
    return [clamp(16 + refl + n), clamp(24 + refl * 1.2 + n), clamp(40 + refl * 1.6 + n)];
  };
}

// 1. Glass curtain wall: full-height panes in thin aluminium mullions, a heavier band every floor.
{
  const px = canvas(), r = rng(1);
  fill(px, 0, 0, SIZE, SIZE, glass(r));
  for (let i = 0; i < SIZE; i += CELL) {
    fill(px, i, 0, i + 3, SIZE, () => [78, 86, 98]); // vertical mullions
    fill(px, 0, i, SIZE, i + 5, () => [70, 78, 90]); // floor band
    fill(px, i + 32, 0, i + 33, SIZE, () => [52, 58, 68]); // thin split
  }
  writePng("facade_glass.png", px);
}
// 2. Office: stone spandrel band over a strip of glass on every floor.
{
  const px = canvas(), r = rng(2);
  fill(px, 0, 0, SIZE, SIZE, glass(r));
  for (let row = 0; row < SIZE; row += CELL) {
    fill(px, 0, row, SIZE, row + 18, (x, y) => {
      const n = (r() - 0.5) * 8;
      return [clamp(112 + n), clamp(108 + n), clamp(104 + n)];
    });
    fill(px, 0, row + 60, SIZE, row + 64, () => [92, 90, 88]);
  }
  for (let col = 0; col < SIZE; col += CELL) {
    fill(px, col, 0, col + 6, SIZE, () => [100, 98, 95]);
    fill(px, col + 32, 18, col + 34, SIZE, () => [60, 62, 66]);
  }
  writePng("facade_office.png", px);
}
// 3. Residential: brick-toned wall with a punched window per cell and a sill.
{
  const px = canvas(), r = rng(3);
  fill(px, 0, 0, SIZE, SIZE, (x, y) => {
    const n = (r() - 0.5) * 10;
    const mortar = y % 8 === 0 || (x + (Math.floor(y / 8) % 2) * 8) % 16 === 0;
    return mortar ? [clamp(70 + n), clamp(64 + n), clamp(62 + n)] : [clamp(96 + n), clamp(74 + n), clamp(66 + n)];
  });
  const g = glass(r);
  for (let cy = 0; cy < SIZE; cy += CELL) {
    for (let cx = 0; cx < SIZE; cx += CELL) {
      fill(px, cx + 14, cy + 16, cx + 50, cy + 58, () => [62, 60, 60]); // frame
      fill(px, cx + 16, cy + 18, cx + 48, cy + 56, g);
      fill(px, cx + 31, cy + 18, cx + 33, cy + 56, () => [62, 60, 60]); // glazing bar
      fill(px, cx + 12, cy + 58, cx + 52, cy + 61, () => [140, 136, 130]); // sill
    }
  }
  writePng("facade_residential.png", px);
}
// 4 and 5. Lit-window overlays: transparent except lit panes, warm or cool, some with blinds drawn part way.
function litMask(name, seed, chance) {
  const px = canvas(), r = rng(seed);
  for (let cy = 0; cy < SIZE; cy += CELL) {
    for (let cx = 0; cx < SIZE; cx += CELL) {
      if (r() > chance) continue;
      const tone = r();
      const base = tone < 0.65 ? [255, 206, 140] : tone < 0.9 ? [255, 236, 200] : [190, 214, 255];
      const level = 0.6 + r() * 0.4;
      const blind = r() < 0.35 ? Math.floor(r() * 20) : 0; // blinds drawn part way down
      fill(px, cx + 16, cy + 20, cx + 48, cy + 56, (x, y) => {
        const inBlind = y < cy + 20 + blind;
        const glow = level * (inBlind ? 0.35 : 1) * (0.85 + 0.15 * Math.sin((x - cx) * 0.2));
        return [clamp(base[0] * glow), clamp(base[1] * glow), clamp(base[2] * glow), 255];
      });
    }
  }
  writePng(name, px);
}
litMask("lit_a.png", 11, 0.32);
litMask("lit_b.png", 29, 0.16);
console.log(fs.readdirSync(OUT).filter((f) => f.endsWith(".png")).join(", "));
