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

1) REQ: allow to change the DAO variable, this will in turn change the exposed Vote and Execute func implems
2) REQ: allow to change the Render function
3) REQ: allow to "change" the daoPrivate variable, this is used only in external queries

1) RES: this is the easy part, since it's an interface, we can just create a new action that change the underlying implem
this action should take a callback that pass the daoPrivate so we can import the data from the previous implem

2) RES: straigthforward, move the Render func into DAO interface

considered only allowing to upgrade a callback in the realm but
it prevents having an upgradeable Render function that can be dynamically used in gno code

3) RES: more tricky, ideas:

- add a private query extension system to daokit that map an extension kind to a path to start the query with
	- example: kind: "gno.land/p/samcrew/basedao.MemberStore" -> path: "gno.land/r/samcrew/daodemo.daoPrivate.Members"
	- specify a "basedao" extension and add it in basedao constructor, it starts by pointing at the var in the instantiating realm
	- allow to update extensions with actions
	- the clients first query the extensions store to know where to do queries

- use the public extension systems outlined in 4) RES (third party realms or extension objects)

TODO: investigate zenao daos to see if this fits

zenao events and communities have an additional public func and it make sense to have a way to access dao extensions from gno code
example from zenao:

// Set public to be used as auth layer for external entities (e.g polls)
func IsMember(memberId string) bool {
	return daoPrivate.Members.IsMember(memberId)
}

so

4) REQ: allow to upgrade public extensions meant to be imported from gno code or called by an EOA from `maketx call` or `maketx run`

4) RES: tricky, ideas:

- make the specific dao realms have their custom public functions upgradeable via actions
	- pro: no gas cost
	- pro: allow `maketx call`ing those funcs
	- con: does not allow to extend the dao capabilities in itself. Can be combined with other methods but I think we should avoid that

- use third party realms for extensions, like a memberstore realm used by multiple daos in the zenao case
	- pro: allow to extend dao capabilities
	- pro: contribute to commons, those third-party realms can be used by other kind of entities (think aeddi's treasury realm or payrolls realm)
	- con: prevents `maketx call`ing those funcs
	- con: gas cost increase due to the lookup to find the dao

- make the DAO interface have a new method to fetch the extension object and then cast it to the correct type
	- pro: allow to extend dao capabilities
	- con: less type-safety
	- con: prevents `maketx call`ing those funcs
	- con: small gas cost for cast, but probably negligible
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
