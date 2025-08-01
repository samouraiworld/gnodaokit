package main

import (
	"gno.land/p/samcrew/daokit"
	"gno.land/r/samcrew/daodemo/custom_resource"
)

func main() {
	// Calling the custom action
	action := custom_resource.NewPostAction("hello", "world")

	proposal := daokit.ProposalRequest{
		Title:       "Sample Proposal",
		Description: "This is a sample proposal using PrintAction.",
		Action:      action,
	}
	custom_resource.Propose(proposal)
}
