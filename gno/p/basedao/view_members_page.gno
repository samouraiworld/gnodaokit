package basedao

import (
	"std"
	"strings"

	"gno.land/p/demo/avl/pager"
	"gno.land/p/demo/ufmt"
	"gno.land/p/sunspirit/md"
	"gno.land/p/sunspirit/table"
)

func (d *DAOPrivate) MembersPageView(path string) string {
	pkgPath := d.Realm.PkgPath()
	linkPath := getLinkPath(pkgPath)
	s := ""
	memberCount := d.Members.MembersCount()

	const pageSize = 10
	pager := pager.NewPager(d.Members.Members, pageSize, false)
	page := pager.MustGetPageByPath(path)

	s += ufmt.Sprintf("## Members 👥 (%d)\n\n", memberCount)

	mdBuilder := md.NewBuilder()
	tb, _ := table.New([]string{"Name", "Address 🔗", "Roles 🎭", "Profile"}, [][]string{})

	for _, item := range page.Items {
		displayName := d.GetProfileString(std.Address(item.Key), "DisplayName", FALLBACK_DISPLAY_NAME)
		roles := d.Members.GetMemberRoles(item.Key)
		rolesStr := strings.Join(roles, ", ")
		if rolesStr == "" {
			rolesStr = "*No role assigned*"
		}
		tb.AddRow([]string{
			displayName,
			item.Key,
			rolesStr,
			md.Link("View", ufmt.Sprintf("%s:%s/%s", linkPath, "member", item.Key)),
		})
	}

	mdBuilder.Add(md.Table(tb))
	s += mdBuilder.Render("\n")
	s += "\n" + page.Picker(path) + "\n"
	s += ufmt.Sprintf("\n--------------------------------\n")

	return s
}
