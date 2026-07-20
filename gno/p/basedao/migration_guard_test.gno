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
