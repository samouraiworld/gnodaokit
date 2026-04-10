package daokit

// Handles DAO governance through proposal voting and execution.
// They contain actions that run when voting requirements are satisfied.
//
// Common use cases: member management, treasury operations, rule updates.

import (
	"chain/runtime"
	"errors"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/seqid"
	"gno.land/p/onbloc/json"
	"gno.land/p/samcrew/daocond"
)

type ProposalStatus int

const (
	ProposalStatusOpen     ProposalStatus = iota // Currently accepting votes
	ProposalStatusPassed                         // Met conditions, ready for execution
	ProposalStatusExecuted                       // Successfully executed
	ProposalStatusExpired                        // Expired without passing
)

func (s ProposalStatus) String() string {
	switch s {
	case ProposalStatusOpen:
		return "Open"
	case ProposalStatusPassed:
		return "Passed"
	case ProposalStatusExecuted:
		return "Executed"
	case ProposalStatusExpired:
		return "Expired"
	default:
		return "Unknown"
	}
}

const (
	MaxOpenProposals  = 50            // Maximum concurrent open proposals
	ProposalTTLBlocks = int64(864000) // ~30 days at 3s/block — proposals expire after this
)

type Proposal struct {
	ID            seqid.ID
	Title         string
	Description   string
	CreatedAt     time.Time
	CreatedHeight int64
	ExpiresHeight int64 // Block height at which the proposal expires (0 = no expiry for legacy)
	ProposerID    string

	Action     Action            // What to execute if passed
	Condition  daocond.Condition // Voting conditions for this proposal
	Status     ProposalStatus
	ExecutorID string
	ExecutedAt time.Time

	Ballot daocond.Ballot // All votes cast on this proposal
}

type ProposalsStore struct {
	Tree      *avl.Tree // int -> Proposal
	genID     seqid.ID
	openCount int // Track open proposals for spam prevention
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

func (p *ProposalsStore) GetProposal(id uint64) *Proposal {
	value, ok := p.Tree.Get(seqid.ID(id).String())
	if !ok {
		return nil
	}
	proposal := value.(*Proposal)
	return proposal
}

// Returns all proposals that match the given filter function.
// Also updates status (expiry/passable) as a side effect, keeping openCount in sync.
func (p *ProposalsStore) GetProposals(filter func(Proposal) bool) *ProposalsStore {
	proposals := NewProposalsStore()
	p.Tree.Iterate("", "", func(key string, value interface{}) bool {
		prop, ok := value.(*Proposal)
		if !ok {
			panic(errors.New("unexpected invalid proposal type"))
		}
		wasOpen := prop.Status == ProposalStatusOpen
		prop.UpdateStatus()
		// Decrement openCount if proposal transitioned out of Open state
		if wasOpen && prop.Status != ProposalStatusOpen {
			p.decrementOpen()
		}
		if filter(*prop) {
			proposals.Tree.Set(key, prop)
		}
		return false
	})
	return proposals
}

// Updates proposal status based on current voting condition results and expiry.
// NOTE: Callers that care about openCount tracking must use the store-level
// helper UpdateProposalStatus, which handles the decrement on transitions.
func (p *Proposal) UpdateStatus() {
	if p.Status != ProposalStatusOpen {
		return
	}
	// Check expiry first
	if p.ExpiresHeight > 0 && runtime.ChainHeight() > p.ExpiresHeight {
		p.Status = ProposalStatusExpired
		return
	}
	if p.Condition.Eval(p.Ballot) {
		p.Status = ProposalStatusPassed
	}
}

// UpdateProposalStatus is a store-level helper that calls UpdateStatus and
// tracks openCount transitions. Use this from code paths that must keep the
// openCount in sync (Vote, Execute, Render paths).
func (p *ProposalsStore) UpdateProposalStatus(prop *Proposal) {
	wasOpen := prop.Status == ProposalStatusOpen
	prop.UpdateStatus()
	if wasOpen && prop.Status != ProposalStatusOpen {
		p.decrementOpen()
	}
}

// CleanExpired iterates all proposals and transitions expired ones to
// ProposalStatusExpired, freeing openCount slots. Anyone can call.
func (p *ProposalsStore) CleanExpired() int {
	cleaned := 0
	p.Tree.Iterate("", "", func(key string, value interface{}) bool {
		prop, ok := value.(*Proposal)
		if !ok {
			return false
		}
		if prop.Status != ProposalStatusOpen {
			return false
		}
		if prop.ExpiresHeight > 0 && runtime.ChainHeight() > prop.ExpiresHeight {
			prop.Status = ProposalStatusExpired
			p.decrementOpen()
			cleaned++
		}
		return false
	})
	return cleaned
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
		wasOpen := prop.Status == ProposalStatusOpen
		prop.UpdateStatus()
		if wasOpen && prop.Status != ProposalStatusOpen {
			p.decrementOpen()
		}
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

func (p *ProposalsStore) decrementOpen() {
	if p.openCount > 0 {
		p.openCount--
	}
}

func (p *ProposalsStore) newProposal(proposer string, req ProposalRequest, condition daocond.Condition) *Proposal {
	if p.openCount >= MaxOpenProposals {
		panic("too many open proposals — wait for existing proposals to pass, execute, or expire")
	}

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
		ExpiresHeight: runtime.ChainHeight() + ProposalTTLBlocks,
	}
	p.Tree.Set(id.String(), proposal)
	p.openCount++
	return proposal
}
