package daokit

import (
	"time"

	"gno.land/p/samcrew/daocond"
)

// Every entry point threads the DAO realm's own realm value.
//
// It serves two purposes. Execute forwards it to the action handlers, which
// cross out under it, so the implementation must refuse any realm that is not
// its own — otherwise a caller holding this handle could make the DAO act under
// the CALLER's identity. And because the realm is then known to be the DAO's,
// rlm.Previous() names the DAO's immediate caller, which a stack walk cannot do:
// reached through this handle there is no DAO realm frame on the stack at all,
// so a walk reports the signing account instead.
//
// An implementation must require the realm to be BOTH its own by pkgpath and
// current: every realm the DAO crosses out into receives the DAO's own realm as
// its cur.Previous() and can hand it back within the same transaction, and only
// IsCurrent() tells that apart from the live one.
//
// The realm is deliberately never the first parameter: a function whose first
// parameter is a realm is read as crossing, which /p/ packages may not declare.
type DAO interface {
	// Creates a new proposal and returns its ID.
	Propose(req ProposalRequest, rlm realm) uint64
	// Casts a vote on a specific proposal.
	Vote(id uint64, vote daocond.Vote, rlm realm)
	// Executes a proposal if it meets the required conditions.
	Execute(id uint64, rlm realm)

	// Generates a web interface representation for the given path.
	Render(path string) string

	// Gets an extension by path, returns nil if not found. A PRIVATE extension
	// additionally requires the DAO realm's own live realm, on the same terms
	// as the entry points above; a public one ignores it.
	Extension(path string, rlm realm) Extension
	// Lists all available extensions.
	ExtensionsList() ExtensionsList
}

// Function type for updating DAO implementation during governance upgrades.
type SetImplemFn = func(implem DAO)

// Creates, votes yes, and immediately executes a proposal in one operation.
// Useful when you have enough permission to execute an action directly.
// Examples: migrations, adding members
func InstantExecute(d DAO, req ProposalRequest, rlm realm) uint64 {
	id := d.Propose(req, rlm)
	d.Vote(id, daocond.VoteYes, rlm)
	d.Execute(id, rlm)
	return id
}

// Manages the essential components of a DAO: resources, proposals, and extensions.
type Core struct {
	Resources  *ResourcesStore  // Available actions and their conditions
	Proposals  *ProposalsStore  // All proposals and their voting state
	Extensions *ExtensionsStore // Pluggable functionality modules
}

// Creates a new DAO core with empty stores.
func NewCore() *Core {
	return &Core{
		Resources:  NewResourcesStore(),
		Proposals:  NewProposalsStore(),
		Extensions: &ExtensionsStore{},
	}
}

// Records a vote for a specific proposal from a voter.
func (d *Core) Vote(voterID string, proposalID uint64, vote daocond.Vote) {
	proposal := d.Proposals.GetProposal(proposalID)
	if proposal == nil {
		panic("proposal not found")
	}

	if proposal.Status != ProposalStatusOpen {
		panic("proposal is not open")
	}

	proposal.Ballot.Vote(voterID, vote)
}

// Executes a proposal if it meets the required voting conditions.
func (d *Core) Execute(proposalID uint64, rlm realm) {
	proposal := d.Proposals.GetProposal(proposalID)
	if proposal == nil {
		panic("proposal not found")
	}

	// Executed is the only status that disqualifies a proposal. It used to be
	// "anything but Open", which made the status a second, weaker gate on top of
	// the condition — and any realm holding the DAO handle could trip it by
	// rendering, since the read paths wrote Open -> Passed as they walked.
	// Whether a proposal may execute is decided by its condition, below, and
	// nothing else.
	if proposal.Status == ProposalStatusExecuted {
		panic("proposal is already executed")
	}

	if !proposal.Condition.Eval(proposal.Ballot) {
		panic("proposal condition is not met")
	}

	// Marked BEFORE the handler runs, not after. The handler crosses out of the
	// DAO, so a callee can re-enter here within the same transaction; marking
	// afterwards would let it execute the same proposal again. The old code was
	// protected from this only incidentally, by the "must be Open" test above —
	// removing that test without moving this line would have opened it.
	proposal.Status = ProposalStatusExecuted
	proposal.ExecutedAt = time.Now()

	d.Resources.Get(proposal.Action.Type()).Handler.Execute(proposal.Action, rlm)
}

// Creates a new proposal for voting and returns its ID.
func (d *Core) Propose(proposerID string, req ProposalRequest) uint64 {
	actionType := req.Action.Type()

	resource := d.Resources.Get(actionType)
	if resource == nil {
		panic("action type is not registered as a resource")
	}

	prop := d.Proposals.newProposal(proposerID, req, resource.Condition)
	return uint64(prop.ID)
}
