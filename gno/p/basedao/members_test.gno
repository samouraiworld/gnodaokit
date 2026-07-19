package basedao

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
)

// An empty member id is what CallerID resolves to when it cannot name the
// caller, so storing one would let unidentified callers pass the member gate.
func TestAddMemberRejectsEmptyID(cur realm, t *testing.T) {
	store := NewMembersStore(nil, nil)

	urequire.PanicsWithMessage(t, cur, "member id must not be empty", func() {
		store.AddMember("", nil)
	})
	urequire.False(t, store.IsMember(""), "empty id must not be stored")
	urequire.Equal(t, uint64(0), store.MembersCount())
}

func TestNewMembersStoreRejectsEmptyInitialMember(cur realm, t *testing.T) {
	urequire.PanicsWithMessage(t, cur, "member id must not be empty", func() {
		NewMembersStore(nil, []Member{{Address: "", Roles: []string{}}})
	})
}

func TestAddMemberAcceptsNonEmptyID(cur realm, t *testing.T) {
	store := NewMembersStore(nil, nil)

	urequire.NotPanics(t, cur, func() {
		store.AddMember(alice.String(), nil)
	})
	urequire.True(t, store.IsMember(alice.String()))
}
