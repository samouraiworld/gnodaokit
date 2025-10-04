package custom_resource

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/demo/profile"
)

var (
	DAO        daokit.DAO
	localDAO   daokit.DAO
	daoPrivate *basedao.DAOPrivate
	myblog     Blog
)

func init() {
	initialRoles := []basedao.RoleInfo{
		{Name: "Role", Description: "Has a role", Color: "#329175"},
	}
	initialMembers := []basedao.Member{
		{Address: "g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh", Roles: []string{}},
		{Address: "g1q87ppukjx8mp7n70fal8ept6ajwr0dttafld65", Roles: []string{}},
		{Address: "g1q87ppukjx8mp7n70fal8ept6ajwr0dttafld64", Roles: []string{}},
		{Address: "g1q87ppukjx8mp7n70fal8ept6ajwr0dttafld69", Roles: []string{}},
	}
	memberStore := basedao.NewMembersStore(initialRoles, initialMembers)
	membersMajority := daocond.MembersThreshold(0.1, memberStore.IsMember, memberStore.MembersCount)

	localDAO, daoPrivate = basedao.New(&basedao.Config{
		Name:             "Demo DAOKIT DAO",
		Description:      "This is a demo DAO built with DAOKIT",
		Members:          memberStore,
		InitialCondition: membersMajority,
		GetProfileString: profile.GetStringField,
		SetProfileString: profile.SetStringField,
		RenderFn: func(path string, dao *basedao.DAOPrivate) string {
			s := ""
			if path == "" {
				s += renderDemo()
			}
			s += " \n\n--- \n\n "
			s += dao.RenderRouter.Render(path)
			s += "# My blog\n"
			s += myblog.Render()
			return s
		},
		SetImplemFn: func(implem daokit.DAO) {
			localDAO = implem
			DAO = daokit.NewCrossing(implem, crossFn)
		},
	})
	DAO = daokit.NewCrossing(localDAO, crossFn)

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

// Vote allows DAO members to cast their vote on a specific proposal
func Vote(cur realm, proposalID uint64, vote daocond.Vote) {
	localDAO.Vote(proposalID, vote)
}

// Execute triggers the implementation of a proposal's actions
func Execute(cur realm, proposalID uint64) {
	localDAO.Execute(proposalID)
}

// Propose creates a new proposal
// To execute this function, you must use a MsgRun (maketx run)
// See why it is necessary in Gno Documentation: https://docs.gno.land/users/interact-with-gnokey#run
func Propose(cur realm, req daokit.ProposalRequest) {
	localDAO.Propose(req)
}

// Render generates a UI representation of the DAO's state
func Render(path string) string {
	return localDAO.Render(path)
}

func crossFn(_ realm, cb func()) {
	cb()
}
