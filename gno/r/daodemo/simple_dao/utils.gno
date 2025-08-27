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

const financeOfficer = "g126gx6p6d3da4ymef35ury6874j6kys044r7zlg"

// initProposals creates a number of initial proposals and votes.
// It divides the proposals into four parts: AddMember, RemoveMember, AssignRole, EditProfile.
// It initializes votes for each proposal type.
func initProposals(nb int) {
	q := nb / 4
	offsets := []int{0, q, 2 * q, 3 * q, nb} // AddMember, Remove, AssignRole, EditProfile

	lastAddr := financeOfficer

	for t, start := range offsets[:4] {
		end := offsets[t+1]
		for i := start; i < end; i++ {
			addr := ufmt.Sprintf("g1memberxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx%02d", i)
			var action daokit.Action
			var title string

			// CREATE
			switch t {
			case 0: // AddMember
				action = basedao.NewAddMemberAction(&basedao.ActionAddMember{Address: std.Address(addr), Roles: []string{}})
				title = ufmt.Sprintf("Add member %s with no role", basedao.TruncateMiddle(addr))
			case 1: // RemoveMember
				action = basedao.NewRemoveMemberAction(std.Address(addr))
				title = ufmt.Sprintf("Remove member %s", basedao.TruncateMiddle(addr))
			case 2: // AssignRole
				role := "public-relationships"
				action = basedao.NewAssignRoleAction(&basedao.ActionAssignRole{Address: std.Address(financeOfficer), Role: role})
				title = ufmt.Sprintf("Assign role %s for %s", role, basedao.TruncateMiddle(addr))
			case 3: // EditProfile
				action = basedao.NewEditProfileAction([2]string{"Bio", "Simple DAO to the moon!"})
				title = "Edit the DAO's profile"
			}
			req := daokit.ProposalRequest{
				Title:       title,
				Action:      action,
				Description: "Random description",
			}
			id := daoPrivate.Core.Propose(lastAddr, req)

			// VOTE
			quart := i * 4 / nb
			switch quart {
			case 0: // VoteNo
				daoPrivate.Core.Vote(financeOfficer, id, daocond.VoteNo)
			case 1: // VoteYes
				daoPrivate.Core.Vote(financeOfficer, id, daocond.VoteYes)
			case 2: // VoteAbstain
				daoPrivate.Core.Vote(financeOfficer, id, daocond.VoteAbstain)
			case 3: // VoteYes + Execute
				daoPrivate.Core.Vote(financeOfficer, id, daocond.VoteYes)
				daoPrivate.Core.Execute(id)
			}

			lastAddr = addr
		}
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
