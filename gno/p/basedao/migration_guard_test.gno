package basedao

import (
	"strings"
	"testing"

	"gno.land/p/nt/urequire/v0"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
)

func noopMigrate(prev *DAOPrivate, params []any, rlm realm) daokit.DAO { return nil }

// A migration is a takeover in the general case: the function receives the DAO's
// live realm and its full private state. A voter must be able to tell one
// migration from another, and every migration used to render as the same fixed
// sentence.
func TestAMigrationMustIdentifyItself(cur realm, t *testing.T) {
	urequire.PanicsWithMessage(t, cur, "migration label must not be empty", func() {
		NewChangeDAOImplementationAction("", noopMigrate)
	})
	urequire.PanicsWithMessage(t, cur, "migration function must not be nil", func() {
		NewChangeDAOImplementationAction("v2", nil)
	})

	action := NewChangeDAOImplementationAction("v2.0 — adds auditing", noopMigrate)
	rendered := action.String()
	urequire.True(t, strings.Contains(rendered, "v2.0 — adds auditing"),
		"the label must reach the voter")
	urequire.True(t, strings.Contains(rendered, "live realm"),
		"the warning must say what is being granted")
}

// Replacing the implementation must not be as easy as adding a member.
func TestMigrationIsHarderThanAddingAMember(cur realm, t *testing.T) {
	members := NewMembersStore(nil, []Member{
		{alice.String(), nil}, {bob.String(), nil}, {carol.String(), nil},
	})
	conf := &Config{
		Name:             "d",
		Description:      "d",
		Members:          members,
		GetProfileString: func(addr address, field, def string) string { return "" },
		SetImplemFn:      func(daokit.DAO) {},
	}
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/testing/migdao"))
	_, d := New(conf, cur)

	addMember := d.Core.Resources.Get(ActionAddMemberKind)
	migration := d.Core.Resources.Get(ActionChangeDAOImplementationKind)

	// Two of three members: enough for the default 60% action, short of the
	// 80% the migration now requires.
	ballot := daocond.NewBallot()
	ballot.Vote(alice.String(), daocond.VoteYes)
	ballot.Vote(bob.String(), daocond.VoteYes)
	urequire.True(t, addMember.Condition.Eval(ballot),
		"two of three must carry an ordinary action")
	urequire.False(t, migration.Condition.Eval(ballot),
		"two of three must NOT carry a migration")
}

// The defaulted migration condition must be strictly harder than the DAO's
// ordinary one, in every dimension — not merely harder in the one dimension a
// members threshold measures.
//
// A Condition is opaque, so there is no way to "raise" one. Substituting a
// members threshold for a role-gated condition drops the role gate: measured
// with And(MembersThreshold(0.4), RoleCount(1,"officer")), a ballot that FAILED
// the ordinary action PASSED a bare 0.8 migration. That makes a takeover easier
// than adding a member, which is the opposite of the point.
func TestMigrationNeverWeakensARoleGatedCondition(cur realm, t *testing.T) {
	eve := "g1eve000000000000000000000000000000000000"
	members := NewMembersStore(
		[]RoleInfo{{Name: "officer", Description: "o", Color: "#000"}},
		[]Member{
			{alice.String(), []string{"officer"}},
			{bob.String(), nil}, {carol.String(), nil}, {dave.String(), nil}, {eve, nil},
		},
	)
	conf := &Config{
		Name:        "d",
		Description: "d",
		Members:     members,
		InitialCondition: daocond.And(
			daocond.MembersThreshold(0.4, members.IsMember, members.MembersCount),
			daocond.RoleCount(1, "officer", members.HasRole),
		),
		GetProfileString: func(addr address, field, def string) string { return "" },
		SetImplemFn:      func(daokit.DAO) {},
	}
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/testing/rolemigdao"))
	_, d := New(conf, cur)

	// Four of five in favour, but not the officer: fails the role gate.
	ballot := daocond.NewBallot()
	ballot.Vote(bob.String(), daocond.VoteYes)
	ballot.Vote(carol.String(), daocond.VoteYes)
	ballot.Vote(dave.String(), daocond.VoteYes)
	ballot.Vote(eve, daocond.VoteYes)

	ordinary := d.Core.Resources.Get(ActionAddMemberKind).Condition
	migration := d.Core.Resources.Get(ActionChangeDAOImplementationKind).Condition

	urequire.False(t, ordinary.Eval(ballot), "the role gate refuses this ballot")
	urequire.False(t, migration.Eval(ballot),
		"so the migration must refuse it too — anything the ordinary condition "+
			"refuses, a takeover must refuse")
}
