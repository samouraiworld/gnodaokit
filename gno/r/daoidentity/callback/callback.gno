// Package callback stands in for any realm a DAO action crosses out into —
// a profile realm, a treasury, a third-party integration.
//
// Such a realm necessarily receives the DAO's own realm value as its
// cur.Previous(). It is therefore the one place from which a re-entrant call
// carrying a DAO-looking realm can be made, which is what the entry gate has
// to refuse.
package callback

import "gno.land/p/samcrew/daokit"

var (
	target daokit.DAO
	// reentered records whether the re-entrant call got through. A refusal
	// panics inside the DAO, so the test observes this staying false.
	reentered bool
)

// Reentered reports whether the re-entrant call was ever accepted.
func Reentered() bool { return reentered }

// SetTarget is called by the DAO realm at construction. The DAO hands us its
// own handle, which is exactly what basedao's README teaches realms to expose.
func SetTarget(cur realm, dao daokit.DAO) {
	target = dao
}

// Reenter is invoked by a DAO action handler, so cur.Previous() here is the
// DAO's own realm value. We hand that value straight back to the DAO.
//
// The value has the DAO's pkgpath, so a gate that only compares pkgpaths
// accepts it — but it is a value from a frame that is no longer the live
// crossing frame, so cur.IsCurrent() on it is false.
func Reenter(cur realm, req daokit.ProposalRequest) {
	stolen := cur.Previous()
	target.Propose(req, stolen)
	reentered = true
}
