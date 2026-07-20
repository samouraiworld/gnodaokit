package basedao

import (
	"testing"

	"gno.land/p/nt/testutils/v0"
	"gno.land/p/nt/urequire/v0"
)

// Removing the final member drops MembersCount to zero, which is an
// unrecoverable state: every DAO entry point first calls assertCallerIsMember,
// so nothing — including AddMember — can ever be proposed again, and every
// threshold evaluates 0/0 = NaN, which is never >= any threshold. Since
// publishing is immutable, such a DAO is bricked forever.
func TestRemoveMemberRejectsRemovingLastMember(cur realm, t *testing.T) {
	solo := testutils.TestAddress("solo").String()
	store := NewMembersStore(nil, []Member{{Address: solo}})

	urequire.PanicsWithMessage(t, cur, "cannot remove the last member", func() {
		store.RemoveMember(solo)
	})
	urequire.Equal(t, uint64(1), store.MembersCount())
}

// The guard must not block ordinary removals.
func TestRemoveMemberAllowsRemovalWhenOthersRemain(cur realm, t *testing.T) {
	first := testutils.TestAddress("first").String()
	second := testutils.TestAddress("second").String()
	store := NewMembersStore(nil, []Member{{Address: first}, {Address: second}})

	urequire.NotPanics(t, cur, func() {
		store.RemoveMember(first)
	})
	urequire.Equal(t, uint64(1), store.MembersCount())
}
