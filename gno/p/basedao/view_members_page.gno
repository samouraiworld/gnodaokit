package basedao

import (
	"std"
	"strings"

	"gno.land/p/demo/avl/pager"
	"gno.land/p/demo/ufmt"
	"gno.land/p/samcrew/piechart"
)

func (d *DAOPrivate) MembersPageView(path string) string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	membersCount := d.Members.MembersCount()
	membersNoRoleCount := d.Members.CountMembersWithNoRole()
	rolesCount := len(d.Members.GetRoles())
	if membersNoRoleCount > 0 {
		rolesCount++
	}
	pieSlices := make([]piechart.PieSlice, 0, rolesCount)
	roles := d.Members.GetRoles()

	for _, role := range roles {
		count := d.Members.CountMembersWithRole(role)
		roleInfo := d.Members.RoleInfo(role)
		pieSlices = append(pieSlices, piechart.PieSlice{
			Value: float64(count),
			Color: roleInfo.Color,
			Label: roleInfo.Name,
		})

	}

	if membersNoRoleCount > 0 {
		pieSlices = append(pieSlices, piechart.PieSlice{
			Value: float64(membersNoRoleCount),
			Color: "#CDCDCD",
			Label: "No role assigned",
		})
	}

	const pageSize = 10
	pager := pager.NewPager(d.Members.Members, pageSize, false)
	page := pager.MustGetPageByPath(path)

	s := ""
	s += ufmt.Sprintf("## Members 👥 (%d)\n\n", membersCount)
	s += ufmt.Sprintf("| **Name** | **Address 🔗** | **Roles 🎭** | **Profile** |\n")
	s += ufmt.Sprintf("|----------|----------------|--------------|-------------|\n")

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

	s += "\n"
	s += piechart.Render(pieSlices, "Roles distribution:")

	s += ufmt.Sprintf("\n--------------------------------\n")

	return s
}
