package basedao

import (
	"testing"

	"gno.land/p/samcrew/avl"

	"gno.land/p/nt/urequire/v0"
)

// The empty-id guard, on controlled input.
//
// It is asserted here rather than through a realm fixture because "" is a
// property of the input, not of the environment: under `gno test` the harness
// leaves OriginCaller unset, so a root-of-chain call happens to resolve to ""
// there while on-chain it resolves to the signing account. A test that inferred
// the empty id from the environment would be pinning the harness.
//
// The guard is load-bearing rather than cosmetic. MembersStore.Members is an
// exported avl.Tree, so a same-realm write or a MigrateFn can seed "" past
// AddMember — and any call the machine cannot attribute to a signer resolves to
// "". Without this, one such entry would authenticate all of them.
func TestAnEmptyCallerIdIsNeverAMember(cur realm, t *testing.T) {
	store := NewMembersStore(nil, []Member{{alice.String(), nil}})
	d := &DAOPrivate{Members: store}

	urequire.PanicsWithMessage(t, cur, "caller id is empty", func() {
		d.assertCallerIsMember("")
	})
}

// Even with "" seeded directly into the store, past AddMember.
func TestAnEmptyCallerIdIsRefusedEvenWhenSeededIntoTheStore(cur realm, t *testing.T) {
	store := NewMembersStore(nil, []Member{{alice.String(), nil}})
	store.Members.Set("", avl.NewTree())
	d := &DAOPrivate{Members: store}

	urequire.True(t, store.IsMember(""), "the store does hold the empty id")
	urequire.PanicsWithMessage(t, cur, "caller id is empty", func() {
		d.assertCallerIsMember("")
	})
}

// A real member still passes, so the guard discriminates.
func TestARealCallerIdIsAccepted(cur realm, t *testing.T) {
	store := NewMembersStore(nil, []Member{{alice.String(), nil}})
	d := &DAOPrivate{Members: store}

	urequire.Equal(t, alice.String(), d.assertCallerIsMember(alice.String()))
}
