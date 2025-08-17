package basedao

import (
	"std"
	"strings"

	"gno.land/p/demo/avl/pager"
	"gno.land/p/demo/ufmt"
)

func (d *DAOPrivate) MembersPageView() string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	s := ""
	memberCount := 0
	d.Members.Members.Iterate("", "", func(key string, value interface{}) bool {
		memberCount++
		return false
	})

	const pageSize = 10
	pager := pager.NewPager(d.Members.Members, pageSize, false)
	page := pager.MustGetPageByPath(path)

	s += ufmt.Sprintf("## Members 👥 (%d)\n\n", memberCount)
	s += ufmt.Sprintf("| **Name** | **Address 🔗** | **Roles 🎭** | **Profile** |\n")
	s += ufmt.Sprintf("|----------|-------------|-----------|-------------|\n")

	for _, item := range page.Items {
		displayName := d.GetProfileString(std.Address(item.Key), "DisplayName", FALLBACK_DISPLAY_NAME)
		roles := d.Members.GetMemberRoles(item.Key)
		rolesStr := strings.Join(roles, ", ")
		if rolesStr == "" {
			rolesStr = "*No role assigned*"
		}
		s += ufmt.Sprintf("| %s | %s | %s | [View](%s:%s/%s) |\n",
			displayName,
			item.Key,
			rolesStr,
			linkPath, "member", item.Key)
	}

	s += "\n" + page.Picker(path) + "\n"
	s += ufmt.Sprintf("\n--------------------------------\n")

	return s
}
