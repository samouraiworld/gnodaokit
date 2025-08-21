package custom_condition

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
// See why a run is necessary for creating a proposal -> https://docs.gno.land/users/interact-with-gnokey#run.
// Parameters:
//   - address: The std.Address of the member to be added
//   - roles: Comma-separated string of roles to assign to the member (e.g., "admin,moderator" or "voter")
func ProposeAddMember(cur realm, address std.Address, roles string) {
	rs := strings.Split(roles, ",")
	for i, s := range rs {
		rs[i] = strings.TrimFunc(s, unicode.IsSpace)
	}

	payload := basedao.ActionAddMember{
		Address: address,
		Roles:   rs,
	}
	action := basedao.NewAddMemberAction(&payload)

	proposal := daokit.ProposalRequest{
		Title:       ufmt.Sprintf("Add member %s with roles %s", address, strings.Join(rs, ", ")),
		Description: ufmt.Sprintf("This proposal will add %s as a member with roles: %s", address, strings.Join(rs, ", ")),
		Action:      action,
	}

	Propose(cur, proposal)
}

func renderDemo() string {
	s := ""
	s += "# ⚙️ Custom Condition Demo\n\n"
	s += "This showcases how to create custom governance rules.\n\n"
	s += "## ℹ️ How it Works\n\n"
	s += "1. **Join the DAO** using the " + md.Link("AddMember", txlink.Call("AddMember")) + " function.\n\n"
	s += "2. **Create a Proposal** using " + md.Link("ProposeAddMember", txlink.Call("ProposeAddMember")) + " function with these parameters:\n\n"
	s += "- `address`: The std.Address of the member to add\n"
	s += "- `roles`: Comma-separated roles (e.g., \"admin,moderator\" or \"voter\")\n\n"
	s += "3. " + md.Link("Vote", txlink.Call("Vote")) + " on proposals using their ID.\n\n"
	s += "## 🎯 Custom Condition: NoRole\n\n"
	s += "This DAO uses a custom condition called **NoRole** that requires:\n"
	s += "- At least **1 vote** from members who have **no assigned roles**\n"
	s += "- Only votes from roleless members count toward approval\n"
	s += "- Members with roles cannot approve proposals\n\n"
	s += "## 📋 Available Actions\n\n"
	s += "### Member Management\n"
	s += "- " + md.Link("🔗 Add Yourself as Member", txlink.Call("AddMember")) + " - Join the DAO to participate in governance\n"
	s += "- " + md.Link("🔗 Propose Add Member", txlink.Call("ProposeAddMember")) + " - Create a proposal to add a new member with specific roles\n\n"
	s += "### Other Demos\n"
	s += "- " + md.Link("🔗 Simple DAO Demo", "/r/samcrew/daodemo/simple_dao") + " - Basic DAO functionality\n"
	s += "- " + md.Link("🔗 Custom Resource Demo", "/r/samcrew/daodemo/custom_resource") + " - Custom DAO actions\n\n"
	s += "*This is a demonstration DAO built with gno.land and daokit*"
	return s
}
