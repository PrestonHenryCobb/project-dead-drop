// More static cross-checks: Enums.X.Y, Types.X, and require paths.
const fs = require("fs");
const path = require("path");
const root = "D:/Dead-Drop/Dead-Drop/src";
function walk(dir, out = []) {
	for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
		const p = path.join(dir, e.name);
		if (e.isDirectory()) walk(p, out);
		else if (p.endsWith(".luau")) out.push(p);
	}
	return out;
}
const files = walk(root);
let problems = 0;
const say = (m) => { console.log(m); problems++; };

// Types
const typesSrc = fs.readFileSync(root + "/shared/Types.luau", "utf8");
const typeNames = new Set([...typesSrc.matchAll(/^export type ([A-Za-z0-9_]+)/gm)].map((m) => m[1]));
// Enums: top-level sections and keys (two levels, via indentation)
const enumsSrc = fs.readFileSync(root + "/shared/Enums.luau", "utf8");
const sections = new Map();
let cur = null;
for (const line of enumsSrc.split("\n")) {
	const s = /^\t([A-Za-z0-9_]+) = \{/.exec(line);
	if (s) { cur = s[1]; sections.set(cur, new Set()); continue; }
	const k = /^\t\t([A-Za-z0-9_]+) = /.exec(line);
	if (k && cur) sections.get(cur).add(k[1]);
	if (/^\t\},?/.test(line)) cur = null;
}
console.log("types:", typeNames.size, "enum sections:", sections.size);

for (const f of files) {
	const src = fs.readFileSync(f, "utf8").replace(/--[^\n]*/g, "");
	const rel = f.replace(root + "/", "");
	if (!rel.endsWith("shared/Types.luau")) {
		for (const m of src.matchAll(/\bTypes\.([A-Z][A-Za-z0-9_]*)/g)) {
			if (!typeNames.has(m[1])) say(`TYPE ${rel}: Types.${m[1]} not exported`);
		}
	}
	if (!rel.endsWith("shared/Enums.luau")) {
		for (const m of src.matchAll(/\bEnums\.([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)/g)) {
			if (!sections.has(m[1])) say(`ENUM ${rel}: Enums.${m[1]} missing`);
			else if (!sections.get(m[1]).has(m[2])) say(`ENUM ${rel}: Enums.${m[1]}.${m[2]} missing`);
		}
	}
	// require(script.Parent.Parent.X.Y) -> resolve relative to this module's directory
	for (const m of src.matchAll(/require\(\s*script((?:\.Parent)*)((?:\.[A-Za-z0-9_]+)+)\s*\)/g)) {
		const ups = (m[1].match(/\.Parent/g) || []).length;
		// script itself is the file; Parent once = its folder
		let dir = path.dirname(f);
		for (let i = 1; i < ups; i++) dir = path.dirname(dir);
		const parts = m[2].split(".").filter(Boolean);
		let p = dir;
		let ok = true;
		for (let i = 0; i < parts.length; i++) {
			const isLast = i === parts.length - 1;
			const asFile = path.join(p, parts[i] + ".luau");
			const asDir = path.join(p, parts[i]);
			if (isLast) ok = fs.existsSync(asFile) || fs.existsSync(path.join(asDir, "init.luau"));
			else if (fs.existsSync(asDir)) p = asDir;
			else { ok = false; break; }
		}
		if (!ok) say(`REQUIRE ${rel}: script${m[1]}${m[2]} does not resolve`);
	}
	// Shared requires: Shared.Util.X, Shared:WaitForChild("Util"):WaitForChild("X"), Shared.Defs.X
	for (const m of src.matchAll(/require\(\s*Shared(?:\.([A-Za-z0-9_]+)|:WaitForChild\("([A-Za-z0-9_]+)"\))((?:(?:\.[A-Za-z0-9_]+)|(?::WaitForChild\("[A-Za-z0-9_]+"\)))*)\s*\)/g)) {
		const first = m[1] || m[2];
		const rest = [...(m[3] || "").matchAll(/(?:\.([A-Za-z0-9_]+)|:WaitForChild\("([A-Za-z0-9_]+)"\))/g)].map((x) => x[1] || x[2]);
		const chain = [first, ...rest];
		let p = root + "/shared";
		let ok = true;
		for (let i = 0; i < chain.length; i++) {
			const isLast = i === chain.length - 1;
			if (isLast) ok = fs.existsSync(path.join(p, chain[i] + ".luau")) || fs.existsSync(path.join(p, chain[i], "init.luau"));
			else if (fs.existsSync(path.join(p, chain[i]))) p = path.join(p, chain[i]);
			else { ok = false; break; }
		}
		if (!ok) say(`REQUIRE ${rel}: Shared.${chain.join(".")} does not resolve`);
	}
}
console.log("problems:", problems);
