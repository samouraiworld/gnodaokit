package daocond

// Package daocond provides a stateless condition system for DAO voting.
//
// This model replaces complex event handlers for membership changes,
// role assignments, and other governance actions. It works well for
// small DAOs with few voters, with plans to add stateful models for
// larger DAOs in the future.

// Condition defines the interface for voting conditions that can be
// evaluated against a ballot and display progress information.
type Condition interface {
	// Eval checks if the condition is satisfied by the current votes.
	Eval(ballot Ballot) bool

	// Signal returns progress toward satisfying the condition (0.0 to 1.0).
	Signal(ballot Ballot) float64

	// Render displays the condition as human-readable text.
	Render() string

	// RenderWithVotes displays the condition with current vote counts.
	RenderWithVotes(ballot Ballot) string
}

// Ballot represents a collection of votes that can be evaluated
// against conditions.
type Ballot interface {
	// Vote records a vote from a specific voter.
	Vote(voter string, vote Vote)

	// Get retrieves the vote from a specific voter.
	Get(voter string) Vote

	// Total returns the total number of votes cast.
	Total() int

	// Iterate over all votes, calling fn for each voter-vote pair.
	// If fn returns false, iteration stops.
	// Useful for counting specific vote types or finding particular voters.
	Iterate(fn func(voter string, vote Vote) bool)
}

// Vote represents a voting decision.
type Vote string

// Available vote options.
const (
	VoteYes     Vote = "yes"
	VoteNo      Vote = "no"
	VoteAbstain Vote = "abstain"
)
