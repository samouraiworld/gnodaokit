package main

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/samcrew/daodemo/custom_condition"
)

func main() {
	payload := basedao.ActionAddMember{
		Address: "g1j9zh3ce7a5tg2esjzherfrx7m3n842k2vmj395",
		Roles:   []string{},
	}
	action := basedao.NewAddMemberAction(&payload)

	proposal := daokit.ProposalRequest{
		Title:       "Adding new member",
		Description: "Adding new member with no role",
		Action:      action,
	}

	custom_condition.Propose(proposal)
}
