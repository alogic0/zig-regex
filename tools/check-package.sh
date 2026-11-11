#!/bin/sh
# Exercise an archive dependency without a sibling checkout or a warm cache.
set -eu

if [ "$#" -ne 2 ]; then
    printf '%s\n' 'usage: tools/check-package.sh ARCHIVE PACKAGE_HASH' >&2
    exit 2
fi
regex_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
regex_archive=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
regex_expected_hash=$2
regex_zig_exe=$(command -v "${REGEX_ZIG_EXE:-zig}")
case "$regex_zig_exe" in
    /*) ;;
    *) regex_zig_exe=$(pwd)/$regex_zig_exe ;;
esac
if [ ! -f "$regex_archive" ]; then
    printf 'archive not found: %s\n' "$regex_archive" >&2
    exit 1
fi

regex_package_hash=$("$regex_zig_exe" fetch "$regex_archive")
if [ "$regex_package_hash" != "$regex_expected_hash" ]; then
    printf '%s\n' 'archive package hash does not match the release receipt' >&2
    exit 1
fi

regex_work_dir=$(mktemp -d "${TMPDIR:-/tmp}/zig-regex-package.XXXXXX")
trap 'rm -rf -- "$regex_work_dir"' EXIT
trap 'exit 1' HUP INT TERM
for regex_optimize in Debug ReleaseSafe; do
    regex_consumer_dir="$regex_work_dir/$regex_optimize"
    mkdir -p "$regex_consumer_dir/vendor"
    cp "$regex_repo_dir/tests/package/build.zig" "$regex_repo_dir/tests/package/main.zig" \
        "$regex_consumer_dir/"
    cp "$regex_archive" "$regex_consumer_dir/vendor/regex.tar.gz"
    sed "s|\.path = \"\.\./\.\.\"|.url = \"file:vendor/regex.tar.gz\", .hash = \"$regex_package_hash\"|" \
        "$regex_repo_dir/tests/package/build.zig.zon" > "$regex_consumer_dir/build.zig.zon"
    (
        cd "$regex_consumer_dir"
        ZIG_GLOBAL_CACHE_DIR="$regex_consumer_dir/global-cache" \
            ZIG_LOCAL_CACHE_DIR="$regex_consumer_dir/local-cache" \
            ZIG_LOCAL_PKG_DIR="$regex_consumer_dir/pkg" \
            "$regex_zig_exe" build test -Doptimize="$regex_optimize" --summary all
    )
done
printf 'Archive consumer passed with Zig %s in Debug and ReleaseSafe\n' "$("$regex_zig_exe" version)"
