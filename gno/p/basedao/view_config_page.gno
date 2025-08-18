package basedao

import (
	"gno.land/p/demo/ufmt"
	"gno.land/p/samcrew/daokit"
)

func (d *DAOPrivate) ConfigPageView() string {
	return d.ConfigHeaderView() +
		d.ConfigRolesView() +
		d.ConfigResourcesView()
}

func (d *DAOPrivate) ConfigHeaderView() string {
	name := d.GetProfileString(d.Realm.Address(), "DisplayName", "DAO")
	s := ""
	s += ufmt.Sprintf("# %s - Config ⚙️\n\n", name)
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}

func (d *DAOPrivate) ConfigRolesView() string {
	roles := d.Members.GetRoles()
	s := ""
	s += ufmt.Sprintf("## Roles 🏷️\n\n")
	for _, role := range roles {
		s += ufmt.Sprintf("- %s\n\n", role)
		info := d.Members.RoleInfo(role)
		s += ufmt.Sprintf("  %s\n\n", info.Description)
	}
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}

func (d *DAOPrivate) ConfigResourcesView() string {
	s := ""
	s += ufmt.Sprintf("## Resources 📦\n\n")
	i := 1
	d.Core.Resources.Tree.Iterate("", "", func(key string, value interface{}) bool {
		resource := value.(*daokit.Resource)
		s += ufmt.Sprintf("- **Resource #%d: %s**\n\n", i, key)
		// TODO: add doc to handler and print here
		s += ufmt.Sprintf("  - **Name:** %s\n", resource.DisplayName)
		s += ufmt.Sprintf("  - **Description:** %s\n", resource.Description)
		s += ufmt.Sprintf("  - **Condition:** %s\n\n", resource.Condition.Render())
		i += 1
		return false
	})
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}
