package daocond_test

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
	"gno.land/p/samcrew/daocond"
)

// A threshold condition divides the yes-votes by the size of its electorate.
// When that electorate is empty the division is 0/0, and gno's float64 divide
// has no zero guard (unlike the integer cases), so it yields NaN. NaN then
// leaks out of Eval, Signal and RenderWithVotes — Signal in particular is a
// display/progress value, and math.Min(NaN/threshold, 1) is NaN, not 1.
//
// The electorate is reachably empty while the DAO still has members, so the
// RemoveMember minimum-member guard does not cover it: RemoveRoleFromMember
// (a default-registered governance action), RemoveRole, and removing the last
// holder of a role while others remain all get there.
//
// Zero must resolve to 0.0, never 1.0: a vacuous-truth reading would let a
// proposal pass with nobody entitled to vote on it.

func TestRoleThresholdWithNoRoleHoldersIsNotNaN(t *testing.T) {
	noHolders := func(memberId string, role string) bool { return false }
	zeroCount := func(role string) uint32 { return 0 }

	cond := daocond.RoleThreshold(0.6, "admin", noHolders, zeroCount)
	ballot := daocond.NewBallot()

	signal := cond.Signal(ballot)
	// NaN is the only value that is not equal to itself.
	urequire.False(t, signal != signal, "Signal must not be NaN")
	urequire.Equal(t, 0.0, signal)
	urequire.False(t, cond.Eval(ballot), "an empty electorate must not satisfy the threshold")
}

func TestMembersThresholdWithNoMembersIsNotNaN(t *testing.T) {
	noMembers := func(memberId string) bool { return false }
	zeroCount := func() uint64 { return 0 }

	cond := daocond.MembersThreshold(0.6, noMembers, zeroCount)
	ballot := daocond.NewBallot()

	signal := cond.Signal(ballot)
	urequire.False(t, signal != signal, "Signal must not be NaN")
	urequire.Equal(t, 0.0, signal)
	urequire.False(t, cond.Eval(ballot), "an empty electorate must not satisfy the threshold")
}

// Render output is surfaced on every proposal-detail page; a NaN there is a
// permanent cosmetic defect on an immutable publish.
func TestEmptyElectorateRendersNoNaN(t *testing.T) {
	noHolders := func(memberId string, role string) bool { return false }
	zeroCount := func(role string) uint32 { return 0 }

	cond := daocond.RoleThreshold(0.6, "admin", noHolders, zeroCount)
	rendered := cond.RenderWithVotes(daocond.NewBallot())

	urequire.False(t, contains(rendered, "NaN"), "render must not contain NaN: "+rendered)
}

func contains(haystack, needle string) bool {
	if len(needle) > len(haystack) {
		return false
	}
	for i := 0; i+len(needle) <= len(haystack); i++ {
		if haystack[i:i+len(needle)] == needle {
			return true
		}
	}
	return false
}
