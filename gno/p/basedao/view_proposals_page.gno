package basedao

import (
	"gno.land/p/demo/avl/pager"
	"gno.land/p/demo/seqid"
	"gno.land/p/demo/ufmt"
	"gno.land/p/samcrew/daokit"
	"gno.land/p/sunspirit/md"
	"gno.land/p/sunspirit/table"
)

func (d *DAOPrivate) ProposalsPageView(path string) string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	s := ""
	proposalsCount := d.Core.ProposalsCount()

	const pageSize = 10
	pager := pager.NewPager(d.Core.Proposals.Tree, pageSize, false)
	page := pager.MustGetPageByPath(path)

	s += ufmt.Sprintf("## Proposals 🗳️ (%d)\n\n", proposalsCount)

	if proposalsCount == 0 {
		s += ufmt.Sprintf("\t⚠️ There are no running proposals at the moment\n\n")
	}

	mdBuilder := md.NewBuilder()
	tb, _ := table.New([]string{"ID", "Title", "Resource", "Proposer", "CreatedAt", "Status"}, [][]string{})

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
		tb.AddRow([]string{
			ufmt.Sprintf("%d", uint64(id)),
			md.Link(proposal.Title, ufmt.Sprintf("%s:%s/%s", linkPath, "proposal", ufmt.Sprintf("%d", uint64(id)))),
			resource.DisplayName,
			RenderAddressLink(proposal.ProposerID),
			proposal.CreatedAt.Format("2006-01-02 15:04:05"),
			proposal.Status.String(),
		})
	}

	mdBuilder.Add(md.Table(tb))
	s += mdBuilder.Render("\n")
	s += "\n" + page.Picker(path) + "\n"
	s += ufmt.Sprintf("> See the [proposal history 📜](%s:%s) for more information\n\n", linkPath, PROPOSAL_HISTORY_PATH)
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}
