// Package suite drives the DAO across genuine realm boundaries.
//
// Every assertion here is unreachable from a testing.SetRealm harness: SetRealm
// fabricates a cur with no frame beneath it, so cur.Previous() resolves to
// gno.land/p/samcrew/basedao rather than to a caller. That harness cannot tell
// a correct caller-identity implementation from a broken one, which is why the
// original defect and #66's New() regression both passed CI.
package suite

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/samcrew/daoidentity/attacker"
	"gno.land/r/samcrew/daoidentity/callback"
	"gno.land/r/samcrew/daoidentity/dao"
	"gno.land/r/samcrew/daoidentity/nonmember"
	"gno.land/r/samcrew/daoidentity/relay"
)

const realmMismatch = "realm mismatch: the DAO may only act as gno.land/r/samcrew/daoidentity/dao"

func addMemberReq() daokit.ProposalRequest {
	return daokit.ProposalRequest{
		Title:       "add a member",
		Description: "any registered action will do",
		Action: basedao.NewAddMemberAction(&basedao.ActionAddMember{
			Address: "g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh",
		}),
	}
}

// The control for every refusal below. This realm is a DAO member, so a call
// that reaches the membership check from here passes it. Any refusal in the
// other tests is therefore the realm gate, not an incidental membership
// failure — and, before the gate existed, this membership is exactly what let
// a foreign realm's call through.
func TestSuiteIsAMemberSoMembershipIsSatisfiable(cur realm, t *testing.T) {
	id := dao.Propose(cross(cur), addMemberReq())

	urequire.Equal(t, dao.SuiteID, dao.ProposerOf(id),
		"the DAO must resolve its immediate caller, which is this realm")
}

// The DAO's immediate caller is the relay, not the account that signed the
// transaction.
//
// A stack walk gets this same answer, because the DAO realm's own frame is on
// the stack here. It is not a regression test for the identity derivation; it
// pins that reaching the DAO the supported way resolves the immediate caller,
// which is the behaviour the demos and every realm integration depend on.
func TestTheResolvedCallerIsTheImmediateOne(cur realm, t *testing.T) {
	id := relay.Propose(cross(cur), addMemberReq())

	urequire.Equal(t, dao.RelayID, dao.ProposerOf(id),
		"the relay called the DAO, so the relay is the proposer")
}

// P0-B, the donation path: a third realm holding the DAO value hands it its own
// realm. Execute forwards that realm to the action handlers, which cross out
// under it, so an accepted foreign realm makes the DAO act as the caller —
// writing to the caller's profile, and through MigrateFn reaching any realm the
// caller controls.
//
// Realm values are unforgeable and cannot be persisted across transactions, so
// a caller can only ever pass its own. Requiring the realm to be the DAO's own
// therefore closes the path outright, without trusting the caller.
func TestAForeignRealmMayNotDonateItsIdentityToExecute(cur realm, t *testing.T) {
	urequire.AbortsWithMessage(t, cur, realmMismatch, func() {
		// The proposal id is irrelevant: the realm gate runs before any
		// lookup, so a foreign realm never reaches proposal state at all.
		attacker.Execute(cross(cur), 0)
	})
}

// P0-A is the same defect from the other side. Reached this way there is no DAO
// realm frame on the stack, so basedao's old stack-walking identity named the
// signer rather than the attacker — and the signer is a member, as
// TestSuiteIsAMemberSoMembershipIsSatisfiable establishes. The membership check
// passed while the attacker supplied the realm the DAO acted under.
func TestAForeignRealmMayNotDonateItsIdentityToPropose(cur realm, t *testing.T) {
	urequire.AbortsWithMessage(t, cur, realmMismatch, func() {
		attacker.Propose(cross(cur), addMemberReq())
	})
}

func TestAForeignRealmMayNotDonateItsIdentityToVote(cur realm, t *testing.T) {
	urequire.AbortsWithMessage(t, cur, realmMismatch, func() {
		attacker.Vote(cross(cur), 0, daocond.VoteYes)
	})
}

// A realm the DAO crosses out into receives the DAO's own realm value as its
// cur.Previous(). That value carries the DAO's pkgpath, so a gate that only
// compares pkgpaths accepts it back — letting a callee re-enter the DAO under
// the DAO's own identity, from a frame the DAO never intended to be re-entered
// from.
//
// It is not the live crossing frame's cur, so IsCurrent() is false and the gate
// refuses it. Nothing but IsCurrent() distinguishes it.
func TestADAORealmValueFromADeadFrameIsRefused(cur realm, t *testing.T) {
	id := dao.Propose(cross(cur), dao.NewCrossOutRequest(addMemberReq()))
	dao.Vote(cross(cur), id, daocond.VoteYes)

	urequire.AbortsWithMessage(t, cur, realmMismatch, func() {
		dao.Execute(cross(cur), id)
	})
	urequire.False(t, callback.Reentered(),
		"the re-entrant proposal must never have been accepted")
}

// The entry gate must run BEFORE CallerID, not after.
//
// CallerIDFn is a frozen extension point, so the realm it receives is part of
// the contract. If the membership check ran first, a custom CallerIDFn would be
// handed an attacker-controlled realm and asked to derive an identity from it —
// which is the whole defect, relocated into the extension point. Nothing else
// in the suite pins the ordering: swapping the two lines leaves every other
// test green.
func TestTheGateRunsBeforeCallerIDEverSeesTheRealm(cur realm, t *testing.T) {
	// A legitimate call, to show CallerID does run and does record.
	dao.Propose(cross(cur), addMemberReq())
	urequire.Equal(t, dao.Self, dao.SeenByCallerID(),
		"CallerID must be handed the DAO's own realm on the supported path")

	urequire.AbortsWithMessage(t, cur, realmMismatch, func() {
		attacker.Propose(cross(cur), addMemberReq())
	})
	urequire.Equal(t, dao.Self, dao.SeenByCallerID(),
		"a refused call must never reach CallerID, so the recorded realm is unchanged")
}

// Execute requires membership, not merely a valid realm. The DAO realm's own
// crossing functions are callable by anyone, so without this a non-member could
// execute any proposal that had reached its threshold.
func TestExecuteRequiresMembershipNotJustTheRightRealm(cur realm, t *testing.T) {
	id := dao.Propose(cross(cur), addMemberReq())
	dao.Vote(cross(cur), id, daocond.VoteYes)

	// nonmember reaches the DAO through its own crossing function, so the realm
	// gate passes and only the membership check stands between it and execution.
	urequire.AbortsWithMessage(t, cur, "caller is not a member", func() {
		nonmember.Execute(cross(cur), id)
	})
}
