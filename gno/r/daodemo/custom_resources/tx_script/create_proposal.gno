package main

import (
	"gno.land/p/samcrew/daokit"
	"gno.land/r/samcrew/daodemo/custom_resources"
)

func main() {
	// Calling the custom action
	action := custom_resources.NewPostAction("hello", "world")

	proposal := daokit.ProposalRequest{
		Title:       "Sample Proposal",
		Description: "This is a sample proposal using PrintAction.",
		Action:      action,
	}
	custom_resources.Propose(proposal)
}
