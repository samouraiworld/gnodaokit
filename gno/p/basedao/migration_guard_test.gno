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

// The defaulted migration threshold is pinned, not merely "higher than
// ordinary". Ten members distinguish 0.8 from 0.7; five cannot, because both
// round to the same count.
func TestTheDefaultMigrationThresholdIsEightyPercent(cur realm, t *testing.T) {
	var ms []Member
	addrs := []string{}
	for i := 0; i < 10; i++ {
		a := "g1member" + string(rune('a'+i)) + "0000000000000000000000000000000"
		addrs = append(addrs, a)
		ms = append(ms, Member{a, nil})
	}
	members := NewMembersStore(nil, ms)
	conf := &Config{
		Name: "d", Description: "d", Members: members,
		GetProfileString: func(addr address, field, def string) string { return "" },
		SetImplemFn:      func(daokit.DAO) {},
	}
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/testing/thresholddao"))
	_, d := New(conf, cur)

	migration := d.Core.Resources.Get(ActionChangeDAOImplementationKind).Condition

	seven := daocond.NewBallot()
	for _, a := range addrs[:7] {
		seven.Vote(a, daocond.VoteYes)
	}
	urequire.False(t, migration.Eval(seven), "70% must not carry a migration")

	eight := daocond.NewBallot()
	for _, a := range addrs[:8] {
		eight.Vote(a, daocond.VoteYes)
	}
	urequire.True(t, migration.Eval(eight), "80% must")
}

// A DAO that chose its own governance keeps it for migration too.
//
// Nothing here can strengthen an opaque Condition. Conjoining a members
// threshold onto role-based governance can demand a majority such a DAO never
// assembles — and migration is the one rule that cannot be repaired afterwards,
// since changing it requires a migration. Matching the DAO's own bar is the only
// default that cannot brick it.
func TestCallerChosenGovernanceIsNotOverriddenForMigration(cur realm, t *testing.T) {
	members := NewMembersStore(
		[]RoleInfo{{Name: "admin", Description: "a", Color: "#000"}},
		[]Member{
			{alice.String(), []string{"admin"}},
			{bob.String(), nil}, {carol.String(), nil}, {dave.String(), nil},
		},
	)
	conf := &Config{
		Name: "d", Description: "d", Members: members,
		// Role-only governance: the admin decides, member count is irrelevant.
		InitialCondition: daocond.RoleCount(1, "admin", members.HasRole),
		GetProfileString: func(addr address, field, def string) string { return "" },
		SetImplemFn:      func(daokit.DAO) {},
	}
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/testing/rolegovdao"))
	_, d := New(conf, cur)

	adminAlone := daocond.NewBallot()
	adminAlone.Vote(alice.String(), daocond.VoteYes)

	urequire.True(t, d.Core.Resources.Get(ActionAddMemberKind).Condition.Eval(adminAlone),
		"the admin carries an ordinary action")
	urequire.True(t, d.Core.Resources.Get(ActionChangeDAOImplementationKind).Condition.Eval(adminAlone),
		"and must still be able to migrate — a migration rule this DAO cannot "+
			"meet is unrepairable, because repairing it needs a migration")
}

// New must not write derived defaults into the caller's Config.
//
// The migration condition closes over the member store, so a Config reused for a
// second DAO would otherwise hand it a condition evaluating the FIRST DAO's
// membership.
func TestNewDoesNotContaminateAReusedConfig(cur realm, t *testing.T) {
	conf := &Config{
		Name: "d", Description: "d",
		Members:          NewMembersStore(nil, []Member{{alice.String(), nil}}),
		GetProfileString: func(addr address, field, def string) string { return "" },
		SetImplemFn:      func(daokit.DAO) {},
	}
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/testing/reuse1"))
	New(conf, cur)

	urequire.True(t, conf.MigrationCondition == nil,
		"New must leave the caller's MigrationCondition alone")
}
