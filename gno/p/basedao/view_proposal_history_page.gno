package basedao

import (
	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/md"
)

func (d *DAOPrivate) ProposalHistoryPageView(path string) string {
	return d.ProposalHistoryHeaderView() +
		d.ProposalHistoryView(path)
}

func (d *DAOPrivate) ProposalHistoryHeaderView() string {
	name := d.GetProfileString(d.Realm.Address(), "DisplayName", "DAO")
	s := ""
	s += ufmt.Sprintf("# %s - Proposal History\n\n", name)
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}

func (d *DAOPrivate) ProposalHistoryView(path string) string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	proposals := d.Core.Proposals.GetInactiveProposals()

	s := ""
	s += ufmt.Sprintf("## Inactive Proposals 🗳️ (%d)\n\n", proposals.Tree.Size())
	s += d.RenderProposalsTable(path, proposals)
	s += ufmt.Sprintf("\n--------------------------------\n")
	s += md.Link("> Go to the active Proposals 📃", ufmt.Sprintf("%s:%s", linkPath, PROPOSALS_PATH)) + "\n\n"
	s += md.Link("Add a new proposal 🗳️", ufmt.Sprintf("%s$help", linkPath)) + "\n\n"

	return s
}
