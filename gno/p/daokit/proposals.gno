package daokit

// Proposals manage the lifecycle of DAO governance decisions.
// Each proposal has a status, voting condition, and executable action.
// Members vote on proposals which can be executed when conditions are met.
//
// Example: Proposal to add a member, transfer funds, or change governance rules.
//
// Usage:
//   req := ProposalRequest{Title: "Add Member", Action: addMemberAction}
//   proposal := store.newProposal(proposerID, req, condition)

import (
	"chain/runtime"
	"errors"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/seqid"
	"gno.land/p/onbloc/json"
	"gno.land/p/samcrew/daocond"
)

// Current state of a proposal in the governance process.
type ProposalStatus int

const (
	ProposalStatusOpen     ProposalStatus = iota // Currently accepting votes
	ProposalStatusPassed                         // Met conditions, ready for execution
	ProposalStatusExecuted                       // Successfully executed
)

func (s ProposalStatus) String() string {
	switch s {
	case ProposalStatusOpen:
		return "Open"
	case ProposalStatusPassed:
		return "Passed"
	case ProposalStatusExecuted:
		return "Executed"
	default:
		return "Unknown"
	}
}

type Proposal struct {
	ID            seqid.ID
	Title         string
	Description   string
	CreatedAt     time.Time
	CreatedHeight int64
	ProposerID    string

	Action     Action            // What to execute if passed
	Condition  daocond.Condition // Voting conditions for this proposal
	Status     ProposalStatus
	ExecutorID string
	ExecutedAt time.Time

	Ballot daocond.Ballot // All votes cast on this proposal
}

type ProposalsStore struct {
	Tree  *avl.Tree // int -> Proposal
	genID seqid.ID
}

// Data needed to create a new proposal.
type ProposalRequest struct {
	Title       string
	Description string
	Action      Action
}

func NewProposalsStore() *ProposalsStore {
	return &ProposalsStore{
		Tree: avl.NewTree(),
	}
}

func (p *ProposalsStore) newProposal(proposer string, req ProposalRequest, condition daocond.Condition) *Proposal {
	id := p.genID.Next()
	proposal := &Proposal{
		ID:            id,
		Title:         req.Title,
		Description:   req.Description,
		ProposerID:    proposer,
		Status:        ProposalStatusOpen,
		Action:        req.Action,
		Condition:     condition,
		Ballot:        daocond.NewBallot(),
		CreatedAt:     time.Now(),
		CreatedHeight: runtime.ChainHeight(),
	}
	p.Tree.Set(id.String(), proposal)
	return proposal
}

func (p *ProposalsStore) GetProposal(id uint64) *Proposal {
	value, ok := p.Tree.Get(seqid.ID(id).String())
	if !ok {
		return nil
	}
	proposal := value.(*Proposal)
	return proposal
}

// Returns all proposals that match the given filter function.
func (p *ProposalsStore) GetProposals(filter func(Proposal) bool) *ProposalsStore {
	proposals := NewProposalsStore()
	p.Tree.Iterate("", "", func(key string, value interface{}) bool {
		prop, ok := value.(*Proposal)
		if !ok {
			panic(errors.New("unexpected invalid proposal type"))
		}
		prop.UpdateStatus() // XXX: costly and probably insecure
		if filter(*prop) {
			proposals.Tree.Set(key, prop)
		}
		return false
	})
	return proposals
}

// Updates proposal status based on current voting condition results.
func (p *Proposal) UpdateStatus() {
	conditionsAreMet := p.Condition.Eval(p.Ballot)
	if p.Status == ProposalStatusOpen && conditionsAreMet {
		p.Status = ProposalStatusPassed
	}
}

// Returns all proposals as a JSON string.
func (p *ProposalsStore) GetProposalsJSON() string {
	props := make([]*json.Node, 0, p.Tree.Size())
	// XXX: pagination
	p.Tree.Iterate("", "", func(key string, value interface{}) bool {
		prop, ok := value.(*Proposal)
		if !ok {
			panic(errors.New("unexpected invalid proposal type"))
		}
		prop.UpdateStatus()
		props = append(props, json.ObjectNode("", map[string]*json.Node{
			"id":          json.NumberNode("", float64(prop.ID)),
			"title":       json.StringNode("", prop.Title),
			"description": json.StringNode("", prop.Description),
			"proposer":    json.StringNode("", prop.ProposerID),
			"status":      json.StringNode("", prop.Status.String()),
			"startHeight": json.NumberNode("", float64(prop.CreatedHeight)),
			"signal":      json.NumberNode("", prop.Condition.Signal(prop.Ballot)),
		}))
		return false
	})
	bz, err := json.Marshal(json.ArrayNode("", props))
	if err != nil {
		panic(err)
	}
	return string(bz)
}
