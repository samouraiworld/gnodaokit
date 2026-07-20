package daokit

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
)

// The honest payload a handler expects.
type realPayload struct{ amount int }

func (p *realPayload) String() string { return "transfer 1 coin" }

// A hostile payload that renders identically but carries different data. It
// satisfies every interface the honest type does.
type spoofPayload struct{ amount int }

func (p *spoofPayload) String() string { return "transfer 1 coin" }

// A handler that asserts a CONCRETE type rejects a spoofed payload, which is
// what makes an action's own rendering safe to put in front of a voter.
//
// Both payloads render the same string, so a member reading the proposal cannot
// tell them apart. The rejection therefore has to come from the type assertion,
// not from anything a voter could have noticed.
func TestAConcreteAssertionRejectsASpoofedPayload(cur realm, t *testing.T) {
	executed := 0
	handler := NewActionHandler("transfer", func(payload interface{}, rlm realm) {
		p, ok := payload.(*realPayload)
		if !ok {
			panic("invalid action type")
		}
		executed = p.amount
	})

	honest := NewAction("transfer", &realPayload{amount: 1})
	hostile := NewAction("transfer", &spoofPayload{amount: 1000000})

	urequire.Equal(t, honest.String(), hostile.String(),
		"the payloads must be indistinguishable to a voter, or this proves nothing")

	handler.Execute(honest, cur)
	urequire.Equal(t, 1, executed)

	urequire.PanicsWithMessage(t, cur, "invalid action type", func() {
		handler.Execute(hostile, cur)
	})
	urequire.Equal(t, 1, executed, "the spoofed payload must not have executed")
}

// And the unsafe pattern, demonstrated rather than asserted: a handler that
// asserts to an INTERFACE admits the spoof, because the hostile payload
// satisfies it exactly as the honest one does.
//
// This is why NewActionHandler's contract is a concrete assertion. Nothing in
// daokit can enforce it — the handler decides — so it is pinned here as a fact
// about the pattern rather than a property of any one line of library code.
func TestAnInterfaceAssertionAdmitsTheSpoof(cur realm, t *testing.T) {
	type renderable interface{ String() string }

	admitted := ""
	handler := NewActionHandler("transfer", func(payload interface{}, rlm realm) {
		p, ok := payload.(renderable) // the mistake
		if !ok {
			panic("invalid action type")
		}
		admitted = p.String()
	})

	hostile := NewAction("transfer", &spoofPayload{amount: 1000000})

	urequire.NotPanics(t, cur, func() {
		handler.Execute(hostile, cur)
	})
	urequire.Equal(t, "transfer 1 coin", admitted,
		"the handler accepted a payload of 1000000 that renders as 1 — exactly the spoof")
}

// An action cannot disguise its KIND, because Type() is the key its handler is
// looked up by: claim a different kind and that kind's handler runs, and its
// concrete assertion fails. So what a member sees an action IS comes from the
// DAO's own resource registry, not from the proposal.
func TestAnActionCannotDisguiseItsKind(cur realm, t *testing.T) {
	core := NewCore()
	transferRan := false
	core.Resources.Set(&Resource{
		Handler: NewActionHandler("transfer", func(payload interface{}, rlm realm) {
			if _, ok := payload.(*realPayload); !ok {
				panic("invalid action type")
			}
			transferRan = true
		}),
		DisplayName: "Transfer funds",
	})

	disguised := NewAction("transfer", &spoofPayload{amount: 1000000})

	urequire.Equal(t, "Transfer funds",
		core.Resources.Get(disguised.Type()).DisplayName,
		"the name a voter sees is keyed by Type(), not supplied by the proposal")

	urequire.PanicsWithMessage(t, cur, "invalid action type", func() {
		core.Resources.Get(disguised.Type()).Handler.Execute(disguised, cur)
	})
	urequire.False(t, transferRan)
}
