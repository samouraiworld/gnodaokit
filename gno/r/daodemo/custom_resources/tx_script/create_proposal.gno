package main

import (
	"gno.land/p/samourai/daokit"
	"gno.land/r/samourai/daodemo/custom_resources"
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
