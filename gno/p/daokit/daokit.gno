package daokit

import (
	"time"

	"gno.land/p/samcrew/daocond"
)

type DAO interface {
	// Every entry point threads the DAO realm's own realm value.
	//
	// It serves two purposes. Execute forwards it to the action handlers, which
	// cross out under it, so the implementation must refuse any realm that is not
	// its own — otherwise a caller holding this handle could make the DAO act
	// under the CALLER's identity. And because the realm is then known to be the
	// DAO's, rlm.Previous() names the DAO's immediate caller, which a stack walk
	// cannot do: a walk finds the outermost crossing frame, so it reports the
	// signing account rather than an intermediary realm.
	//
	// The realm is deliberately never the first parameter: a function whose first
	// parameter is a realm is read as crossing, which /p/ packages may not declare.

	// Creates a new proposal and returns its ID.
	Propose(req ProposalRequest, rlm realm) uint64
	// Casts a vote on a specific proposal.
	Vote(id uint64, vote daocond.Vote, rlm realm)
	// Executes a proposal if it meets the required conditions.
	Execute(id uint64, rlm realm)

	// Generates a web interface representation for the given path.
	Render(path string) string

	// Gets an extension by path, returns nil if not found.
	Extension(path string) Extension
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

	proposal.Ballot.Vote(voterID, daocond.Vote(vote))
}

// Executes a proposal if it meets the required voting conditions.
func (d *Core) Execute(proposalID uint64, rlm realm) {
	proposal := d.Proposals.GetProposal(proposalID)
	if proposal == nil {
		panic("proposal not found")
	}

	if proposal.Status != ProposalStatusOpen {
		panic("proposal is not open")
	}

	if !proposal.Condition.Eval(proposal.Ballot) {
		panic("proposal condition is not met")
	}

	proposal.UpdateStatus()
	if proposal.Status != ProposalStatusPassed {
		panic("proposal does not meet the condition(s) or is already closed/executed")
	}

	d.Resources.Get(proposal.Action.Type()).Handler.Execute(proposal.Action, rlm)
	proposal.Status = ProposalStatusExecuted
	proposal.ExecutedAt = time.Now()
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
