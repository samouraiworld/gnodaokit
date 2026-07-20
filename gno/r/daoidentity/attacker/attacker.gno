// Package attacker holds the DAO value and calls its entry points directly,
// bypassing the DAO realm's own crossing functions.
//
// This is the shape both identity blockers reduce to. Because no frame of the
// DAO realm is on the stack, the DAO's /p/ code sees this realm as the current
// realm and this realm's caller as the previous one — so the old stack-walking
// identity named the signer, whose membership then satisfied the check while
// this realm supplied the realm the DAO acted under.
package attacker

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/samcrew/daoidentity/dao"
)

// Propose hands the DAO this realm's own realm value.
func Propose(cur realm, req daokit.ProposalRequest) uint64 {
	return dao.Handle().Propose(req, cur)
}

// Vote hands the DAO this realm's own realm value.
func Vote(cur realm, id uint64, vote daocond.Vote) {
	dao.Handle().Vote(id, vote, cur)
}

// Execute is the worst reach: Execute forwards the realm to the action
// handlers, which cross out under it, so a realm accepted here decides the
// identity the DAO acts as — and through MigrateFn, reaches anywhere the
// caller controls.
func Execute(cur realm, id uint64) {
	dao.Handle().Execute(id, cur)
}

// ReadSecret tries to fetch the DAO's PRIVATE extension with this realm's own
// realm. Only the DAO realm may.
func ReadSecret(cur realm) {
	dao.Handle().Extension(dao.SecretPath, cur)
}

// ReadPublicExtension fetches a PUBLIC extension, which any realm may do.
func ReadPublicExtension(cur realm) bool {
	return dao.Handle().Extension(basedao.MembersViewExtensionPath, cur) != nil
}
