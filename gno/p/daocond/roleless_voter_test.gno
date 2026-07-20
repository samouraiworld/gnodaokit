package daocond

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
)

// Core.Vote gates on membership only, never on holding one of the tier roles,
// so a member with no tier role can land in the ballot. getUserRole then found
// no match and panicked — and because the panic is raised from inside the
// ballot walk, every subsequent Eval, Signal and Render on that proposal
// panicked too. On an immutable publish that is permanent, and it is triggered
// by an ordinary member casting an ordinary vote.
//
// A voter with no tier role has no voting power; they must contribute zero,
// not abort the tally.
func TestGnoloveDAOCondToleratesARolelessVoter(t *testing.T) {
	roles := []string{"T1", "T2"}
	hasRole := func(userID string, role string) bool {
		return userID == "t1voter" && role == "T1"
	}
	usersWithRoleCount := func(role string) uint32 {
		if role == "T1" {
			return 1
		}
		return 0
	}

	cond := GnoloveDAOCondThreshold(0.5, roles, hasRole, usersWithRoleCount)

	ballot := NewBallot()
	ballot.Vote("t1voter", VoteYes)
	ballot.Vote("roleless", VoteYes)

	// The roleless voter carries no power, so the T1 voter alone still decides.
	urequire.True(t, cond.Eval(ballot), "the roleless voter must not abort the tally")

	signal := cond.Signal(ballot)
	urequire.False(t, signal != signal, "Signal must not be NaN")
}
