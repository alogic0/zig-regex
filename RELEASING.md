# Source distribution

The package version is in `build.zig.zon`; `.zigversion` pins its compiler.
The library is distributed as source with MIT, provenance and Unicode notices.
There is no compiled native library, package service or runtime download.

## First GitHub upload

Create an empty GitHub repository named `zig-regex`. Leave GitHub's README,
license and gitignore initialization options off; this repository already has
those files. Use this About description:

> Dependency-free regex library for Zig with Unicode support, captures, byte offsets, and explicit allocator ownership.

Suggested topics: `zig`, `regex`, `regular-expressions`, `unicode`, `wasm`.
Set `main` as the default branch. When ready to upload, replace `OWNER` with
your GitHub user or organization, then run:

```sh
git remote add origin git@github.com:OWNER/zig-regex.git
git push -u origin main
```

See [GitHub's existing-repository instructions](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github).
Wait for the CI workflow to pass on GitHub before publishing a release.
The workflow runs on pushes and pull requests with read-only repository
permissions and does not publish releases.

## Version management

The development dependency `zig-package-version` is pinned in
`tools/vendor/zig-package-version/UPSTREAM`, with its MIT license and file
checksums alongside the unmodified source. Use the compiler in `.zigversion`
and run from the repository root:

```sh
zig run tools/package_version.zig -- get
zig run tools/package_version.zig -- set MAJOR.MINOR.PATCH
```

Replace `MAJOR.MINOR.PATCH` with the release version you choose. `versions.zon`
lists the manifest and current README markers, including archive filenames.
`get` verifies that they agree; `set` updates them together. The helper accepts
canonical numeric versions with components up to 65535, without prerelease or
build labels. Review the diff and update the changelog separately; historical
entries and existing release receipts are not rewritten. The tool is vendored
so a checkout or source archive needs no sibling repository or network fetch.

## Prepare and verify

Run the checks in `CONTRIBUTING.md`, review the changelog and commit a clean
tree. On Linux, with Git, Zig and `sha256sum` installed:

```sh
./tools/prepare-release.sh
```

The script archives the exact clean HEAD, with `build.zig.zon` at the archive
root, and writes these files under `zig-out/dist/`:

- `zig-regex-VERSION.tar.gz`: deterministic source archive from `git archive`.
- `SHA256SUMS`: checksum of the exact compressed archive bytes.
- `PACKAGE_INFO.txt`: package version, source revision, compiler and Zig hash.

It rejects compiler drift, inconsistent version markers and dirty
tracked/untracked source. Repeating it at
the same commit must produce the same checksum. Keep an existing release's
artifact unchanged; correct a published defect in a new version.
An optional output-directory argument keeps different releases separate, for
example `./tools/prepare-release.sh zig-out/dist/VERSION`. Repository-only GitHub
and agent metadata is excluded through `.gitattributes`.

Before distributing, extract the archive to an independent directory and repeat
the native/Wasm and `tests/package` checks in Debug and ReleaseSafe. Verify its
licenses and absence of generated caches. The `.github/workflows/ci.yml` package
job performs these checks and retains the three files as a workflow artifact;
see [GitHub's artifact documentation](https://docs.github.com/en/actions/tutorials/store-and-share-data).

Also test the archive as a real dependency, using the hash in its receipt:

```sh
regex_dist=zig-out/dist
regex_archive=$(sed -n 's/^archive=//p' "$regex_dist/PACKAGE_INFO.txt")
regex_hash=$(sed -n 's/^package_hash=//p' "$regex_dist/PACKAGE_INFO.txt")
./tools/check-package.sh "$regex_dist/$regex_archive" "$regex_hash"
REGEX_ZIG_EXE=/absolute/path/to/zig-0.15.2/zig \
  ./tools/check-package.sh "$regex_dist/$regex_archive" "$regex_hash"
```

Set `regex_dist` to your chosen output directory if using a separate one.
The checker copies the package fixture into a temporary directory, replaces
its path dependency with the vendored archive URL and hash, and runs Debug
and ReleaseSafe with separate empty caches. CI runs this check on both
supported compilers. It exercises dependency fetching and the published
module boundary without access to a sibling source checkout.

## Share

For a release, create an annotated `vVERSION` tag at the verified commit and
distribute the three verified files together. Tag, manifest and receipt versions
must agree. Existing version tags must continue to identify their original
commits. Prepare fresh artifacts from the final commit and create a new tag
when ready to publish:

```sh
regex_version=$(zig run tools/package_version.zig -- get)
git tag -a "v$regex_version" -m "zig-regex $regex_version"
git push origin tag "v$regex_version"
```

After CI passes for that tag, create a GitHub release targeting it, copy the
corresponding changelog entry into the release notes and attach the three
verified distribution files. The uploaded archive is the one described by
`SHA256SUMS` and `PACKAGE_INFO.txt`; GitHub's automatically generated source
downloads are separate artifacts. Preparation and CI do not create a remote,
push a tag or publish a release.

Recipients can verify `sha256sum --check SHA256SUMS`, copy the archive into their
own `vendor/` directory and run `zig fetch vendor/zig-regex-VERSION.tar.gz`.
Compare the printed hash with `PACKAGE_INFO.txt`, then follow `README.md` to add
the manifest's relative `file:` URL and verified hash. The fetch command takes a
filesystem path; direct relative `file:` fetch handling differs between the
qualified compilers. Verify the actual consumer build with an empty global
cache, then commit the archive and manifest together. A hosted URL may
replace the `file:` URL once those exact bytes are available at an immutable
location. The Zig hash remains the same for the same admitted package files.

Changing packaging docs or build files changes the Zig hash even when matching
code is identical. Consumer pins must be tested explicitly; dependency tests do
not automatically run in consumer test roots. Source distribution does not
qualify additional compiler versions, platforms or application-specific regex
profiles.
