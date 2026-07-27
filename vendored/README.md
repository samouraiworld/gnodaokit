# `vendored/` — the pinned dependency closure

`gno lint` and `gno test` do **not** resolve dependencies from a lockfile. They derive the source
from the pkgpath domain (`rpcpkgfetcher.go`: `https://rpc.%s:443`), and `rpc.gno.land` CNAMEs to
betanet — a **mutable testnet**. So a hermetically pinned compiler was being fed by a live,
unversioned dependency source, and any upstream redeploy retroactively broke every branch, including
already-merged history.

That is why CI went red on 2026-06-04 and stayed red. Two independent failure classes:

1. **Syntax skew** — the chain serves *pre*-interrealm-v2 sources, i.e. the deps are **older** than
   the pinned compiler. Bumping `GNOVERSION` moves *further* away, not closer.
2. **Packages simply gone** — `r/demo/profile` returns a server-side "package is not available". The
   failed fetch leaves the cache directory uncreated, which then resurfaces as a *misleading*
   `open …/p/onbloc/json: no such file or directory` — a masked download failure, not cache
   corruption.

Vendoring removes the network from the build, which is the only thing that closes both classes.
`load.go` short-circuits the fetch on any workspace-local match.

## Placement is load-bearing

This directory sits at the **repository root**, deliberately not under `gno/`. `make lint`, `make
test` and `make fmt` all target `./gno/...`, so vendored third-party code is resolved but never
linted, tested or reformatted. Moving it under `gno/` would pull every vendored package into those
targets.

## Provenance

Every file except this directory's own `README.md`, `NOTICE` and `LICENSE.md` is copied
**byte-for-byte** from `examples/` in `gnolang/gno` at the `GNOVERSION` pinned in the `Makefile`, so
the dependencies are version-matched to the compiler by construction. CI re-checks this on every run
(`vendored-provenance`), so the two cannot drift apart silently.

There are no source exemptions. Every vendored `.gno` file has an upstream counterpart the job
compares it against, in both directions, so nothing can be added, edited or deleted here without the
comparison seeing it.

### The avl `Get` shape

topaz-1's stdlib `p/nt/avl/v0` exposes a **single-value** `Get`, which is the form this codebase
calls. A key that is absent reads back as `nil`, so the type assertion that follows every lookup
distinguishes absent from present in one step:

```go
roleData, ok := m.Roles.Get(role).(*Role)
if !ok {
    // absent, or not a *Role
}
```

This used to be a vendored fork of avl carrying a two-value `Get`, which had to be exempted from the
byte-comparison above and guarded separately. Calling the chain's own shape removes the fork, the
exemption and both guards.

### `GNOVERSION` is topaz-1's own ref

`GNOVERSION` is `fc4052651`, which is what topaz-1 runs. The vendored tree is therefore
version-matched to the compiler **and** to the chain at the same time, so a green build here does
correspond to what `AddPackage` will see — for the stdlib dependencies. It still says nothing about
`p/samcrew/piechart`, which no chain hosts until the ceremony publishes it (see Sequencing).

It was not always so. The pin used to be `2c7f1abe`, six weeks older, and roughly 15 vendored
packages differed from what the chain hosted — **including `p/nt/avl/v0`, whose on-chain `Get` is
single-value while the vendored copy at that ref was two-value.** A green build genuinely did not
prove publishability, and the gap was held open only by a narrow argument about which symbols
gnodaokit actually touched. Two concrete costs, both paid: the old toolchain had **no sub-realm
support at all** — `cur.Sub()` failed preprocessing — so nothing could test the semantics the
identity work reasons about; and the divergence had to be re-argued by hand on every change.

There is one avl in the tree now, so `svg.Canvas.Style` being a `*nt/avl/v0.Tree` needs no aliasing
at the boundary in `gno/p/basedao/utils.gno`.

Bumping `GNOVERSION` again re-opens all of this. Whoever does it must re-run the regeneration below
and re-check that the new ref is still what the target chain runs.

### Sequencing

Every dependency gnodaokit imports is now a package topaz-1 already hosts, so a green build here
corresponds to what `AddPackage` will see with no prior dependency-publishing step.

## Regenerating

```sh
GNOVERSION=$(sed -n '1s/GNOVERSION=//p' Makefile)
git clone https://github.com/gnolang/gno /tmp/gno && git -C /tmp/gno checkout "$GNOVERSION"
# copy each package listed below from /tmp/gno/examples/<pkgpath> to vendored/<pkgpath>
```

Add a package when the build reports `gno: downloading <path>`; the CI hermeticity guard fails the
build if any such line appears, so the closure cannot silently become incomplete.
