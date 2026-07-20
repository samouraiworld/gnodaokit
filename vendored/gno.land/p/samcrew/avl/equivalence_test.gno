package avl

// Equivalence suite for the vendored avl (AVL_OPTION_A_VENDORING_SPEC §3.2).
//
// The vendored module is byte-identical to gno.land/p/nt/avl/v0 @ f3d5a5d13
// except for the module/import paths, so "equivalence vs the stdlib avl" is
// proven by pinning the OBSERVABLE CONTRACT here and running the IDENTICAL
// suite at both the pre-avl pin (f3d5a5d13, CI) and the mainnet-candidate ref
// (67a0bb333, local Topaz toolchain until the flag-day re-pin) — a behavior
// drift introduced by either VM would fail one leg. A literal side-by-side
// import of p/nt/avl/v0 cannot compile at both refs (its Get is two-value at
// the pin and single-value after #5314), hence the reference-model form.
//
// Frozen contract under test (the whole point of Option A):
//   Get(key)    -> (value any, exists bool)   hit: (val, true) · miss: (nil, false)
//   Set(k, v)   -> updated bool
//   Remove(key) -> (value any, removed bool)
//   Iterate / ReverseIterate / Size / Has / GetByIndex unchanged.

import (
	"sort"
	"strconv"
	"testing"
)

// TestGetTwoValueContract pins the exact two-value Get semantics ~407 Memba
// call sites rely on, including the nil-VALUE-vs-miss distinction (the
// custody-oracle nil-vs-zero trap: a stored nil must read back (nil, true)).
func TestGetTwoValueContract(t *testing.T) {
	tree := NewTree()

	// Miss on empty tree.
	if v, ok := tree.Get("absent"); v != nil || ok {
		t.Fatalf("empty-tree Get: want (nil,false), got (%v,%t)", v, ok)
	}

	// Hit returns (val, true).
	tree.Set("k", 42)
	if v, ok := tree.Get("k"); v != 42 || !ok {
		t.Fatalf("hit Get: want (42,true), got (%v,%t)", v, ok)
	}

	// A stored nil VALUE is a hit: (nil, true) — distinct from a miss.
	tree.Set("nilval", nil)
	if v, ok := tree.Get("nilval"); v != nil || !ok {
		t.Fatalf("nil-value Get: want (nil,true), got (%v,%t)", v, ok)
	}

	// Miss after Remove reverts to (nil, false).
	tree.Remove("k")
	if v, ok := tree.Get("k"); v != nil || ok {
		t.Fatalf("post-Remove Get: want (nil,false), got (%v,%t)", v, ok)
	}
}

// TestSetRemoveContract pins Set's updated flag and Remove's two-value form.
func TestSetRemoveContract(t *testing.T) {
	tree := NewTree()

	if updated := tree.Set("a", 1); updated {
		t.Fatal("Set on new key: want updated=false")
	}
	if updated := tree.Set("a", 2); !updated {
		t.Fatal("Set on existing key: want updated=true")
	}
	if v, removed := tree.Remove("a"); v != 2 || !removed {
		t.Fatalf("Remove hit: want (2,true), got (%v,%t)", v, removed)
	}
	if v, removed := tree.Remove("a"); v != nil || removed {
		t.Fatalf("Remove miss: want (nil,false), got (%v,%t)", v, removed)
	}
	if s := tree.Size(); s != 0 {
		t.Fatalf("Size after remove: want 0, got %d", s)
	}
}

// lcg is a deterministic linear congruential generator (Numerical Recipes
// constants) so the fuzz sequence is bit-identical on every run and ref.
type lcg struct{ state uint64 }

func (r *lcg) next() uint64 {
	r.state = r.state*6364136223846793005 + 1442695040888963407
	return r.state
}

