package custom_condition

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/demo/profile"
)

var (
	DAO        daokit.CrossingDAO
	daoPrivate *basedao.DAOPrivate
)

func init() {
	initialRoles := []basedao.RoleInfo{
		{Name: "Role", Description: "Has a role", Color: "#329175"},
	}
	initialMembers := []basedao.Member{
		{Address: "g1j9zh3ce7a5tg2esjzherfrx7m3n842k2vmj395", Roles: []string{"Role"}},
		{Address: "g1qkm0xhj8nsm2l3g50ttazxhlq7fs47myhxqk79", Roles: []string{}},
		{Address: "g1nqsjex9aguqy062wdrryvvg9u6dn6e9u44dmkm", Roles: []string{}},
	}
	memberStore := basedao.NewMembersStore(initialRoles, initialMembers)

	// Define the "NoRole" condition
	noRole := NoRole(memberStore, 1)

	var dao daokit.DAO
	dao, daoPrivate = basedao.New(&basedao.Config{
		Name:             "Demo DAOKIT DAO",
		Description:      "This is a demo DAO built with DAOKIT",
		Members:          memberStore,
		InitialCondition: noRole,
		GetProfileString: profile.GetStringField,
		SetProfileString: profile.SetStringField,
	})
	DAO = &crossingDAOWrapper{dao: dao}
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
