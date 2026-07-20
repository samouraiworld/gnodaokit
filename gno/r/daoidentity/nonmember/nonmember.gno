// Package nonmember reaches the DAO the supported way — through the DAO realm's
// own crossing function — but is not a member. The realm gate passes for it; the
// membership check is the only thing that must not.
package nonmember

import "gno.land/r/samcrew/daoidentity/dao"

func Execute(cur realm, id uint64) {
	dao.Execute(cross(cur), id)
}
