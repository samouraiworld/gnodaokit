package basedao

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
)

func (d *DAOPrivate) MembersPageView(path string) string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	s := ""
	memberCount := 0
	d.Members.Members.Iterate("", "", func(key string, value interface{}) bool {
		memberCount++
		return false
	})
	s += ufmt.Sprintf("## Members 👥 (%d)\n\n", memberCount)
	s += ufmt.Sprintf("| **Name** | **Address 🔗** | **Roles 🎭** | **Profile** |\n")
	s += ufmt.Sprintf("|----------|-------------|-----------|-------------|\n")
	d.Members.Members.Iterate("", "", func(key string, value interface{}) bool {
		displayName := d.GetProfileString(std.Address(key), "DisplayName", FALLBACK_DISPLAY_NAME)
		roles := d.Members.GetMemberRoles(key)
		rolesStr := strings.Join(roles, ", ")
		if rolesStr == "" {
			rolesStr = "*No role assigned*"
		}
		s += ufmt.Sprintf("| %s | %s | %s | [View](%s:%s/%s) |\n",
			displayName,
			key,
			rolesStr,
			linkPath, "member", key)

		return false
	})
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}
