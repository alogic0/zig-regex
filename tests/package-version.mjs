import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

if (process.argv.length !== 3) throw new Error('usage: node package-version.mjs UPDATER_BINARY');
const binary = resolve(process.argv[2]);
const repository = fileURLToPath(new URL('../', import.meta.url));
const files = ['versions.zon', 'build.zig.zon', 'README.md', 'CHANGELOG.md', 'RELEASING.md'];
const originals = new Map(await Promise.all(files.map(async (name) => [name, await readFile(join(repository, name), 'utf8')])));
const directory = await mkdtemp(join(tmpdir(), 'zig-regex-version-'));

// All setters run on disposable copies; the source checkout is read-only.
try {
  await Promise.all(files.map((name) => writeFile(join(directory, name), originals.get(name))));
  const run = (args) => {
    const result = spawnSync(binary, args, { cwd: directory, encoding: 'utf8', timeout: 10_000, maxBuffer: 1024 * 1024 });
    assert.ifError(result.error);
    return result;
  };
  const get = run(['get']);
  assert.equal(get.status, 0, get.stderr);
  const current = get.stdout.trim();
  const next = current === '7.8.9' ? '7.8.10' : '7.8.9';
  const historical = `\nHistorical fixture version: ${current}\n`;
  await writeFile(join(directory, 'README.md'), originals.get('README.md') + historical);

  const set = run(['set', next]);
  assert.equal(set.status, 0, set.stderr);
  const updated = run(['get']);
  assert.equal(updated.status, 0, updated.stderr);
  assert.equal(updated.stdout.trim(), next);
  const expectedManifest = originals.get('build.zig.zon').replace(`.version = "${current}"`, `.version = "${next}"`);
  const expectedReadme = originals.get('README.md')
    .replace(`Version **${current}**`, `Version **${next}**`)
    .replaceAll(`zig-regex-${current}.tar.gz`, `zig-regex-${next}.tar.gz`) + historical;
  assert.equal(await readFile(join(directory, 'build.zig.zon'), 'utf8'), expectedManifest);
  assert.equal(await readFile(join(directory, 'README.md'), 'utf8'), expectedReadme);
  for (const name of ['versions.zon', 'CHANGELOG.md', 'RELEASING.md']) {
    assert.equal(await readFile(join(directory, name), 'utf8'), originals.get(name), `${name} must stay unchanged`);
  }

  // A stale README must block the same get command used by release preparation.
  await writeFile(join(directory, 'README.md'), expectedReadme.replace(`Version **${next}**`, `Version **${current}**`));
  const mismatch = run(['get']);
  assert.equal(mismatch.status, 1);
  assert.match(mismatch.stderr, /README\.md/);
  const repair = run(['set', next]);
  assert.equal(repair.status, 0, repair.stderr);
  assert.equal(await readFile(join(directory, 'README.md'), 'utf8'), expectedReadme);
  process.stdout.write('Version markers, archive names, history preservation and drift checks passed\n');
} finally {
  await rm(directory, { recursive: true, force: true });
}
