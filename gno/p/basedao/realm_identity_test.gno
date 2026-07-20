package basedao

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
	"gno.land/p/samcrew/daokit"
)

func newIdentityTestDAO(cur realm, daoPkgPath string) *DAOPrivate {
	conf := &Config{
		Name:        "Identity DAO",
		Description: "fixture",
		Members: NewMembersStore(
			[]RoleInfo{{Name: "admin", Description: "admin", Color: "#000"}},
			[]Member{{alice.String(), []string{"admin"}}},
		),
		GetProfileString: func(addr address, field, def string) string { return "" },
	}
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewCodeRealm(daoPkgPath))
	_, dao := New(conf, cur)
	return dao
}

// Execute used to take whatever realm its caller handed it, so a third realm
// holding the DAO value could pass its own `cur` and make the DAO perform its
// outbound cross-realm calls under THAT realm's identity — writing to the
// caller's profile, and via MigrateFn reaching any realm the caller controls.
// On the pre-port code this was impossible: the crossing function was declared
// inside the DAO realm, so the identity was bound at construction and callers
// could not reach it.
//
// Realm values are unforgeable, so a foreign realm can only ever pass its own.
// Requiring the realm to be the DAO's own therefore closes the donation path
// completely, without needing to trust the caller.
func TestExecuteRejectsAForeignRealm(cur realm, t *testing.T) {
	dao := newIdentityTestDAO(cur, "gno.land/r/testing/identitydao")

	// Become a different realm, exactly as an attacker realm would be.
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/testing/attacker"))

	urequire.PanicsWithMessage(t, cur,
		"realm mismatch: the DAO may only act as gno.land/r/testing/identitydao",
		func() {
			// Proposal id is irrelevant: the realm check must run before any
			// lookup, so a foreign realm never reaches proposal state at all.
			dao.Execute(0, cur)
		})
}

// The DAO's own realm must still be accepted, or the fix would brick every DAO.
func TestExecuteAcceptsTheDAOsOwnRealm(cur realm, t *testing.T) {
	dao := newIdentityTestDAO(cur, "gno.land/r/testing/identitydao2")

	// cur is the DAO's realm here (SetRealm rebinds it), so the realm gate must
	// pass and execution must fail later, on the missing proposal.
	urequire.PanicsWithMessage(t, cur, "proposal not found", func() {
		dao.Execute(0, cur)
	})
}

// Caller identity used to come from unsafe.PreviousRealm(), which stack-walks to
// the OUTERMOST crossing frame rather than the immediate caller — so in an
// EOA -> intermediary -> DAO chain the DAO saw the EOA, and any member's
// signature routed through an intermediary passed the membership check while
// that intermediary supplied the acting identity.
//
// Identity is now derived from the threaded realm, which is statically scoped to
// the DAO realm's own crossing function and cannot lie.
func TestCallerIDIsDerivedFromTheThreadedRealm(cur realm, t *testing.T) {
	seen := ""
	conf := &Config{
		Name:        "Identity DAO",
		Description: "fixture",
		Members: NewMembersStore(
			[]RoleInfo{{Name: "admin", Description: "admin", Color: "#000"}},
			[]Member{{alice.String(), []string{"admin"}}},
		),
		GetProfileString: func(addr address, field, def string) string { return "" },
		CallerID: func(dao *DAOPrivate, rlm realm) string {
			seen = rlm.PkgPath()
			return alice.String()
		},
	}
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/testing/identitydao3"))
	_, dao := New(conf, cur)

	dao.Propose(daokit.ProposalRequest{
		Title:       "t",
		Description: "d",
		Action:      NewAddMemberAction(&ActionAddMember{Address: bob}),
	}, cur)

	urequire.Equal(t, "gno.land/r/testing/identitydao3", seen,
		"CallerID must receive the DAO's own realm, so rlm.Previous() names the immediate caller")
}
