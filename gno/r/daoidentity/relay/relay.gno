// Package relay is an ordinary intermediary realm: it calls the DAO's own
// crossing function, so the DAO's immediate caller is this realm.
package relay

import (
	"gno.land/p/samcrew/daokit"
	"gno.land/r/samcrew/daoidentity/dao"
)

// Propose reaches the DAO the supported way — through the DAO realm's crossing
// function — so the DAO sees this realm, not whoever called us.
func Propose(cur realm, req daokit.ProposalRequest) uint64 {
	return dao.Propose(cross(cur), req)
}
