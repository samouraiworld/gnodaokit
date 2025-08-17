package basedao

import (
	"gno.land/p/demo/seqid"
	"gno.land/p/demo/ufmt"
	"gno.land/p/samcrew/daokit"
)

func (d *DAOPrivate) ProposalHistoryPageView() string {
	return d.ProposalHistoryHeaderView() +
		d.ProposalHistoryView()
}

func (d *DAOPrivate) ProposalHistoryHeaderView() string {
	name := d.GetProfileString(d.Realm.Address(), "DisplayName", "DAO")
	s := ""
	s += ufmt.Sprintf("# %s - Proposal History\n\n", name)
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}

func (d *DAOPrivate) ProposalHistoryView() string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	s := ""
	s += ufmt.Sprintf("## Proposals 🗳️\n\n")
	i := 1
	d.Core.Proposals.Tree.Iterate("", "", func(key string, value interface{}) bool {
		proposal, ok := value.(*daokit.Proposal)
		if !ok {
			panic("unexpected invalid proposal type")
		}
		id, err := seqid.FromString(key)
		if err != nil {
			panic(err)
		}
		s += ufmt.Sprintf("- **Proposal %d: [%s](%s:%s/%d) - %s**\n\n", uint64(id), proposal.Title, linkPath, "proposal", uint64(id), proposal.Status)
		i += 1
		return false
	})
	s += ufmt.Sprintf("[Add a new proposal 🗳️](%s$help)\n\n", linkPath)
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}
