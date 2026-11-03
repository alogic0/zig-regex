# Source distribution

The package version is in `build.zig.zon`; `.zigversion` pins its compiler.
The library is distributed as source with MIT, provenance and Unicode notices.
There is no compiled native library, package service or runtime download.

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

It rejects compiler drift and dirty tracked/untracked source. Repeating it at
the same commit must produce the same checksum. Keep an existing release's
artifact unchanged; correct a published defect in a new version.

Before distributing, extract the archive to an independent directory and repeat
the native/Wasm and `tests/package` checks in Debug and ReleaseSafe. Verify its
licenses and absence of generated caches. The `.github/workflows/ci.yml` package
job performs these checks and retains the three files as a workflow artifact;
see [GitHub's artifact documentation](https://docs.github.com/en/actions/tutorials/store-and-share-data).

## Share

For a release, create an annotated `vVERSION` tag at the verified commit and
distribute the three verified files together. Tag, manifest and receipt versions
must agree. A GitHub repository/remote and public release can be selected later;
preparation and CI do not create a remote, push a tag or publish a release.

Recipients can verify `sha256sum --check SHA256SUMS`, copy the archive into their
own `vendor/` directory and run the `zig fetch --save-exact=regex file:vendor/...`
command in `README.md`. They should compare the generated package hash with
`PACKAGE_INFO.txt` and commit the archive and manifest together. A hosted URL may
replace the `file:` URL once those exact bytes are available at an immutable
location. The Zig hash remains the same for the same admitted package files.

Changing packaging docs or build files changes the Zig hash even when matching
code is identical. Consumer pins must be tested explicitly; dependency tests do
not automatically run in consumer test roots. Source distribution does not
qualify additional compiler versions, platforms or application-specific regex
profiles.
