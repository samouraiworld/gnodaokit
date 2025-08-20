package simple_dao

import (
	"std"
	"strings"
	"unicode"

	"gno.land/p/demo/ufmt"
	"gno.land/p/mason/md"
	"gno.land/p/moul/txlink"
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daokit"
)

// initProposals creates initial proposals (25 * "Add member" by two different proposers)
func initProposals() {
	for i := 1; i <= 25; i++ {
		addr := ufmt.Sprintf("g1member%02dxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", i)
		truncatedAddr := ufmt.Sprintf("g1member%02d...", i)
		req := daokit.ProposalRequest{
			Title: ufmt.Sprintf("Add member %s with no role", truncatedAddr),
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
		daoPrivate.Core.Propose(proposer, req)
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
//   - roles: Comma-separated string of roles to assign to the member (e.g., "admin,moderator" or "voter")
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
	s += "Welcome to the Simple DAO! This is a demonstration of basic DAO functionality using the **gno.land** ecosystem.\n\n"
	s += "## ℹ️ How it Works\n\n"
	s += "1. **Join the DAO** using the " + md.Link("AddMember", txlink.Call("AddMember")) + " function.\n\n"
	s += "2. **Create a pre-made Proposal** using " + md.Link("ProposeAddMember", txlink.Call("")) + "  function using this parameters:\n\n"
	s += "- `address`: The std.Address of the member to add\n"
	s += "- `roles`: Comma-separated roles (e.g., \"admin,moderator\" or \"voter\")\n\n"
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
