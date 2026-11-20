// Detect require cycles among modules reached through script.Parent... requires (server and client).
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
const graph = new Map();
for (const f of files) {
	const src = fs.readFileSync(f, "utf8").replace(/--[^\n]*/g, "");
	const deps = [];
	for (const m of src.matchAll(/require\(\s*script((?:\.Parent)*)((?:\.[A-Za-z0-9_]+)+)\s*\)/g)) {
		const ups = (m[1].match(/\.Parent/g) || []).length;
		let dir = path.dirname(f);
		for (let i = 1; i < ups; i++) dir = path.dirname(dir);
		const parts = m[2].split(".").filter(Boolean);
		let p = dir;
		for (let i = 0; i < parts.length - 1; i++) p = path.join(p, parts[i]);
		const target = path.join(p, parts[parts.length - 1] + ".luau");
		if (fs.existsSync(target)) deps.push(path.resolve(target));
	}
	graph.set(path.resolve(f), deps);
}
const state = new Map();
const stack = [];
let found = 0;
function dfs(n) {
	state.set(n, 1);
	stack.push(n);
	for (const d of graph.get(n) || []) {
		if (state.get(d) === 1) {
			const cycle = stack.slice(stack.indexOf(d)).concat(d).map((x) => path.basename(x, ".luau"));
			console.log("CYCLE: " + cycle.join(" -> "));
			found++;
		} else if (!state.has(d)) dfs(d);
	}
	stack.pop();
	state.set(n, 2);
}
for (const n of graph.keys()) if (!state.has(n)) dfs(n);
console.log("modules:", graph.size, "cycles:", found);
