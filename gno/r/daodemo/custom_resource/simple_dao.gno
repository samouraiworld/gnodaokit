package custom_resource

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/demo/profile"
)

var (
	DAO        daokit.CrossingDAO
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

	var dao daokit.DAO
	dao, daoPrivate = basedao.New(&basedao.Config{
		Name:             "Demo DAOKIT DAO",
		Description:      "This is a demo DAO built with DAOKIT",
		Members:          memberStore,
		InitialCondition: membersMajority,
		GetProfileString: profile.GetStringField,
		SetProfileString: profile.SetStringField,
	})
	DAO = &crossingDAOWrapper{dao: dao}

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
	DAO.Vote(cur, proposalID, vote)
}

func Execute(cur realm, proposalID uint64) {
	DAO.Execute(cur, proposalID)
}

func Propose(cur realm, req daokit.ProposalRequest) {
	DAO.Propose(cur, req)
}

func Render(path string) string {
	s := ""
	if path == "" {
		s += renderDemo()
	}
	s += " \n\n--- \n\n "
	s += daoPrivate.Render(path)
	s += "# My blog\n"
	s += myblog.Render()
	return s
}

type crossingDAOWrapper struct {
	dao daokit.DAO
}

// Execute implements CrossingDAO.
func (c *crossingDAOWrapper) Execute(cur realm, id uint64) {
	c.dao.Execute(id)
}

// Propose implements CrossingDAO.
func (c *crossingDAOWrapper) Propose(cur realm, req daokit.ProposalRequest) uint64 {
	return c.dao.Propose(req)
}

// Vote implements CrossingDAO.
func (c *crossingDAOWrapper) Vote(cur realm, id uint64, vote daocond.Vote) {
	c.dao.Vote(id, vote)
}
