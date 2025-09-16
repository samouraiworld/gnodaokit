package simple_dao

// This is the most basic example of a DAO using DAOKIT.
// It is a simple DAO that has a single admin role, a public-relationships role and a finance-officer.
// It is used to demonstrate the basic functionality of DAOKIT.

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/demo/profile"
)

var (
	DAO        daokit.CrossingDAO  // External interface for DAO interaction
	daoPrivate *basedao.DAOPrivate // Full access to internal DAO state
)

// TODO: add a little bit more complexity to show daocond initialization
// Initializes the DAO with predefined roles, members, and governance rules.
func init() {
	// Define initial roles in the DAO
	initialRoles := []basedao.RoleInfo{
		{Name: "public-relationships", Description: "Responsible of communication with the public", Color: "#21577A"},
		{Name: "finance-officer", Description: "Responsible of funds management", Color: "#F3D3BC"},
	}

	// Define initial members and their roles
	initialMembers := []basedao.Member{
		{Address: "g126gx6p6d3da4ymef35ury6874j6kys044r7zlg", Roles: []string{"finance-officer"}},
	}

	// create the member store now to be able to use it in the condition
	memberStore := basedao.NewMembersStore(initialRoles, initialMembers)

	// Define governance conditions using daocond
	membersMajority := daocond.MembersThreshold(0.4, memberStore.IsMember, memberStore.MembersCount)
	financeOfficer := daocond.RoleCount(1, "finance-officer", memberStore.HasRole)

	// `and` and `or` use va_args so you can pass as many conditions as needed
	adminCond := daocond.And(membersMajority, financeOfficer)

	// Initialize DAO with configuration
	var dao daokit.DAO
	dao, daoPrivate = basedao.New(&basedao.Config{
		Name:             "Demo DAOKIT DAO",
		Description:      "This is a demo DAO built with DAOKIT",
		Members:          memberStore,
		InitialCondition: adminCond,
		GetProfileString: profile.GetStringField,
		SetProfileString: profile.SetStringField,
	})
	DAO = &crossingDAOWrapper{dao: dao}

	initProposals(25)
}

// Vote allows DAO members to cast their vote on a specific proposal
func Vote(cur realm, proposalID uint64, vote daocond.Vote) {
	DAO.Vote(cur, proposalID, vote)
}

// Execute triggers the implementation of a proposal's actions
func Execute(cur realm, proposalID uint64) {
	DAO.Execute(cur, proposalID)
}

// Execute triggers the implementation of a proposal's actions
// To execute this function, you must use a MsgRun (maketx run)
// See why it is necessary in Gno Documentation: https://docs.gno.land/users/interact-with-gnokey#run
func Propose(cur realm, req daokit.ProposalRequest) {
	DAO.Propose(cur, req)
}

// Render generates a UI representation of the DAO's state
func Render(path string) string {
	s := ""
	// Demo path to showcase the possibility of this realm
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
