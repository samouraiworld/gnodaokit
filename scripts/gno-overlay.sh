#!/usr/bin/env bash
#
# Build a deterministic GNOROOT overlay and run a gno subcommand against it.
#
# gnodaokit tracks bleeding-edge gno master (interrealm v2 / cross(cur)). The
# gno.land chain that `gno lint`/`gno test` download dependencies from lags
# master, so its deployed packages (uassert, onbloc/json, r/demo/profile, ...)
# fail to build under the pinned toolchain and turn CI red even when our code is
# correct. To verify against the exact gno version instead, assemble an overlay
# from that version's stdlibs + examples, inject this repo's packages under their
# on-chain import paths, and resolve every dependency locally via -root-dir.
#
# Usage: GNOVERSION=<commit> scripts/gno-overlay.sh <lint|test> [extra gno args...]

set -euo pipefail

: "${GNOVERSION:?GNOVERSION must be set (the Makefile passes it)}"
sub="${1:?usage: gno-overlay.sh <lint|test> [args...]}"
shift

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
overlay="${OVERLAY:-${root}/gnobuild/overlay/${GNOVERSION}}"
gno=(go run "github.com/gnolang/gno/gnovm/cmd/gno@${GNOVERSION}")

# Resolve the gno module source, downloading and extracting it into the module
# cache if absent. `go mod download` (unlike `go list -m`) guarantees the source
# is extracted on disk, and reports its directory without touching go.mod/go.sum.
moddir="$(go mod download -json "github.com/gnolang/gno@${GNOVERSION}" |
	sed -n 's/.*"Dir": "\(.*\)".*/\1/p')"
if [ -z "${moddir}" ] || [ ! -d "${moddir}/gnovm/stdlibs" ]; then
	echo "gno-overlay: could not resolve gno module source for ${GNOVERSION}" >&2
	exit 1
fi

# Assemble the overlay once per version (stdlibs, test stdlibs, examples). The
# module cache is read-only, so copy then make it writable.
if [ ! -e "${overlay}/.ready" ]; then
	rm -rf "${overlay}"
	mkdir -p "${overlay}/gnovm"
	cp -r "${moddir}/gnovm/stdlibs" "${overlay}/gnovm/stdlibs"
	cp -r "${moddir}/gnovm/tests" "${overlay}/gnovm/tests"
	cp -r "${moddir}/examples" "${overlay}/examples"
	chmod -R u+w "${overlay}"
	touch "${overlay}/.ready"
fi

# (Re)inject this repo's packages under their on-chain import paths so imports
# resolve from the overlay instead of being downloaded from the chain.
gnoland="${overlay}/examples/gno.land"
for pkg in basedao daocond daokit realmid; do
	rm -rf "${gnoland}/p/samcrew/${pkg}"
	cp -r "${root}/gno/p/${pkg}" "${gnoland}/p/samcrew/${pkg}"
done
rm -rf "${gnoland}/r/samcrew/daodemo"
mkdir -p "${gnoland}/r/samcrew/daodemo"
cp -r "${root}/gno/r/daodemo/." "${gnoland}/r/samcrew/daodemo/"
chmod -R u+w "${overlay}"

# Isolated GNOHOME so nothing is ever pulled from the chain: a missing dependency
# fails loudly instead of silently downloading an incompatible version.
export GNOHOME="${overlay}/gnohome"
cd "${overlay}/examples"
exec "${gno[@]}" "${sub}" -root-dir "${overlay}" "$@" \
	./gno.land/p/samcrew/... ./gno.land/r/samcrew/...
