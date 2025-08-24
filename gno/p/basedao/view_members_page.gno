package basedao

import (
	"gno.land/p/demo/ufmt"
)

func (d *DAOPrivate) MembersPageView(path string) string {
	memberCount := d.Members.MembersCount()
	s := ""
	s += ufmt.Sprintf("## Members 👥 (%d)\n\n", memberCount)
	s += d.RenderMembersTable(path, d.Members.Members)
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}
