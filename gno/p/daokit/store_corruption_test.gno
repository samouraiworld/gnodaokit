package daokit

import (
	"testing"

	"gno.land/p/nt/seqid/v0"
	"gno.land/p/nt/urequire/v0"
)

// The stdlib avl Get returns nil for an absent key, so the type assertion that
// follows every lookup cannot on its own tell "absent" from "present but wrong
// type". These stores are exported, so a same-realm write can put either one
// there. Absent is a normal answer; a wrong type is a bug, and stays loud.

func TestResourcesStoreRejectsAWrongTypedEntry(cur realm, t *testing.T) {
	r := NewResourcesStore()

	urequire.True(t, r.Get("absent") == nil,
		"an absent resource is a normal answer")

	r.Tree.Set("corrupt", "not a resource")
	urequire.PanicsWithMessage(t, cur,
		"a value of ResourcesStore.Tree is not a *Resource, should not happen",
		func() { r.Get("corrupt") })
}

func TestProposalsStoreRejectsAWrongTypedEntry(cur realm, t *testing.T) {
	p := NewProposalsStore()

	urequire.True(t, p.GetProposal(1) == nil,
		"an absent proposal is a normal answer")

	// The key GetProposal derives for id 1.
	p.Tree.Set(seqid.ID(1).String(), "not a proposal")
	urequire.PanicsWithMessage(t, cur,
		"a value of ProposalsStore.Tree is not a *Proposal, should not happen",
		func() { p.GetProposal(1) })
}

func TestExtensionsStoreRejectsAWrongTypedEntry(cur realm, t *testing.T) {
	es := &ExtensionsStore{}

	_, ok := es.Get("absent")
	urequire.False(t, ok, "an absent extension is a normal answer")

	es.Tree.Set("corrupt", "not an extension")
	urequire.PanicsWithMessage(t, cur,
		"a value of ExtensionsStore.Tree is not an Extension, should not happen",
		func() { es.Get("corrupt") })
}
