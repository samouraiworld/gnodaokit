package custom_resource

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/demo/profile"
)

var (
	DAO        daokit.DAO
	daoPrivate *basedao.DAOPrivate
	myblog     Blog
)

func init() {
	initialRoles := []basedao.RoleInfo{
		{Name: "Role", Description: "Has a role"},
	}
	initialMembers := []basedao.Member{
		{Address: "g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh", Roles: []string{}},
		{Address: "g1q87ppukjx8mp7n70fal8ept6ajwr0dttafld65", Roles: []string{}},
		{Address: "g1q87ppukjx8mp7n70fal8ept6ajwr0dttafld64", Roles: []string{}},
		{Address: "g1q87ppukjx8mp7n70fal8ept6ajwr0dttafld69", Roles: []string{}},
	}
	memberStore := basedao.NewMembersStore(initialRoles, initialMembers)
	membersMajority := daocond.MembersThreshold(0.1, memberStore.IsMember, memberStore.MembersCount)

	DAO, daoPrivate = basedao.New(&basedao.Config{
		Name:             "Demo DAOKIT DAO",
		Description:      "This is a demo DAO built with DAOKIT",
		Members:          memberStore,
		InitialCondition: membersMajority,
		GetProfileString: profile.GetStringField,
		SetProfileString: profile.SetStringField,
	})

	// Create a new custom resource
	resource := daokit.Resource{
		Handler:     NewPostHandler(&myblog),
		Condition:   membersMajority,
		DisplayName: "Hello",
		Description: "Description",
	}
	// Add it to our DAO
	daoPrivate.Core.Resources.Set(&resource)

	// Add some demo blog post proposals to showcase custom resource
	initBlogProposals()
}

func Vote(cur realm, proposalID uint64, vote daocond.Vote) {
	DAO.Vote(proposalID, vote)
}

func Execute(cur realm, proposalID uint64) {
	DAO.Execute(proposalID)
}

func Propose(cur realm, req daokit.ProposalRequest) {
	DAO.Propose(req)
}

func Render(path string) string {
	if path == "demo" {
		return renderDemo()
	}
	s := daoPrivate.Render(path)
	s += "# My blog\n"
	s += myblog.Render()
	return s
}
