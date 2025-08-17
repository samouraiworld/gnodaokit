package basedao

import (
	"gno.land/p/demo/avl/pager"
	"gno.land/p/demo/seqid"
	"gno.land/p/demo/ufmt"
	"gno.land/p/samcrew/daokit"
)

// TEMPORARY UTILITARY
func truncateMiddle(s string, max int) string {
	runes := []rune(s)
	if len(runes) <= max {
		return s
	}
	if max <= 3 {
		return string(runes[:max])
	}
	half := (max - 3) / 2
	return string(runes[:half]) + "..." + string(runes[len(runes)-half:])
}

func displayAddressMD(addr string) string {
	return "[" + truncateMiddle(addr, 16) + "](/u/" + addr + ")"
}

///////////////

func (d *DAOPrivate) ProposalsPageView(path string) string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	s := ""
	proposalsCount := d.Core.Proposals.Tree.Size()

	const pageSize = 10
	pager := pager.NewPager(d.Core.Proposals.Tree, pageSize, false)
	page := pager.MustGetPageByPath(path)

	s += ufmt.Sprintf("## Proposals 🗳️ (%d)\n\n", proposalsCount)
	s += ufmt.Sprintf("| **ID** | **Title** | **Action** | **Proposer** | **CreatedAt** | **Status** |\n")
	s += ufmt.Sprintf("|-----|-------------|---------|--------------|-------------|--------|\n")

	if proposalsCount == 0 {
		s += ufmt.Sprintf("\t⚠️ There are no running proposals at the moment\n\n")
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
		s += ufmt.Sprintf("| %d | [%s](%s:%s/%d) | %s | %s | %s | %s |\n",
			uint64(id),
			proposal.Title, linkPath, "proposal", uint64(id),
			proposal.Action.Type(),
			displayAddressMD(proposal.ProposerID),
			proposal.CreatedAt.Format("2006-01-02 15:04:05"),
			proposal.Status.String())
	}

	s += "\n" + page.Picker(path) + "\n"
	s += ufmt.Sprintf("> See the [proposal history 📜](%s:%s) for more information\n\n", linkPath, PROPOSAL_HISTORY_PATH)
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}
