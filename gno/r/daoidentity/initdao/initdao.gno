// Package initdao pins that the realm gate does not break construction.
//
// A realm's own init IS a live crossing frame — cur.IsCurrent() holds there —
// so requiring the threaded realm to be current costs nothing at deploy time. A
// gate that refused during init would brick every DAO on publication, which is
// strictly worse than the hole it closes, so this is worth its own fixture.
//
// What init does NOT do is leave the caller unnamed. cur.Previous() at the root
// of a call chain is the origin realm — {signer, ""} — so IsUser() holds and the
// resolved caller is the SIGNING ACCOUNT's address. On-chain that is the
// deploying account, which is why seeding a DAO with the deployer as a member
// and calling InstantExecute from init works.
//
// It reads as the empty string under `gno test` only because the harness leaves
// OriginCaller unset unless a test sets it. Nothing here may assert on that:
// it is a property of the harness, not of the code being frozen. The empty-id
// guard is asserted directly, on controlled input, in basedao's own tests.
package initdao

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
)

const Self = "gno.land/r/samcrew/daoidentity/initdao"

var (
	localDAO   daokit.DAO
	daoPrivate *basedao.DAOPrivate

	// RealmWasCurrentDuringInit records that a realm's own init holds its live
	// realm, so the gate's IsCurrent() requirement cannot brick construction.
	RealmWasCurrentDuringInit bool
	// PreviousWasTheOriginRealm records that init sits at the root of the call
	// chain: its previous realm is the signer, not another realm.
	PreviousWasTheOriginRealm bool
)

func init(cur realm) {
	members := basedao.NewMembersStore(nil, []basedao.Member{{Address: Self}})
	cond := daocond.MembersThreshold(0.1, members.IsMember, members.MembersCount)

	localDAO, daoPrivate = basedao.New(&basedao.Config{
		Name:             "Init DAO",
		Description:      "construction-time gate fixture",
		Members:          members,
		InitialCondition: cond,
		GetProfileString: func(addr address, field, def string) string { return "" },
		PrivateVarName:   "daoPrivate",
		NoCreationEvent:  true,
	}, cur)

	RealmWasCurrentDuringInit = cur.IsCurrent()
	PreviousWasTheOriginRealm = cur.Previous().IsUserCall()
}

// Members reports the member count.
func Members() uint64 { return daoPrivate.Members.MembersCount() }
