package daodemo

// This is the most basic example of a DAO using DAOKIT.
// It is a simple DAO that has a single admin role and a single public-relationships role.
// It is used to demonstrate the basic functionality of DAOKIT.

import (
	"gno.land/p/samourai/basedao"
	"gno.land/p/samourai/daocond"
	"gno.land/p/samourai/daokit"
	"gno.land/r/demo/profile"
)

var (
	DAO        daokit.DAO
	daoPrivate *basedao.DAOPrivate
)

/*
Proxy research:

once we hit mainnet, we need a way to upgrade daos implementations

looking at this realm, we need to:

1) allow to change the DAO variable, this will in turn change the exposed Vote and Execute func implems
2) allow to change the Render function
3) allow to "change" the daoPrivate variable, this is used only in external queries

1) this is the easy part, since it's an interface, we can just create a new action that change the underlying implem
this action should take a callback that pass the daoPrivate so we can import the data from the previous implem

2) straigthforward, create an action that can update the Render func target callback

3) more tricky, current idea:
- add an extension system to daokit
- specify a "basedao" extension and add it in this realm, it starts by pointing at the var in this realm
- allow to update extensions with actions
- the clients first query the extensions store to know where to do queries

TODO: investigate zenao daos to see if this fits
*/

// TODO: add a little bit more complexity to show daocond initialization
func init() {
	initialRoles := []basedao.RoleInfo{
		{Name: "admin", Description: "Admin is the superuser"},
		{Name: "public-relationships", Description: "Responsible of communication with the public"},
		{Name: "finance-officer", Description: "Responsible of funds management"},
	}

	initialMembers := []basedao.Member{
		{Address: "g126gx6p6d3da4ymef35ury6874j6kys044r7zlg", Roles: []string{"admin", "public-relationships"}},
		{Address: "g1ld6uaykyugld4rnm63rcy7vju4zx23lufml3jv", Roles: []string{"public-relationships"}},
		{Address: "g1r69l0vhp7tqle3a0rk8m8fulr8sjvj4h7n0tth", Roles: []string{"finance-officer"}},
		{Address: "g16jv3rpz7mkt0gqulxas56se2js7v5vmc6n6e0r", Roles: []string{}},
	}

	// create the member store now to be able to use it in the condition
	memberStore := basedao.NewMembersStore(initialRoles, initialMembers)

	membersMajority := daocond.MembersThreshold(0.6, memberStore.IsMember, memberStore.MembersCount)
	publicRelationships := daocond.RoleCount(1, "public-relationships", memberStore.HasRole)
	financeOfficer := daocond.RoleCount(1, "finance-officer", memberStore.HasRole)

	// and & or use va_args so you can pass as many conditions as you want
	adminCond := daocond.And(membersMajority, publicRelationships, financeOfficer)

	DAO, daoPrivate = basedao.New(&basedao.Config{
		Name:             "Demo DAOKIT DAO",
		Description:      "This is a demo DAO built with DAOKIT",
		Members:          memberStore,
		InitialCondition: adminCond,
		GetProfileString: profile.GetStringField,
		SetProfileString: profile.SetStringField,
	})
}

func Vote(proposalID uint64, vote daocond.Vote) {
	DAO.Vote(proposalID, vote)
}

func Execute(proposalID uint64) {
	DAO.Execute(proposalID)
}

func Render(path string) string {
	return daoPrivate.Render(path)
}
