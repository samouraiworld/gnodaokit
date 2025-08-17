package basedao

import (
	"gno.land/p/demo/seqid"
	"gno.land/p/demo/ufmt"
	"gno.land/p/samcrew/daokit"
)

func (d *DAOPrivate) ProposalDetailPageView(idu uint64) string {
	return d.ProposalDetailHeaderView() +
		d.ProposalDetailView(idu)
}

func (d *DAOPrivate) ProposalDetailHeaderView() string {
	name := d.GetProfileString(d.Realm.Address(), "DisplayName", "DAO")
	s := ""
	s += ufmt.Sprintf("# %s - Proposal Detail\n\n", name)
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}

func (d *DAOPrivate) ProposalDetailView(idu uint64) string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	id := seqid.ID(idu)
	proposal := d.Core.Proposals.GetProposal(uint64(id))
	s := ""
	s += ufmt.Sprintf("## Title - %s 📜\n\n", proposal.Title)
	s += ufmt.Sprintf("## Description 📝\n\n%s\n\n", proposal.Description)
	s += ufmt.Sprintf("## Resource - %s 📦\n\n", proposal.Action.Type())
	resource := d.Core.Resources.Get(proposal.Action.Type())
	s += ufmt.Sprintf("  - **Name:** %s\n", resource.DisplayName)
	s += ufmt.Sprintf("  - **Description:** %s\n", resource.Description)
	s += ufmt.Sprintf("  - **Condition:** %s\n\n", resource.Condition.Render())
	s += ("---\n\n")
	s += proposal.Action.String() + "\n\n"
	s += ("---\n\n")
	if proposal.Status == daokit.ProposalStatusOpen {
		s += ufmt.Sprintf("## Status - Open 🟡\n\n")
		s += ufmt.Sprintf("[Vote on this proposal 🗳️](%s$help)\n\n", linkPath)
	} else if proposal.Status == daokit.ProposalStatusPassed {
		s += ufmt.Sprintf("## Status - Passed 🟢\n\n")
		s += ufmt.Sprintf("[Execute this proposal 🗳️](%s$help)\n\n", linkPath)
	} else if proposal.Status == daokit.ProposalStatusExecuted {
		s += ufmt.Sprintf("## Status - Executed ✅\n\n")
	} else {
		s += ufmt.Sprintf("## Status - Closed 🔴\n\n")
	}
	s += ufmt.Sprintf("> proposed by %s 👤\n\n", proposal.ProposerID)
	s += ufmt.Sprintf("\n--------------------------------\n")
	s += ufmt.Sprintf("## Votes 🗳️\n\n%s\n\n", proposal.Condition.RenderWithVotes(proposal.Ballot))
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}
