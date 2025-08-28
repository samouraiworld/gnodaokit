package basedao

import (
	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/md"
)

func (d *DAOPrivate) ProposalsPageView(path string) string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	proposals := d.Core.Proposals.GetActiveProposals()

	s := ""
	s += ufmt.Sprintf("## Active Proposals 🗳️ (%d)\n\n", proposals.Tree.Size())
	s += d.RenderProposalsTable(path, proposals)
	s += ufmt.Sprintf("\n--------------------------------\n")
	s += md.Link("> Go to the Proposals history 📜", ufmt.Sprintf("%s:%s", linkPath, PROPOSAL_HISTORY_PATH)) + "\n\n"
	s += md.Link("Add a new proposal 🗳️", ufmt.Sprintf("%s$help", linkPath)) + "\n\n"
	return s
}
