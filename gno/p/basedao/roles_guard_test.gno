package basedao

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
	"gno.land/p/samcrew/avl"
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
