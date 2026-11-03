#!/bin/sh
# Prepare a source snapshot of one clean commit; publication is separate.
set -eu

if [ "$#" -gt 1 ]; then
    printf '%s\n' 'usage: tools/prepare-release.sh [OUTPUT_DIRECTORY]' >&2
    exit 2
fi
regex_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$regex_repo_dir"
regex_zig_exe=${REGEX_ZIG_EXE:-zig}
regex_zig_version=$(cat .zigversion)
if [ "$("$regex_zig_exe" version)" != "$regex_zig_version" ]; then
    printf 'release preparation requires Zig %s\n' "$regex_zig_version" >&2
    exit 1
fi
if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
    printf '%s\n' 'release preparation requires a clean Git checkout' >&2
    exit 1
fi
regex_version=$(sed -n 's/^    \.version = "\([^"]*\)",$/\1/p' build.zig.zon)
case "$regex_version" in
    ''|*[!0-9A-Za-z.+-]*)
        printf '%s\n' 'cannot read package version from build.zig.zon' >&2
        exit 1 ;;
esac
regex_revision=$(git rev-parse --verify HEAD)
regex_output_dir=${1:-zig-out/dist}
mkdir -p -- "$regex_output_dir"
regex_output_dir=$(CDPATH= cd -- "$regex_output_dir" && pwd)
regex_archive_name="zig-regex-${regex_version}.tar.gz"
regex_archive="$regex_output_dir/$regex_archive_name"
# Keep build.zig.zon at the archive root; git records deterministic timestamps.
git archive --format=tar.gz --output="$regex_archive" "$regex_revision"
regex_package_hash=$("$regex_zig_exe" fetch "$regex_archive")
case "$regex_package_hash" in
    "regex-${regex_version}-"*) ;;
    *) printf '%s\n' 'unexpected Zig package identity' >&2; exit 1 ;;
esac
printf 'version=%s\nrevision=%s\nzig=%s\narchive=%s\npackage_hash=%s\n' \
    "$regex_version" "$regex_revision" "$regex_zig_version" "$regex_archive_name" \
    "$regex_package_hash" > "$regex_output_dir/PACKAGE_INFO.txt"
(cd "$regex_output_dir" && sha256sum "$regex_archive_name" > SHA256SUMS)
printf 'Prepared %s\n%s\n' "$regex_archive" "$regex_package_hash"
