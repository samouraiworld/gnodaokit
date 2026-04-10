package daocond

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

type membersThresholdCond struct {
	isMemberFn     func(memberId string) bool
	membersCountFn func() uint64
	// Threshold stored as basis points (bps): 6000 = 60%, 10000 = 100%.
	// Integer math avoids non-deterministic float64 behavior in consensus paths.
	thresholdBps uint64
}

// Creates a condition requiring a percentage of members to vote yes.
//
// Example: MembersThreshold(0.6, isMemberFn, countFn)
// Requires 60% member approval. The 0.6 float is converted to 6000 bps at
// construction time; all evaluation uses integer math for consensus safety.
func MembersThreshold(threshold float64, isMemberFn func(memberId string) bool, membersCountFn func() uint64) Condition {
	if threshold <= 0 || threshold > 1 {
		panic(errors.New("invalid threshold"))
	}
	if isMemberFn == nil {
		panic(errors.New("nil isMemberFn"))
	}
	if membersCountFn == nil {
		panic(errors.New("nil membersCountFn"))
	}
	// Convert float threshold to basis points (round to nearest)
	bps := uint64(threshold*10000 + 0.5)
	if bps == 0 {
		bps = 1 // minimum 0.01%
	}
	if bps > 10000 {
		bps = 10000
	}
	return &membersThresholdCond{
		thresholdBps:   bps,
		isMemberFn:     isMemberFn,
		membersCountFn: membersCountFn,
	}
}

// Checks if enough members voted yes to meet the threshold.
// Uses integer math: yes * 10000 >= threshold_bps * total.
func (c *membersThresholdCond) Eval(ballot Ballot) bool {
	total := c.membersCountFn()
	if total == 0 {
		return false
	}
	yes := c.totalVote(ballot, VoteYes)
	return yes*10000 >= c.thresholdBps*total
}

// Returns progress toward meeting the threshold between 0.0 and 1.0.
// Display-only; Signal is not used in consensus decisions.
func (c *membersThresholdCond) Signal(ballot Ballot) float64 {
	total := c.membersCountFn()
	if total == 0 {
		return 0.0
	}
	yes := c.totalVote(ballot, VoteYes)
	// ratio = (yes/total) / (thresholdBps/10000) = (yes * 10000) / (total * thresholdBps)
	numerator := yes * 10000
	denominator := total * c.thresholdBps
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
// Example output: "60% of members"
func (c *membersThresholdCond) Render() string {
	return ufmt.Sprintf("%d.%02d%% of members", c.thresholdBps/100, c.thresholdBps%100)
}

// Displays the condition with current vote counts.
func (c *membersThresholdCond) RenderWithVotes(ballot Ballot) string {
	s := ""
	s += ufmt.Sprintf("%d.%02d%% of members must vote yes\n\n", c.thresholdBps/100, c.thresholdBps%100)
	total := c.membersCountFn()
	s += ufmt.Sprintf("Yes: %d/%d\n\n", c.totalVote(ballot, VoteYes), total)
	s += ufmt.Sprintf("No: %d/%d\n\n", c.totalVote(ballot, VoteNo), total)
	s += ufmt.Sprintf("Abstain: %d/%d\n\n", c.totalVote(ballot, VoteAbstain), total)
	return s
}

var _ Condition = (*membersThresholdCond)(nil)

func (c *membersThresholdCond) totalVote(ballot Ballot, vote Vote) uint64 {
	total := uint64(0)
	ballot.Iterate(func(voter string, v Vote) bool {
		if v == vote && c.isMemberFn(voter) {
			total += 1
		}
		return false
	})
	return total
}
