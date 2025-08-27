package simple_dao

import (
	"std"
	"strings"
	"unicode"

	"gno.land/p/demo/ufmt"
	"gno.land/p/mason/md"
	"gno.land/p/moul/txlink"
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
)

// initProposals creates initial proposals ("Add member").
// Takes the number of proposals to create and uses the last created address as proposer.
// It creates 4 types of proposals in equal parts:
// - Add member with no role
// - Remove member
// - Assign role
// - Edit profile
// Each proposal gets votes: first third "No", second third "Yes", last third "Abstain".
func initProposals(nb int) {
	baseOffset := nb / 4
	offsetAddMember := baseOffset
	offsetRemoveMember := offsetAddMember + baseOffset
	offsetAssignRole := offsetRemoveMember + baseOffset
	offsetEditProfile := nb

	idsAddMember := make([]uint64, 0, baseOffset)
	idsRemoveMember := make([]uint64, 0, baseOffset)
	idsAssignRole := make([]uint64, 0, baseOffset)
	idsEditProfile := make([]uint64, 0, nb-offsetAssignRole)

	var lastAddr string = "g126gx6p6d3da4ymef35ury6874j6kys044r7zlg"
	var addr string

	for i := 0; i < offsetAddMember; i++ {
		addr = ufmt.Sprintf("g1memberxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx%02d", i)
		req := daokit.ProposalRequest{
			Title: ufmt.Sprintf("Add member %s with no role", basedao.TruncateMiddle(addr)),
			Action: basedao.NewAddMemberAction(&basedao.ActionAddMember{
				Address: std.Address(addr),
				Roles:   []string{},
			}),
			Description: "Random description",
		}
		id := daoPrivate.Core.Propose(lastAddr, req)
		idsAddMember = append(idsAddMember, id)
		lastAddr = addr
	}

	for i := offsetAddMember; i < offsetRemoveMember; i++ {
		addr = ufmt.Sprintf("g1memberxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx%02d", i)
		req := daokit.ProposalRequest{
			Title:       ufmt.Sprintf("Remove member %s", basedao.TruncateMiddle(addr)),
			Action:      basedao.NewRemoveMemberAction(std.Address(addr)),
			Description: "Random description",
		}
		id := daoPrivate.Core.Propose(lastAddr, req)
		idsRemoveMember = append(idsRemoveMember, id)
		lastAddr = addr
	}

	for i := offsetRemoveMember; i < offsetAssignRole; i++ {
		addr = ufmt.Sprintf("g1memberxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx%02d", i)
		role := "public-relationships"
		req := daokit.ProposalRequest{
			Title: ufmt.Sprintf("Assign role %s for %s", role, basedao.TruncateMiddle(addr)),
			Action: basedao.NewAssignRoleAction(&basedao.ActionAssignRole{
				Address: std.Address(addr),
				Role:    role,
			}),
			Description: "Random description",
		}
		id := daoPrivate.Core.Propose(lastAddr, req)
		idsAssignRole = append(idsAssignRole, id)
		lastAddr = addr
	}

	for i := offsetAssignRole; i < offsetEditProfile; i++ {
		addr = ufmt.Sprintf("g1memberxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx%02d", i)
		req := daokit.ProposalRequest{
			Title:       ufmt.Sprintf("Edit profile for %s", basedao.TruncateMiddle(addr)),
			Action:      basedao.NewEditProfileAction([2]string{"Name", "Johnny Doey"}),
			Description: "Random description",
		}
		id := daoPrivate.Core.Propose(lastAddr, req)
		idsEditProfile = append(idsEditProfile, id)
		lastAddr = addr
	}

	initVotes(idsAddMember)
	initVotes(idsRemoveMember)
	initVotes(idsAssignRole)
	initVotes(idsEditProfile)
}

