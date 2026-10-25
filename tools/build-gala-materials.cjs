// Original, deterministic PBR data textures. No photographic inputs or random micro-noise.
// Run: node tools/build-gala-materials.cjs
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const out = path.join(__dirname, '..', 'assets', 'gala', 'materials');
fs.mkdirSync(out, { recursive: true });
const size = 1024;
function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(name, data) {
  const type = Buffer.from(name);
  const length = Buffer.alloc(4); length.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([type, data])));
  return Buffer.concat([length, type, data, crc]);
}
function png(name, pixel) {
  const rows = Buffer.alloc((size * 3 + 1) * size);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const offset = y * (size * 3 + 1) + 1 + x * 3;
    const color = pixel(x / size, y / size);
    rows.set(color, offset);
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(size); header.writeUInt32BE(size, 4); header[8] = 8; header[9] = 2;
  fs.writeFileSync(path.join(out, name + '.png'), Buffer.concat([
    Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header),
    chunk('IDAT', zlib.deflateSync(rows)), chunk('IEND', Buffer.alloc(0))
  ]));
}
const solid = value => () => [value, value, value];
png('neutral-albedo', solid(255)); // Tint comes from Part.Color, retaining outfit and clearance palettes.
png('flat-normal', () => [128, 128, 255]);
// Four broad longitudinal paint bands; seamless and intentionally free of fine wood grain.
png('walnut-albedo', (x) => {
  const value = Math.round(249 + 6 * Math.cos(x * Math.PI * 8));
  return [value, value, value];
});
const targets = {
  Ivory: { color: '#EFE8DA', roughness: .78, metalness: 0 },
  Walnut: { color: '#2A1B15', roughness: .42, metalness: 0 },
  Brass: { color: '#C89D54', roughness: .22, metalness: .92 },
  Steel: { color: '#1E242B', roughness: .72, metalness: .8 },
  Velvet: { color: '#581825', roughness: .9, metalness: 0 },
  Suit: { color: 'retain outfit palette', roughness: .82, metalness: 0 }
};
const manifest = {};
const written = new Set();
for (const [role, target] of Object.entries(targets)) {
  const maps = { ColorMap: role === 'Walnut' ? 'walnut-albedo.png' : 'neutral-albedo.png', NormalMap: 'flat-normal.png' };
  for (const field of ['roughness', 'metalness']) {
    const byte = Math.round(target[field] * 255);
    const name = `${field}-${byte}`;
    if (!written.has(name)) { png(name, solid(byte)); written.add(name); }
    maps[field === 'roughness' ? 'RoughnessMap' : 'MetalnessMap'] = name + '.png';
  }
  manifest[role] = { ...target, ...maps };
}
fs.writeFileSync(path.join(out, 'manifest.json'), JSON.stringify({ size, encoding: '8-bit RGB; grayscale PBR data; flat OpenGL normal; no baked shadows', materials: manifest }, null, 2) + '\n');
// Produces a real binding script without inventing upload IDs. Owner supplies filename -> uploaded ContentId.
let binding = '--!strict\n-- Run in the Studio EDIT command bar after filling ids from Asset Manager.\nlocal ids: { [string]: string } = {}\nlocal maps = {\n';
for (const [role, maps] of Object.entries(manifest)) {
  binding += `\t${role} = {\n`;
  for (const field of ['ColorMap','NormalMap','RoughnessMap','MetalnessMap']) binding += `\t\t${field} = assert(ids["${maps[field]}"], "Supply uploaded ID for ${maps[field]}"),\n`;
  binding += '\t},\n';
}
binding += `}
local clone = game.ServerScriptService.Server.Tools.Gala:Clone()
local shared = game.ReplicatedStorage.Shared:Clone()
shared.Name = "SharedOverride"
shared.Parent = clone
clone.Parent = game.ServerStorage
local ok, problem = pcall(function() require(clone.Materials).install(maps) end)
clone:Destroy()
assert(ok, tostring(problem))
`;
fs.writeFileSync(path.join(out, 'install.luau'), binding);
console.log(`Built ${written.size + 3} original 1024px PNG maps and a six-material binding manifest.`);
