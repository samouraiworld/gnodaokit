package daokit

// Define what DAOs can do when proposals are executed.
// Each action has a type and handler that implements the actual logic.
//
// Example: Adding a member, transferring funds, or updating configuration.
//
// Usage:
//   action := NewAction("custom.AddMember", memberData)
//   handler := NewActionHandler("custom.AddMember", addMemberFunc)

import (
	"errors"

	"gno.land/p/moul/md"
	"gno.land/p/nt/ufmt"
)

// Represents a proposal's executable operation.
type Action interface {
	// Returns human-readable description of the action.
	String() string
	// Returns unique identifier for the action type.
	Type() string
}

// Executes actions when proposals pass.
type ActionHandler interface {
	// Executes the given action's logic.
	Execute(action Action)
	// Returns the action type this handler processes.
	Type() string
}

// Creates a new action with the specified type and payload data.
func NewAction(kind string, payload interface{}) Action {
	return &genericAction{kind: kind, payload: payload}
}

// Generic action implementation that stores type and payload data.
type genericAction struct {
	payload interface{} // The action's data
	kind    string      // The action's type identifier
}

// Returns string representation of the action's payload.
func (g *genericAction) String() string {
	return ufmt.Sprintf("%v", g.payload)
}

// Returns the action's type identifier.
func (g *genericAction) Type() string {
	return g.kind
}

// Creates a new action handler with the specified type and execution function.
func NewActionHandler(kind string, executor func(interface{})) ActionHandler {
	return &genericActionHandler{kind: kind, executor: executor}
}

// Generic action handler that executes functions on action payloads.
type genericActionHandler struct {
	executor func(payload interface{}) // Function that processes the action
	kind     string                    // Action type this handler processes
}

// Executes the action by calling the executor function with the payload.
func (g *genericActionHandler) Execute(iaction Action) {
	action, ok := iaction.(*genericAction)
	if !ok {
		panic(errors.New("invalid action type"))
	}
	g.executor(action.payload)
}

// Creates a new empty action instance of this handler's type.
func (g *genericActionHandler) Instantiate() Action {
	return &genericAction{
		kind: g.kind,
	}
}

// Returns the action type this handler processes.
func (g *genericActionHandler) Type() string {
	return g.kind
}

// //////////////////////////////////////////////////////////
// ActionExecuteLambdaKind
//
// Built-in action type for executing lambda functions.
const ActionExecuteLambdaKind = "gno.land/p/samcrew/daokit.ExecuteLambda"

func NewExecuteLambdaHandler() ActionHandler {
	return NewActionHandler(ActionExecuteLambdaKind, func(i interface{}) {
		cb, ok := i.(func())
		if !ok {
			panic(errors.New("invalid action type"))
		}
		cb()
	})
}

func NewExecuteLambdaAction(cb func()) Action {
	return NewAction(ActionExecuteLambdaKind, cb)
}

// //////////////////////////////////////////////////////////
// ActionInstantExecuteKind
//
// Built-in action type for instantly executing sub-proposals.
const ActionInstantExecuteKind = "gno.land/p/samcrew/daokit.InstantExecute"

type actionInstantExecute struct {
	dao DAO             // Target DAO to execute on
	req ProposalRequest // Proposal to execute instantly
}

func (a *actionInstantExecute) String() string {
	// XXX: find a way to be explicit about the subdao
	s := ""
	s += md.Paragraph(md.Blockquote(a.req.Action.Type()))
	s += md.Paragraph(a.req.Action.String())
	return s
}

func NewInstantExecuteHandler() ActionHandler {
	return NewActionHandler(ActionInstantExecuteKind, func(i interface{}) {
		action, ok := i.(*actionInstantExecute)
		if !ok {
			panic(errors.New("invalid action type"))
		}
		InstantExecute(action.dao, action.req)
	})
}

func NewInstantExecuteAction(dao DAO, req ProposalRequest) Action {
	return NewAction(ActionInstantExecuteKind, &actionInstantExecute{dao: dao, req: req})
}
