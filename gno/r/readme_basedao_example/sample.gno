// Code in this file is the "Complete Example" from gno/p/basedao/README.md, verbatim apart from
// the package clause. It is compiled and its init is run by CI so the
// documentation cannot drift into something that does not build — the examples
// ship with the frozen package, and a broken one is as permanent as a broken
// signature. Edit them together.
package readme_basedao_example

import (
    "gno.land/p/samcrew/basedao"
    "gno.land/p/samcrew/daocond"
    "gno.land/p/samcrew/daokit"
    "gno.land/r/demo/profile"
)

var (
	// Unexported deliberately: anything that can reach this value can call the
	// DAO's entry points directly, bypassing this realm's crossing functions.
	localDAO   daokit.DAO
	daoPrivate *basedao.DAOPrivate // Full access to internal DAO state
)

func init(cur realm) {
    // Set up roles
    roles := []basedao.RoleInfo{
        {Name: "admin", Description: "Administrators", Color: "#329175"},
        {Name: "member", Description: "Regular members", Color: "#21577A"},
    }

    // Add initial members
    members := []basedao.Member{
        {Address: "g1admin...", Roles: []string{"admin"}},
        {Address: "g1user1...", Roles: []string{"member"}},
        {Address: "g1user2...", Roles: []string{"member"}},
    }

    store := basedao.NewMembersStore(roles, members)

    // Require 60% of members to approve proposals
    condition := daocond.MembersThreshold(0.6, store.IsMember, store.MembersCount)

    // Create the DAO (cur is threaded so the DAO can perform cross-realm calls)
    localDAO, daoPrivate = basedao.New(&basedao.Config{
        Name:             "My DAO",
        Description:      "A simple DAO example",
        Members:          store,
        InitialCondition: condition,
        // Required: New() panics without it.
        GetProfileString: profile.GetStringField,
        SetProfileString: profile.SetStringField,
    }, cur)
}

// Create a new Proposal to be voted on
// To execute this function, you must use a MsgRun (maketx run)
// See why it is necessary in Gno Documentation: https://docs.gno.land/users/interact-with-gnokey#run
func Propose(cur realm, req daokit.ProposalRequest) {
	localDAO.Propose(req, cur)
}

// Allows DAO members to cast their vote on a specific proposal
func Vote(cur realm, proposalID uint64, vote daocond.Vote) {
    localDAO.Vote(proposalID, vote, cur)
}

// Triggers the implementation of a proposal's actions
func Execute(cur realm, proposalID uint64) {
	localDAO.Execute(proposalID, cur)
}

// Render generates a UI representation of the DAO's state
func Render(path string) string {
	return localDAO.Render(path)
}

// Handle exposes the DAO to other realms. Note it is a function, not an
// exported variable: it is the only intentional way out, and anything holding
// this value can call the entry points directly.
func Handle() daokit.DAO {
	return localDAO
}
