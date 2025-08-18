package basedao

import (
	"std"
	"strings"

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
	s += ufmt.Sprintf("## Members 👥 (%d)\n\n", memberCount)
	// TODO: improve field resizing
	s += "| **Name** | **Address 🔗** | **Roles 🎭** | **Profil** |\n"
	s += "|:------------:|----------------|--------------|------------|\n"
	d.Members.Members.Iterate("", "", func(key string, value interface{}) bool {
		displayName := d.GetProfileString(std.Address(key), "DisplayName", FALLBACK_DISPLAY_NAME)
		avatarURI := d.GetProfileString(std.Address(key), "Avatar", "")
		roles := d.Members.GetMemberRoles(key)
		rolesStr := strings.Join(roles, ", ")
		if rolesStr == "" {
			rolesStr = "*No role assigned*"
		}
		avatarMD := avatarMarkdown(avatarURI, 70, 70)
		avatarAndName := ufmt.Sprintf("%s%s", avatarMD, displayName)
		profileLink := ufmt.Sprintf("[View](%s:member/%s)", linkPath, key)
		s += ufmt.Sprintf("| %s | %s | %s | %s |\n",
			avatarAndName,
			key,
			rolesStr,
			profileLink,
		)
		return false
	})
	s += ufmt.Sprintf("\n--------------------------------\n")
	return s
}

// UTILITIES

func convertIPFSToGatewayURI(uri string, width, height int) string {
	// TODO: replace with a better default image
	const fallbackIPFS = "ipfs://bafkreibdiemksac4wuusly4ymybkwsbzqvkai4cvosf7g5gbkgo4ts6zqy"
	const pinataGatewayBase = "https://gold-personal-grasshopper-424.mypinata.cloud/ipfs/"

	if uri == "" {
		uri = fallbackIPFS
	}
	if strings.HasPrefix(uri, "ipfs://") {
		cid := strings.TrimPrefix(uri, "ipfs://")
		return ufmt.Sprintf("%s%s?img-width=%d&img-height=%d", pinataGatewayBase, cid, width, height)
	}
	return uri
}

func avatarMarkdown(uri string, width, height int) string {
	// TODO: dataURI SVG
	imgURL := convertIPFSToGatewayURI(uri, width, height)
	return ufmt.Sprintf("![](%s)", imgURL)
}
