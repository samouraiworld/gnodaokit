package basedao

import (
	"gno.land/p/demo/seqid"
	"gno.land/p/demo/ufmt"
	"gno.land/p/samcrew/daokit"
)

func (d *DAOPrivate) ProposalsPageView(path string) string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	s := ""
	s += ufmt.Sprintf("## Proposals 🗳️ \n\n")
	i := 0
	d.Core.Proposals.Tree.Iterate("", "", func(key string, value interface{}) bool {
		proposal := value.(*daokit.Proposal)
		if proposal.Status != daokit.ProposalStatusOpen {
			return false
		}
		id, err := seqid.FromString(key)
		if err != nil {
			panic(err)
		}
		s += ufmt.Sprintf("- **Proposal %d: [%s](%s:%s/%d)**\n\n", uint64(id), proposal.Title, linkPath, "proposal", uint64(id))
		i += 1
		return false
	})
	if i == 0 {
		s += ufmt.Sprintf("\t⚠️ There are no running proposals at the moment\n\n")
	}
	s += ufmt.Sprintf("> See the [proposal history 📜](%s:%s) for more information\n\n", linkPath, PROPOSAL_HISTORY_PATH)
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}
