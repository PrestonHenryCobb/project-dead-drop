// Writes the Never Seen Swag logo as SVG files with transparent backgrounds into assets/branding/.
//   node tools/build-nss-logo.cjs
// Keep the proportions in step with src/shared/Util/StudioLogo.luau (the in-game version): leaned red bars through the two dollar signs, a wifi sign
// with a slash that passes through the dot and crosses every ring.
const fs = require("fs");
const path = require("path");

const RED = "#C2383F";
const VARIANTS = { "nss-logo.svg": "#F4EFE6", "nss-logo-dark.svg": "#14161B" }; // light ink for dark backgrounds, dark ink for light ones

const BAR_LEAN = 12; // degrees, the lean of the red bars through the dollar signs
const WIFI = { x: 345, y: 122, rings: [24, 44, 64], sweep: 50, strike: 40, over: 14, tail: 18 };

function dollar(cx) {
	// The S of a dollar sign, as one brush-like stroke.
	return `<path d="M${cx + 21} 52 C${cx + 8} 32 ${cx - 24} 38 ${cx - 21} 62 C${cx - 18} 84 ${cx + 24} 72 ${cx + 22} 99 C${cx + 20} 124 ${cx - 14} 128 ${cx - 25} 108"/>`;
}

function bar(cx) {
	const top = 14, bottom = 136, half = 22;
	return `<g transform="rotate(${BAR_LEAN} ${cx} 75)"><path d="M${cx} ${top} V${bottom} M${cx - half} ${top} H${cx + half} M${cx - half} ${bottom} H${cx + half}"/></g>`;
}

function arc(radius) {
	const a = (WIFI.sweep * Math.PI) / 180;
	const x1 = WIFI.x - Math.sin(a) * radius, y1 = WIFI.y - Math.cos(a) * radius;
	const x2 = WIFI.x + Math.sin(a) * radius, y2 = WIFI.y - Math.cos(a) * radius;
	return `<path d="M${x1.toFixed(1)} ${y1.toFixed(1)} A${radius} ${radius} 0 0 1 ${x2.toFixed(1)} ${y2.toFixed(1)}"/>`;
}

function slash() {
	// Through the dot, up and to the left across every ring, ending a little past the outer one; a short tail below the dot.
	const t = (WIFI.strike * Math.PI) / 180;
	const dx = -Math.sin(t), dy = -Math.cos(t);
	const reach = WIFI.rings[WIFI.rings.length - 1] + WIFI.over;
	return `<path d="M${(WIFI.x + dx * reach).toFixed(1)} ${(WIFI.y + dy * reach).toFixed(1)} L${(WIFI.x - dx * WIFI.tail).toFixed(1)} ${(WIFI.y - dy * WIFI.tail).toFixed(1)}"/>`;
}

function svg(ink) {
	return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 430 160" width="860" height="320" role="img" aria-label="Never Seen Swag">
	<title>Never Seen Swag</title>
	<g fill="none" stroke="${ink}" stroke-linecap="round" stroke-linejoin="round" stroke-width="13">
		<path d="M22 122 L30 30 L72 120 L84 28"/>
		${dollar(150)}
		${dollar(232)}
	</g>
	<g fill="none" stroke="${RED}" stroke-linecap="round" stroke-linejoin="round" stroke-width="7">
		${bar(150)}
		${bar(232)}
	</g>
	<g fill="none" stroke="${ink}" stroke-linecap="round" stroke-width="10">
		${WIFI.rings.map(arc).join("\n\t\t")}
	</g>
	<circle cx="${WIFI.x}" cy="${WIFI.y}" r="7" fill="${ink}"/>
	<g fill="none" stroke="${RED}" stroke-linecap="round" stroke-width="8">
		${slash()}
	</g>
</svg>
`;
}

const dir = path.join(__dirname, "..", "assets", "branding");
fs.mkdirSync(dir, { recursive: true });
for (const [name, ink] of Object.entries(VARIANTS)) {
	fs.writeFileSync(path.join(dir, name), svg(ink));
	console.log("wrote", path.join("assets", "branding", name));
}
