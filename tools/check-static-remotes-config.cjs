// Static cross-checks: remote names against Remotes.luau, and GameConfig key paths against GameConfig.luau.
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
const remotesSrc = fs.readFileSync(root + "/shared/Remotes.luau", "utf8");
function list(name) {
	const m = remotesSrc.match(new RegExp(name + " = \\{([\\s\\S]*?)\\n\\t\\},"));
	return new Set([...(m ? m[1] : "").matchAll(/"([A-Za-z]+)"/g)].map((x) => x[1]));
}
const s2c = list("ServerToClient"), c2s = list("ClientToServer"), fn = list("ClientToServerFunctions");
console.log("remotes:", s2c.size, "server->client,", c2s.size, "client->server,", fn.size, "functions");

let problems = 0;
for (const f of files) {
	const src = fs.readFileSync(f, "utf8");
	const rel = f.replace(root + "/", "");
	const isClient = rel.startsWith("client/");
	for (const m of src.matchAll(/\b(?:RemoteController|Remote|Remotes)\.(connect|fire|invoke)\(\s*"([A-Za-z]+)"/g)) {
		const [, kind, name] = m;
		const ok = kind === "connect" ? s2c.has(name) : kind === "fire" ? c2s.has(name) : fn.has(name);
		if (!ok) { console.log(`REMOTE ${rel}: ${kind}("${name}") not in the matching list`); problems++; }
	}
	for (const m of src.matchAll(/RemoteService\.(onRequest|onInvoke|fireClient|fireClients|fireAllClients)\(\s*"([A-Za-z]+)"/g)) {
		const [, kind, name] = m;
		const ok = kind === "onRequest" ? c2s.has(name) : kind === "onInvoke" ? fn.has(name) : s2c.has(name);
		if (!ok) { console.log(`REMOTE ${rel}: RemoteService.${kind}("${name}") not in the matching list`); problems++; }
	}
}

// GameConfig key paths. Build a nested key tree by walking the file with a brace-depth parser.
const cfgSrc = fs.readFileSync(root + "/shared/GameConfig.luau", "utf8");
function parseTable(src, start) {
	// returns {keys: Map(name -> subtree|null), end}
	const keys = new Map();
	let i = start;
	let depth = 0;
	let line = "";
	const body = [];
	// naive: scan tokens at depth 1 for `Name = ` or `Name = {`
	let pos = start; // position just after '{'
	let d = 1;
	let s = pos;
	let inStr = null;
	let atLineStart = true;
	for (; pos < src.length && d > 0; pos++) {
		const c = src[pos];
		if (inStr) { if (c === "\\") pos++; else if (c === inStr) inStr = null; continue; }
		if (c === '"' || c === "'") { inStr = c; continue; }
		if (c === "-" && src[pos + 1] === "-") { while (pos < src.length && src[pos] !== "\n") pos++; continue; }
		if (c === "{" || c === "(") { d++; continue; }
		if (c === "}" || c === ")") { d--; continue; }
		if (d === 1) {
			const m = /^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(\{)?/.exec(src.slice(pos, pos + 120));
			if (m && (pos === 0 || /[\s,{]/.test(src[pos - 1]))) {
				const name = m[1];
				if (m[2]) {
					const inner = parseTable(src, pos + m[0].length);
					keys.set(name, inner.keys);
					pos = inner.end;
				} else {
					keys.set(name, null);
					pos += m[0].length - 1;
				}
			}
		}
	}
	return { keys, end: pos - 1 };
}
const startIdx = cfgSrc.indexOf("local GameConfig = {");
const tree = parseTable(cfgSrc, cfgSrc.indexOf("{", startIdx) + 1).keys;
console.log("GameConfig sections:", tree.size);

function has(pathParts) {
	let node = tree;
	for (const p of pathParts) {
		if (!(node instanceof Map)) return true; // value, deeper access unknowable
		if (!node.has(p)) return false;
		node = node.get(p);
	}
	return true;
}
for (const f of files) {
	if (f.endsWith("GameConfig.luau")) continue;
	const src = fs.readFileSync(f, "utf8");
	const rel = f.replace(root + "/", "");
	// direct paths
	for (const m of src.matchAll(/\bGameConfig\.([A-Za-z]+)((?:\.[A-Za-z][A-Za-z0-9]*){0,2})/g)) {
		const parts = [m[1], ...m[2].split(".").filter(Boolean)];
		if (!has(parts)) { console.log(`CONFIG ${rel}: GameConfig.${parts.join(".")} is not defined`); problems++; }
	}
	// aliases: local config = GameConfig.A.B  then config.Key
	for (const a of src.matchAll(/\blocal ([A-Za-z]+) = GameConfig\.([A-Za-z]+)((?:\.[A-Za-z][A-Za-z0-9]*)*)\s*(?:--.*)?\n/g)) {
		const alias = a[1];
		const base = [a[2], ...a[3].split(".").filter(Boolean)];
		if (!has(base)) continue;
		const re = new RegExp("\\b" + alias + "\\.([A-Za-z][A-Za-z0-9]*)", "g");
		for (const u of src.matchAll(re)) {
			if (!has([...base, u[1]])) { console.log(`CONFIG ${rel}: ${alias}.${u[1]} (GameConfig.${base.join(".")}.${u[1]}) is not defined`); problems++; }
		}
	}
}
console.log("problems:", problems);
