package daocond_test

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
	"gno.land/p/samcrew/daocond"
)

// RenderWithVotes is reachable from every proposal-detail render
// (basedao/view_proposal_detail_page.gno). gno's ufmt panics on an argument
// shortfall rather than emitting Go's cosmetic "%!s(MISSING)", so an arity
// mismatch here bricks proposal rendering for any DAO using a RoleThreshold.
func TestRoleThresholdRenderWithVotes(t *testing.T) {
	hasRole := func(memberId string, role string) bool {
		return memberId == "alice" && role == "admin"
	}
	roleCount := func(role string) uint32 { return 2 }

	cond := daocond.RoleThreshold(0.6, "admin", hasRole, roleCount)

	ballot := daocond.NewBallot()
	ballot.Vote("alice", daocond.VoteYes)

	want := "60% of admin members with role admin must vote yes\n\n" +
		"Yes: 1/2 = 50%\n\n" +
		"No: 0/2 = 0%\n\n" +
		"Abstain: 0/2 = 0%\n\n"

	urequire.Equal(t, want, cond.RenderWithVotes(ballot))
}
