package basedao

import (
	"gno.land/p/demo/avl/pager"
	"gno.land/p/demo/seqid"
	"gno.land/p/demo/ufmt"
	"gno.land/p/samcrew/daokit"
)

func (d *DAOPrivate) ProposalsPageView(path string) string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	s := ""
	proposalsCount := d.Core.ProposalsCount()

	const pageSize = 10
	pager := pager.NewPager(d.Core.Proposals.Tree, pageSize, true)
	page := pager.MustGetPageByPath(path)

	s += ufmt.Sprintf("## Proposals 🗳️ (%d)\n\n", proposalsCount)

	if proposalsCount == 0 {
		s += ufmt.Sprintf("\t⚠️ There are no running proposals at the moment\n\n")
	} else {
		s += ufmt.Sprintf("| **ID** | **Title** | **Resource** | **Proposer** | **CreatedAt** | **Status** |\n")
		s += ufmt.Sprintf("|--------|-----------|--------------|--------------|---------------|------------|\n")
	}

	for _, item := range page.Items {
		proposal := item.Value.(*daokit.Proposal)
		key := item.Key

		if proposal.Status != daokit.ProposalStatusOpen {
			continue
		}
		id, err := seqid.FromString(key)
		if err != nil {
			panic(err)
		}
		resource := d.Core.Resources.Get(proposal.Action.Type())
		s += ufmt.Sprintf("| %d | [%s](%s:%s/%d) | %s | %s | %s | %s |\n",
			uint64(id),
			proposal.Title, linkPath, "proposal", uint64(id),
			resource.DisplayName,
			RenderAddressLink(proposal.ProposerID),
			FormatDateTimeWithUTCOffset(proposal.CreatedAt),
			proposal.Status.String())
	}

	s += "\n" + page.Picker(path) + "\n"
	s += ufmt.Sprintf("> See the [proposal history 📜](%s:%s) for more information\n\n", linkPath, PROPOSAL_HISTORY_PATH)
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}
