// Heuristic scan for tunable-looking numeric literals outside GameConfig (CLAUDE.md rule 2).
const fs = require("fs");
const path = require("path");
const root = "D:/Dead-Drop/Dead-Drop/src/server";
function walk(dir, out = []) {
	for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
		const p = path.join(dir, e.name);
		if (e.isDirectory()) {
			if (e.name === "Tools") continue; // Studio-only generators
			walk(p, out);
		} else if (p.endsWith(".luau")) out.push(p);
	}
	return out;
}
const ok = new Set(["0", "1", "2", "3", "0.5", "1e-3", "1e-4", "1e-6", "100", "60", "360", "180", "90", "10", "1000", "0.1", "4", "5", "8"]);
const results = [];
for (const f of walk(root)) {
	const lines = fs.readFileSync(f, "utf8").split("\n");
	lines.forEach((line, i) => {
		const code = line.replace(/--.*$/, "").replace(/"[^"]*"/g, '""').replace(/`[^`]*`/g, "``");
		if (/^\s*(type|export type)\b/.test(code)) return;
		for (const m of code.matchAll(/(?<![\w.\]])(\d+\.\d+|\d{2,}|[3-9])(?![\w.])/g)) {
			const n = m[1];
			if (ok.has(n)) continue;
			// skip indices like [3], Vector3 / Color3.fromRGB args, UDim sizes, math helpers
			if (/Color3\.|fromRGB|Vector3\.new\(|CFrame\.|UDim|Enum\./.test(code)) continue;
			if (new RegExp("\\[\\s*" + n + "\\s*\\]").test(code)) continue;
			results.push(`${path.relative(root, f)}:${i + 1}: ${n}   ${code.trim().slice(0, 100)}`);
		}
	});
}
console.log("candidates:", results.length);
const byFile = {};
for (const r of results) byFile[r.split(":")[0]] = (byFile[r.split(":")[0]] || 0) + 1;
console.log(Object.entries(byFile).sort((a, b) => b[1] - a[1]).slice(0, 15).map(([k, v]) => `${v} ${k}`).join("\n"));
fs.writeFileSync("D:/Dead-Drop/Dead-Drop/tools/.magic-candidates.txt", results.join("\n"));
