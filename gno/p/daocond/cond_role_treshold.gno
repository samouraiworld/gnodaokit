package daocond

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

type roleThresholdCond struct {
	hasRoleFn        func(memberId string, role string) bool
	usersRoleCountFn func(role string) uint32
	// Threshold stored as basis points (bps): 6000 = 60%, 10000 = 100%.
	// Integer math avoids non-deterministic float64 behavior in consensus paths.
	thresholdBps uint32
	role         string
}

// Creates a condition requiring a percentage of role holders to vote yes.
//
// Example: RoleThreshold(0.6, "admin", hasRoleFn, countFn)
// Requires 60% of admins. The 0.6 float is converted to 6000 bps at
// construction time; all evaluation uses integer math for consensus safety.
func RoleThreshold(threshold float64, role string, hasRoleFn func(memberId string, role string) bool, usersRoleCountFn func(role string) uint32) Condition {
	if threshold <= 0 || threshold > 1 {
		panic(errors.New("invalid threshold"))
	}
	if hasRoleFn == nil {
		panic(errors.New("nil hasRoleFn"))
	}
	if usersRoleCountFn == nil {
		panic(errors.New("nil usersRoleCountFn"))
	}
	bps := uint32(threshold*10000 + 0.5)
	if bps == 0 {
		bps = 1
	}
	if bps > 10000 {
		bps = 10000
	}
	return &roleThresholdCond{
		thresholdBps:     bps,
		hasRoleFn:        hasRoleFn,
		usersRoleCountFn: usersRoleCountFn,
		role:             role,
	}
}

// Checks if enough role holders voted yes to meet the threshold.
// Uses integer math: yes * 10000 >= threshold_bps * total.
func (c *roleThresholdCond) Eval(ballot Ballot) bool {
	total := c.usersRoleCountFn(c.role)
	if total == 0 {
		return false
	}
	yes := c.totalVote(ballot, VoteYes)
	return uint64(yes)*10000 >= uint64(c.thresholdBps)*uint64(total)
}

// Returns progress toward meeting the threshold between 0.0 and 1.0.
// Display-only; Signal is not used in consensus decisions.
func (c *roleThresholdCond) Signal(ballot Ballot) float64 {
	total := c.usersRoleCountFn(c.role)
	if total == 0 {
		return 0.0
	}
	yes := c.totalVote(ballot, VoteYes)
	numerator := uint64(yes) * 10000
	denominator := uint64(total) * uint64(c.thresholdBps)
	if denominator == 0 {
		return 0.0
	}
	ratio := float64(numerator) / float64(denominator)
	if ratio > 1.0 {
		return 1.0
	}
	return ratio
}

// Displays the condition as text.
func (c *roleThresholdCond) Render() string {
	return ufmt.Sprintf("%d.%02d%% of %s members", c.thresholdBps/100, c.thresholdBps%100, c.role)
}

// Displays the condition with current vote counts.
func (c *roleThresholdCond) RenderWithVotes(ballot Ballot) string {
	s := ""
	s += ufmt.Sprintf("%d.%02d%% of %s members must vote yes\n\n", c.thresholdBps/100, c.thresholdBps%100, c.role)
	total := c.usersRoleCountFn(c.role)
	s += ufmt.Sprintf("Yes: %d/%d\n\n", c.totalVote(ballot, VoteYes), total)
	s += ufmt.Sprintf("No: %d/%d\n\n", c.totalVote(ballot, VoteNo), total)
	s += ufmt.Sprintf("Abstain: %d/%d\n\n", c.totalVote(ballot, VoteAbstain), total)
	return s
}

var _ Condition = (*roleThresholdCond)(nil)

// Snapshot freezes the current role member count at proposal creation time.
// Prevents minority takeover via role assignment/removal between vote and execution.
func (c *roleThresholdCond) Snapshot() Condition {
	frozenTotal := c.usersRoleCountFn(c.role)
	return &roleThresholdCond{
		hasRoleFn:        c.hasRoleFn,
		usersRoleCountFn: func(_ string) uint32 { return frozenTotal },
		thresholdBps:     c.thresholdBps,
		role:             c.role,
	}
}

func (c *roleThresholdCond) totalVote(ballot Ballot, vote Vote) uint32 {
	total := uint32(0)
	ballot.Iterate(func(voter string, v Vote) bool {
		if v == vote && c.hasRoleFn(voter, c.role) {
			total += 1
		}
		return false
	})
	return total
}