// initVotes casts votes on a list of proposal IDs.
// It votes "No" on the first third, "Yes" on the second third, and "Abstain" on the last third.
func initVotes(ids []uint64) {
	n := len(ids)
	third := n / 3
	endNo := third
	endYes := 2 * third
	endAbstain := n

	for i := 0; i < endNo; i++ {
		daoPrivate.Core.Vote("g126gx6p6d3da4ymef35ury6874j6kys044r7zlg", ids[i], daocond.VoteNo)
	}
	for i := endNo; i < endYes; i++ {
		daoPrivate.Core.Vote("g126gx6p6d3da4ymef35ury6874j6kys044r7zlg", ids[i], daocond.VoteYes)
	}
	for i := endYes; i < endAbstain; i++ {
		daoPrivate.Core.Vote("g126gx6p6d3da4ymef35ury6874j6kys044r7zlg", ids[i], daocond.VoteAbstain)
	}
}

// Bypass limitation by adding yourself to the DAO.
// It is necessary to be part of the DAO to create a Proposal.
func AddMember(cur realm) {
	addr := std.PreviousRealm().Address().String()
	daoPrivate.Members.AddMember(addr, make([]string, 0))
}

// Creates a Proposal to add a new member to the DAO with specified roles.
// This function exist to let users try the userflow of daokit with a simple MsgCall (maketx call) instead of a MsgRun.
// See why a run is necessary for creating a proposal -> https://docs.gno.land/users/interact-with-gnokey#run.
// Parameters:
//   - address: The std.Address of the member to be added
//   - roles: Comma-separated roles (e.g., "public-relationships,finance-officer" or "finance-officer")
func ProposeAddMember(cur realm, address std.Address, roles string) {
	rs := strings.Split(roles, ",")
	for i, s := range rs {
		rs[i] = strings.TrimFunc(s, unicode.IsSpace)
	}
	req := daokit.ProposalRequest{
		Title: ufmt.Sprintf("Add member %s with roles %s", address, strings.Join(rs, ", ")),
		Action: basedao.NewAddMemberAction(&basedao.ActionAddMember{
			Address: address,
			Roles:   rs,
		}),
	}
	Propose(cur, req)
}

func renderDemo() string {
	s := ""
	s += "# 🏛️ Simple DAO Actions\n\n"
	s += "Welcome to Simple DAO! This is a demonstration of basic DAO functionality.\n\n"
	s += "## ℹ️ How it Works\n\n"
	s += "1. **Join the DAO** using the " + md.Link("AddMember", txlink.Call("AddMember")) + " function.\n\n"
	s += "2. **Create a pre-made Proposal** using " + md.Link("ProposeAddMember", txlink.Call("ProposeAddMember")) + "  function using this parameters:\n\n"
	s += "- `address`: The std.Address of the member to add\n"
	s += "- `roles`: Comma-separated roles (e.g., \"public-relationships,finance-officer\" or \"finance-officer\")\n\n"
	s += "3. " + md.Link("Vote", txlink.Call("Vote")) + " on proposals using their ID.\n\n"
	s += "## 📋 Available Actions\n\n"
	s += "### Member Management\n"
	s += "- " + md.Link("🔗 Add Yourself as Member", txlink.Call("AddMember")) + " - Join the DAO to participate in governance\n"
	s += "- " + md.Link("🔗 Propose Add Member", txlink.Call("ProposeAddMember")) + " - Create a proposal to add a new member with specific roles\n\n"
	s += "## 🛠️ Custom Resource & Condition Demo\n\n"
	s += "Explore how to extend your DAO with custom resources and conditions:\n\n"
	s += "- " + md.Link("🔗 Custom Resource Example", "/r/samcrew/daodemo/custom_resource") + " - See a demo of custom resource implementation\n"
	s += "- " + md.Link("🔗 Custom Condition Example", "/r/samcrew/daodemo/custom_condition") + " - See a demo of custom condition implementation\n\n"
	s += "*This is a demonstration DAO built with gno.land and daokit*"
	return s
}
