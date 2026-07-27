package basedao

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
	"gno.land/p/nt/avl/v0"
)

// An empty role name is destructive, not merely useless: RenderWithRolesLinks
// substitutes role names into rendered prose, and strings.ReplaceAll with an
// empty needle matches between every character. Measured before the guard:
// "hello world", 11 characters, came back as 227.
func TestAddRoleRejectsAnEmptyName(cur realm, t *testing.T) {
	store := NewMembersStore(nil, nil)

	urequire.PanicsWithMessage(t, cur, "role name must not be empty", func() {
		store.AddRole(RoleInfo{Name: "", Description: "d", Color: "#000"})
	})
	urequire.Equal(t, 0, len(store.GetRoles()), "empty role must not be stored")
}

func TestNewMembersStoreRejectsAnEmptyInitialRole(cur realm, t *testing.T) {
	urequire.PanicsWithMessage(t, cur, "role name must not be empty", func() {
		NewMembersStore([]RoleInfo{{Name: "", Description: "d", Color: "#000"}}, nil)
	})
}

// Roles is an exported avl.Tree, so the guard at the door is not the only way in.
// The render path must stay safe even when the store was seeded around it.
func TestRenderSkipsAnEmptyRoleSeededPastTheGuard(cur realm, t *testing.T) {
	conf := &Config{
		Name:             "d",
		Description:      "d",
		Members:          NewMembersStore(nil, []Member{{alice.String(), nil}}),
		GetProfileString: func(addr address, field, def string) string { return "" },
	}
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/testing/daorealm"))
	_, d := New(conf, cur)

	// Past AddRole entirely.
	d.Members.Roles.Set("", &Role{Name: "", Members: avl.NewTree()})

	urequire.Equal(t, "hello world", d.RenderWithRolesLinks("hello world"),
		"an empty role must not be substituted into rendered prose")
}

// The members table substitutes role names the same way, and an empty role
// reaches it through the ordinary API: once "" is in Roles, AddRoleToMember
// assigns it like any other role.
func TestMembersTableSkipsAnEmptyRole(cur realm, t *testing.T) {
	conf := &Config{
		Name:             "d",
		Description:      "d",
		Members:          NewMembersStore([]RoleInfo{{Name: "admin", Description: "a", Color: "#000"}}, []Member{{alice.String(), []string{"admin"}}}),
		GetProfileString: func(addr address, field, def string) string { return "" },
	}
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/testing/daorealm3"))
	_, d := New(conf, cur)

	before := len(d.RenderMembersTable("", d.Members.Members))

	d.Members.Roles.Set("", &Role{Name: "", Members: avl.NewTree()})
	d.Members.AddRoleToMember(alice.String(), "")

	// The empty role legitimately adds a separator to the joined list, so the
	// table grows by a couple of characters. Without the skip it grows by 4.4x:
	// measured 585 -> 2578, against 585 -> 587 with it.
	after := len(d.RenderMembersTable("", d.Members.Members))
	urequire.True(t, after < before+16,
		"an empty role must not be substituted into the members table")
}

// A real role still renders, so the skip does not disable the feature.
func TestRenderStillLinksRealRoles(cur realm, t *testing.T) {
	conf := &Config{
		Name:             "d",
		Description:      "d",
		Members:          NewMembersStore([]RoleInfo{{Name: "admin", Description: "a", Color: "#000"}}, []Member{{alice.String(), []string{"admin"}}}),
		GetProfileString: func(addr address, field, def string) string { return "" },
	}
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/testing/daorealm2"))
	_, d := New(conf, cur)

	urequire.NotEqual(t, "the admin decides", d.RenderWithRolesLinks("the admin decides"),
		"a real role must still be linked")
}
