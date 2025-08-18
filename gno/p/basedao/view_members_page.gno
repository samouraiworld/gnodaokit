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
    s += "|------------|----------------|--------------|------------|\n"
    d.Members.Members.Iterate("", "", func(key string, value interface{}) bool {
        displayName := d.GetProfileString(std.Address(key), "DisplayName", FALLBACK_DISPLAY_NAME)
        avatarURI := d.GetProfileString(std.Address(key), "Avatar", "")
        roles := d.Members.GetMemberRoles(key)
        rolesStr := strings.Join(roles, ", ")
        if rolesStr == "" {
            rolesStr = "*No role assigned*"
        }
        avatarMD := avatarMarkdown(avatarURI)
		avatarAndName := ufmt.Sprintf("%s %s", avatarMD, displayName)
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

func convertIPFSToGatewayURI(uri string) string {
	// TODO: replace with a better default image
    const fallbackIPFS = "ipfs://bafkreie63lsunbgxbjcwdc3sywfojdoboogot6pgxfoaqszjyzi7rzs3sm" 
    if uri == "" {
        uri = fallbackIPFS
    }
    if strings.HasPrefix(uri, "ipfs://") {
        cid := strings.TrimPrefix(uri, "ipfs://")
        return "https://ipfs.io/ipfs/" + cid
    }
    return uri
}

func avatarMarkdown(uri string) string {
    imgURL := convertIPFSToGatewayURI(uri)
    return ufmt.Sprintf("![](%s)", imgURL) 	// TODO: Image (e.g. from moul/md)
}