package basedao

import (
	"strings"
	"testing"

	"gno.land/p/nt/urequire/v0"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
)

// Rendering shows the status the votes imply, and changes nothing.
//
// The read paths used to write: a proposal that had met its condition was moved
// Open -> Passed as a side effect of being displayed, which then made it
// permanently unexecutable. They now compute the display status instead, and
// nothing outside Execute ever writes Status — so a stored proposal is Open
// until it is Executed, and Passed exists only as something rendered.
func TestRenderingShowsTheStatusTheVotesImplyAndWritesNothing(cur realm, t *testing.T) {
	members := []Member{
		{alice.String(), []string{"admin"}},
		{bob.String(), []string{}},
		{carol.String(), []string{}},
	}
	tdao := newTestingDAO(cur, t, 0.2, members)

	// Untouched.
	openID := tdao.dao.Propose(tdao.mockProposalRequest, cur)
	// Enough votes to meet the condition, but never executed.
	passedID := tdao.dao.Propose(tdao.mockProposalRequest, cur)
	tdao.dao.Vote(passedID, daocond.VoteYes, cur)
	// Executed.
	executedID := tdao.dao.Propose(tdao.mockProposalRequest, cur)
	tdao.dao.Vote(executedID, daocond.VoteYes, cur)
	tdao.dao.Execute(executedID, cur)

	store := tdao.privdao.Core.Proposals
	get := func(id uint64) *daokit.Proposal { return store.GetProposal(id) }

	// Stored status: only Execute ever wrote one.
	urequire.Equal(t, daokit.ProposalStatusOpen.String(), get(openID).Status.String())
	urequire.Equal(t, daokit.ProposalStatusOpen.String(), get(passedID).Status.String(),
		"meeting the condition must not have written anything")
	urequire.Equal(t, daokit.ProposalStatusExecuted.String(), get(executedID).Status.String())

	// Rendered status: what the votes imply.
	table := tdao.privdao.RenderProposalsTable("", store)
	urequire.True(t, strings.Contains(table, "Passed"),
		"a condition-met proposal must render as Passed")
	urequire.True(t, strings.Contains(table, "Executed"),
		"an executed proposal must render as Executed")
	urequire.True(t, strings.Contains(table, "Open"),
		"an untouched proposal must render as Open")

	// And rendering still wrote nothing.
	urequire.Equal(t, daokit.ProposalStatusOpen.String(), get(passedID).Status.String(),
		"rendering must not have moved the condition-met proposal")

	// The JSON view agrees.
	js := store.GetProposalsJSON()
	urequire.True(t, strings.Contains(js, `"Passed"`), "JSON must show Passed")
	urequire.True(t, strings.Contains(js, `"Executed"`), "JSON must show Executed")

	// The active/history split follows the rendered status, not the stored one.
	active := tdao.privdao.ProposalsView("")
	history := tdao.privdao.ProposalHistoryView("")
	urequire.False(t, strings.Contains(history, "Open"),
		"an open proposal does not belong in history")
	urequire.True(t, strings.Contains(active, "Passed"),
		"a condition-met proposal is still active until executed")
	urequire.True(t, strings.Contains(history, "Executed"),
		"an executed proposal belongs in history")
}
