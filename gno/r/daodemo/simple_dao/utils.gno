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

// Bypass limitation by adding yourself to the DAO.
// It is necessary to be part of the DAO to create a Proposal.
func AddMember(cur realm) {
	addr := std.PreviousRealm().Address().String()
	daoPrivate.Members.AddMember(addr, make([]string, 0))
}

// Creates a Proposal to add a new member to the DAO with specified roles.
// This function exist to let users try the userflow of daokit with a simple MsgCall (maketx call) instead of a MsgRun.
// See why a run is necessary for creating a proposal -> [link to docs].
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

func renderActions() string {
	s := ""
	s += "# 🏛️ Simple DAO Actions\n\n"
	s += "Welcome to the Simple DAO! This is a demonstration of basic DAO functionality using the gno.land ecosystem.\n\n"
	s += "## ℹ️ How it Works\n\n"
	s += "1. **Join the DAO**: First, add yourself as a member using the AddMember function\n"
	s += "Click " + md.Link("Add Yourself as Member", txlink.Call("AddMember")) + " to become a member of the DAO.\n\n"
	s += "2. **Create Proposals**: Once you're a member, you can create your Proposal, as ProposeAddMember\n"
	s += "Use " + md.Link("Propose Add Member", txlink.Call("ProposeAddMember")) + " with parameters:\n"
	s += "- `address`: The std.Address of the member to add\n"
	s += "- `roles`: Comma-separated roles (e.g., \"admin,moderator\" or \"voter\")\n\n"
	s += "3. **Voting**: Members can vote on proposals to govern the DAO\n\n"
	s += md.Link("Vote", txlink.Call("Vote")) + "on your Proposal using its ID.\n\n"
	s += "## 📋 Available Actions\n\n"
	s += "### Member Management\n"
	s += "- " + md.Link("🔗 Add Yourself as Member", txlink.Call("AddMember")) + " - Join the DAO to participate in governance\n"
	s += "- " + md.Link("🔗 Propose Add Member", txlink.Call("ProposeAddMember")) + " - Create a proposal to add a new member with specific roles\n\n"
	s += "*This is a demonstration DAO built with gno.land and daokit*"
	return s
}
