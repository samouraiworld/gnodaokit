package simple_dao

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
)

// initProposals creates initial proposals (25 * "Add member" by two different proposers)
func initProposals() {
	for i := 1; i <= 25; i++ {
		addr := ufmt.Sprintf("g1memberxxxxxxxxxxxxxxxxxxxxxxxxxxxx%02d", i)
		req := daokit.ProposalRequest{
			Title: ufmt.Sprintf("Add member %s with no role", basedao.TruncateMiddle(addr)),
			Action: basedao.NewAddMemberAction(&basedao.ActionAddMember{
				Address: std.Address(addr),
				Roles:   []string{},
			}),
		}
		var proposer string
		if i <= 12 {
			proposer = "g126gx6p6d3da4ymef35ury6874j6kys044r7zlg"
		} else {
			proposer = "g1ld6uaykyugld4rnm63rcy7vju4zx23lufml3jv"
		}
		id := daoPrivate.Core.Propose(proposer, req)
		daoPrivate.Core.Vote(proposer, id, daocond.VoteYes)
	}
}
