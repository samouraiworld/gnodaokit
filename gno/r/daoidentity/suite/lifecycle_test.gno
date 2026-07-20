// Proposal lifecycle, driven across realm boundaries.
package suite

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/samcrew/daoidentity/attacker"
	"gno.land/r/samcrew/daoidentity/dao"
)

// These tests actually execute their proposals, so each needs a member the DAO
// does not already hold — AddMember refuses a duplicate.
func addDistinctMemberReq(addr string) daokit.ProposalRequest {
	return daokit.ProposalRequest{
		Title:       "add " + addr,
		Description: "a distinct member per test",
		Action:      basedao.NewAddMemberAction(&basedao.ActionAddMember{Address: address(addr)}),
	}
}

// Rendering must not move a proposal's status.
//
// Render is on the cross-realm DAO interface and reaches GetProposals, which
// used to call UpdateStatus on every proposal it walked. A proposal that had
// met its condition was still Open — Vote never updates status — so any realm
// holding the handle could flip it to Passed with one cheap call. Execute then
// refused it forever, because it required exactly Open.
//
// Reproduced before the fix: Open -> foreign Render -> Passed -> Execute panics
// "proposal is not open", permanently, repeatable after every re-vote.
func TestRenderingDoesNotBrickAPassedProposal(cur realm, t *testing.T) {
	id := dao.Propose(cross(cur), addDistinctMemberReq("g1v9kxjcm9ta047h6lta047h6lta047h6lzd40g1"))
	dao.Vote(cross(cur), id, daocond.VoteYes)
	urequire.Equal(t, "Open", dao.StatusOf(id), "voting alone must not move the status")

	// Anyone holding the handle, in a transaction.
	_ = dao.Handle().Render("proposals")
	urequire.Equal(t, "Open", dao.StatusOf(id), "rendering must not move the status")

	urequire.NotAborts(t, cur, func() {
		dao.Execute(cross(cur), id)
	})
	urequire.Equal(t, "Executed", dao.StatusOf(id))
}

// Executing twice must be refused, and the guard has to be the executed marker
// rather than the old "must be Open" test.
func TestAProposalExecutesOnlyOnce(cur realm, t *testing.T) {
	id := dao.Propose(cross(cur), addDistinctMemberReq("g1v9kxjcm9ta047h6lta047h6lta047h6lzd40g2"))
	dao.Vote(cross(cur), id, daocond.VoteYes)
	dao.Execute(cross(cur), id)

	urequire.AbortsWithMessage(t, cur, "proposal is already executed", func() {
		dao.Execute(cross(cur), id)
	})
}

// A proposal cannot re-enter its own execution.
//
// This is the one re-entrancy shape the realm gate cannot refuse: the handler
// calls back through the DAO realm's own crossing function, so the realm it
// presents is genuinely the DAO's and genuinely live. Only the executed marker
// stops it — and only because that marker is set BEFORE the handler runs.
//
// The old code was protected here by accident: Execute demanded status Open, and
// UpdateStatus had already moved it to Passed. Removing that demand, which is
// what unbricks rendering, would have opened this if the marker had stayed where
// it was.
func TestAProposalCannotReenterItsOwnExecution(cur realm, t *testing.T) {
	id := dao.Propose(cross(cur), dao.NewReenterRequest())
	dao.Vote(cross(cur), id, daocond.VoteYes)
	dao.ArmReenter(id)

	urequire.AbortsWithMessage(t, cur, "proposal is already executed", func() {
		dao.Execute(cross(cur), id)
	})
	urequire.True(t, dao.ReenterAttempted, "the handler must actually have run")
	urequire.False(t, dao.ReenterSucceeded, "the re-entrant Execute must not have returned")
}

// A proposal whose Passed status has been persisted must still execute.
//
// Executed is the only status that disqualifies a proposal. Making Open the
// requirement instead turns the status into a second gate on top of the
// condition, and anything that can move the status can then deny execution —
// which is exactly how rendering bricked proposals. UpdateStatus is exported and
// writes Open -> Passed, so this is reachable without any read path at all.
func TestAPersistedPassedProposalStillExecutes(cur realm, t *testing.T) {
	id := dao.Propose(cross(cur), addDistinctMemberReq("g1v9kxjcm9ta047h6lta047h6lta047h6lzd40g3"))
	dao.Vote(cross(cur), id, daocond.VoteYes)

	dao.PersistStatus(id)
	urequire.Equal(t, "Passed", dao.StatusOf(id), "the status really is persisted")

	urequire.NotAborts(t, cur, func() {
		dao.Execute(cross(cur), id)
	})
	urequire.Equal(t, "Executed", dao.StatusOf(id))
}

// A private extension is readable only by the DAO's own realm.
//
// The check used to be a stack walk, which answers "is a DAO frame innermost",
// not "is my caller the DAO". That let anything the DAO invoked without crossing
// read a private extension — including a proposer-authored ExecuteLambda
// callback. Requiring the DAO's own live realm closes that by construction: a
// callback given no realm cannot produce one.
func TestAPrivateExtensionIsReadableOnlyByItsOwnRealm(cur realm, t *testing.T) {
	urequire.Equal(t, "TOP-SECRET", dao.ReadSecret(cross(cur)),
		"the DAO's own realm must be able to read it")

	urequire.AbortsWithMessage(t, cur, realmMismatch, func() {
		attacker.ReadSecret(cross(cur))
	})
}

// A public extension ignores the realm, so cross-realm membership checks — the
// documented use of MembersViewExtension — keep working.
func TestAPublicExtensionIsReadableByAnyRealm(cur realm, t *testing.T) {
	urequire.True(t, dao.ReadPublicExtension(cross(cur)), "own realm")
	urequire.True(t, attacker.ReadPublicExtension(cross(cur)), "any other realm")
}
