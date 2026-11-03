import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

if (process.argv.length !== 3) throw new Error('usage: node run-wasm.mjs REGEX_WASM');
const { instance } = await WebAssembly.instantiate(await readFile(process.argv[2]), {});
assert.equal(typeof instance.exports.regexAcceptance, 'function');
assert.equal(instance.exports.regexAcceptance(), 0, 'Wasm public API acceptance failed');
process.stdout.write('Wasm public API acceptance passed\n');