// TestFuzzEquivalenceVsModel drives a deterministic randomized op sequence
// against the tree and a map+sorted-keys reference model, checking every op
// result and periodically the full in-order state.
func TestFuzzEquivalenceVsModel(t *testing.T) {
	const (
		ops        = 4000
		keySpace   = 157 // forces plenty of hit/miss/update/rebalance traffic
		checkEvery = 500
	)

	tree := NewTree()
	model := make(map[string]any)
	rng := &lcg{state: 20260717}

	fullCompare := func(step int) {
		if got, want := tree.Size(), len(model); got != want {
			t.Fatalf("step %d: Size=%d, model=%d", step, got, want)
		}
		keys := []string{}
		for k := range model {
			keys = append(keys, k)
		}
		sort.Strings(keys)

		// Per-key two-value Get equivalence.
		for _, k := range keys {
			v, ok := tree.Get(k)
			if !ok || v != model[k] {
				t.Fatalf("step %d: Get(%s): want (%v,true), got (%v,%t)", step, k, model[k], v, ok)
			}
		}

		// Full in-order traversal: order and values must match the model.
		i := 0
		tree.Iterate("", "", func(k string, v any) bool {
			if i >= len(keys) {
				t.Fatalf("step %d: Iterate yielded more than %d entries", step, len(keys))
			}
			if k != keys[i] || v != model[keys[i]] {
				t.Fatalf("step %d: Iterate[%d]: want (%s,%v), got (%s,%v)", step, i, keys[i], model[keys[i]], k, v)
			}
			i++
			return false
		})
		if i != len(keys) {
			t.Fatalf("step %d: Iterate yielded %d entries, want %d", step, i, len(keys))
		}

		// Reverse traversal mirrors the sorted order.
		j := len(keys) - 1
		tree.ReverseIterate("", "", func(k string, v any) bool {
			if j < 0 {
				t.Fatalf("step %d: ReverseIterate yielded too many entries", step)
			}
			if k != keys[j] {
				t.Fatalf("step %d: ReverseIterate: want %s, got %s", step, keys[j], k)
			}
			j--
			return false
		})
		if j != -1 {
			t.Fatalf("step %d: ReverseIterate incomplete (j=%d)", step, j)
		}

		// GetByIndex agrees with the sorted model.
		for idx, k := range keys {
			gk, gv := tree.GetByIndex(idx)
			if gk != k || gv != model[k] {
				t.Fatalf("step %d: GetByIndex(%d): want (%s,%v), got (%s,%v)", step, idx, k, model[k], gk, gv)
			}
		}
	}

	for op := 1; op <= ops; op++ {
		k := "k" + strconv.Itoa(int(rng.next()%keySpace))
		switch rng.next() % 4 {
		case 0, 1: // Set (50%)
			val := int(rng.next() % 1000)
			_, existed := model[k]
			if updated := tree.Set(k, val); updated != existed {
				t.Fatalf("op %d: Set(%s) updated=%t, model existed=%t", op, k, updated, existed)
			}
			model[k] = val
		case 2: // Remove (25%)
			want, existed := model[k]
			v, removed := tree.Remove(k)
			if removed != existed {
				t.Fatalf("op %d: Remove(%s) removed=%t, model existed=%t", op, k, removed, existed)
			}
			if existed && v != want {
				t.Fatalf("op %d: Remove(%s) value=%v, model=%v", op, k, v, want)
			}
			if !existed && v != nil {
				t.Fatalf("op %d: Remove(%s) miss returned value %v, want nil", op, k, v)
			}
			delete(model, k)
		default: // Get + Has (25%)
			want, existed := model[k]
			v, ok := tree.Get(k)
			if ok != existed {
				t.Fatalf("op %d: Get(%s) exists=%t, model=%t", op, k, ok, existed)
			}
			if existed && v != want {
				t.Fatalf("op %d: Get(%s) value=%v, model=%v", op, k, v, want)
			}
			if !existed && v != nil {
				t.Fatalf("op %d: Get(%s) miss returned value %v, want nil", op, k, v)
			}
			if tree.Has(k) != existed {
				t.Fatalf("op %d: Has(%s) != model %t", op, k, existed)
			}
		}
		if op%checkEvery == 0 {
			fullCompare(op)
		}
	}
	fullCompare(ops)

	// Iterate early-stop contract: returning true halts the walk.
	seen := 0
	tree.Iterate("", "", func(k string, v any) bool {
		seen++
		return seen == 3
	})
	if tree.Size() >= 3 && seen != 3 {
		t.Fatalf("Iterate early-stop: want 3 callbacks, got %d", seen)
	}
}
