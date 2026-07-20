# realm_id: Realm and User Identification Utilities

`realmid` provides simple functions to identify callers in the Gno ecosystem - whether they're users or packages.

## Functions

```go
// Get the previous caller (user address or package path)
func Previous() string

// Get the current realm identifier  
func Current() string

// Check if an ID is a package path (contains dots)
func IsPackage(id string) bool

// Check if an ID is a user address (no dots)
func IsUser(id string) bool
```

> ## ⚠️ Not for caller authentication
>
> `Previous` and `Current` are built on `chain/runtime/unsafe`, which stack-walks.
> Read from a non-crossing helper — which is what a `/p/` package is — the walk
> reports whichever realm is outermost-crossing on the stack, so when a caller
> invokes your package's methods directly there is no frame of *your* realm at all
> and the walk names the signing account instead.
>
> For caller identity, thread a `realm` from a crossing function and use
> `cur.Previous()`, which is statically scoped to that function. `basedao` does
> exactly this and no longer uses this package. Only `IsPackage` / `IsUser`, which
> are pure string predicates, are safe to reach for unconditionally.

## Basic Usage

```go
import "gno.land/p/samcrew/realmid"

// The caller identity comes from a threaded realm, not from a stack walk.
// realmid classifies it.
func MyFunction(cur realm) {
    prev := cur.Previous()
    caller := prev.PkgPath()
    if prev.IsUser() {
        caller = prev.Address().String()
    }

    if realmid.IsUser(caller) {
        // caller is a user address like "g1abc123..."
        println("Called by user:", caller)
    } else {
        // caller is a package path like "gno.land/r/demo/users"
        println("Called by realm:", caller)
    }
}
```

## Integration with basedao

`basedao.CallerIDFn` receives the DAO's own realm, so an implementation derives
the identity from it rather than walking the stack:

```go
config := &basedao.Config{
    Name: "My DAO",
    CallerID: func(dao *basedao.DAOPrivate, rlm realm) string {
        prev := rlm.Previous()
        if prev.IsUser() {
            return prev.Address().String()
        }
        return prev.PkgPath()
    },
    // ...
}
```

Leaving `CallerID` nil installs exactly this behaviour, so most DAOs should not
set it at all.