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
	s := ""
	membersCount := d.Members.MembersCount()

	const pageSize = 10
	pager := pager.NewPager(d.Members.Members, pageSize, false)
	page := pager.MustGetPageByPath(path)

	// pieSlices := make([]piechart.PieSlice, 0, len(d.Members.GetRoles()))
	pieSlices := []piechart.PieSlice{}

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

	pieSlices = append(pieSlices, piechart.PieSlice{
		Value: float64(d.Members.CountMembersWithNoRole()),
		Color: "#CDCDCD",
		Label: "No role assigned",
	})

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
