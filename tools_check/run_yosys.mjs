// yowasp-yosys runner.
//   node run_yosys.mjs "<yosys -p script>" file1.v file2.v ...
// Files are loaded into the WASM virtual FS under their basename, so the
// yosys script must refer to them by basename.  Globs are NOT expanded
// inside -p, so always list files explicitly.
import { runYosys } from '@yowasp/yosys';
import { readFileSync } from 'node:fs';

const [, , script, ...paths] = process.argv;
if (!script) {
  console.error('usage: node run_yosys.mjs "<yosys script>" [files...]');
  process.exit(2);
}

const files = {};
for (const p of paths) {
  const base = p.split('/').pop();
  files[base] = new Uint8Array(readFileSync(p));
}

let out = '';
let err = '';
const sink = (target) => (data) => {
  const buf = data instanceof Uint8Array ? Buffer.from(data) : Buffer.from(String(data));
  if (target === 'out') out += buf.toString('utf8');
  else err += buf.toString('utf8');
};

let status = 0;
try {
  await runYosys(['-p', script], files, { stdout: sink('out'), stderr: sink('err') });
} catch (e) {
  status = 1;
  err += `\n[yosys exited non-zero: ${e}]\n`;
}

// Strip ANSI colour codes so logs are readable / greppable.
const strip = (s) => s.replace(/\x1b\[[0-9;]*m/g, '').replace(/\x1b\[\d*[A-Za-z]/g, '');
process.stdout.write(strip(out));
if (err.trim()) process.stderr.write(strip(err));
process.exit(status);
