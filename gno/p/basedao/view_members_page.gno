package basedao

import (
	"gno.land/p/demo/ufmt"
	"gno.land/p/samcrew/piechart"
)

func (d *DAOPrivate) MembersPageView(path string) string {
	memberCount := d.Members.MembersCount()
	membersNoRoleCount := d.Members.CountMembersWithNoRole()
	rolesCount := len(d.Members.GetRoles())
	if membersNoRoleCount > 0 {
		rolesCount++
	}
	pieSlices := make([]piechart.PieSlice, 0, rolesCount)

	s := ""
	s += ufmt.Sprintf("## Members 👥 (%d)\n\n", memberCount)
	s += d.RenderMembersTable(path, d.Members.Members)
	s += "\n"
	s += piechart.Render(pieSlices, "Roles distribution:")
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}
