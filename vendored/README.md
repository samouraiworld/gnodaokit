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

Every file except `gno.land/p/samcrew/avl/` is copied **byte-for-byte** from `examples/` in
`gnolang/gno` at the `GNOVERSION` pinned in the `Makefile`, so the dependencies are version-matched
to the compiler by construction. CI re-checks this on every run (`vendored-provenance`), so the two
cannot drift apart silently.

`gno.land/p/samcrew/avl/` is the **fork**, not upstream. It is byte-identical to `deps/avl` in
`samouraiworld/samcrew-deployer`, which carries its own CI guard pinning it to upstream `f3d5a5d13`.

### Why the fork, and why this matters

topaz-1's stdlib `p/nt/avl/v0` exposes a **single-value** `Get`, while this codebase calls the
**two-value** form. Vendoring upstream `p/nt/avl/v0` for the data-structure role would produce a
**green build compiled against an ABI the target chain does not have** — a false green in exactly
the place the gate exists to prevent one. So the fork is vendored for that role.

The one remaining `gno.land/p/nt/avl/v0` import, in `gno/p/basedao/utils.gno`, is deliberate:
`svg.Canvas.Style` is a `*nt/avl/v0.Tree`, so the stdlib ABI must be matched exactly at that
boundary. It only calls `NewTree()`, never `Get`, so it carries no arity exposure.

## Regenerating

```sh
GNOVERSION=$(sed -n '1s/GNOVERSION=//p' Makefile)
git clone https://github.com/gnolang/gno /tmp/gno && git -C /tmp/gno checkout "$GNOVERSION"
# copy each package listed below from /tmp/gno/examples/<pkgpath> to vendored/<pkgpath>
# then restore the fork:
cp -R ../samcrew-deployer/deps/avl vendored/gno.land/p/samcrew/avl
```

Add a package when the build reports `gno: downloading <path>`; the CI hermeticity guard fails the
build if any such line appears, so the closure cannot silently become incomplete.
