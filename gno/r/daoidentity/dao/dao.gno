// Package dao hosts a DAO the way a real realm does, so the identity rules can
// be exercised across genuine realm boundaries.
//
// testing.SetRealm cannot stand in for this: it fabricates a cur with no frame
// beneath it, so cur.Previous() resolves to gno.land/p/samcrew/basedao itself
// rather than to any caller. No SetRealm-based test can tell a correct
// caller-identity implementation from a broken one in either direction, which
// is why both the original defect and #66's New() regression passed CI.
package dao

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/samcrew/daoidentity/callback"
)

const (
	// Self is this realm's own pkgpath — the only realm the DAO may act as.
	Self = "gno.land/r/samcrew/daoidentity/dao"
	// RelayID reaches the DAO through an intermediary realm.
	RelayID = "gno.land/r/samcrew/daoidentity/relay"
	// SuiteID is the test realm. It is a member on purpose: it plays the
	// signer whose membership used to satisfy the check while a foreign realm
	// supplied the acting identity.
	SuiteID = "gno.land/r/samcrew/daoidentity/suite"

	// ActionCrossOut is an action whose handler crosses out of the DAO, as
	// the built-in EditProfile action does.
	ActionCrossOut = "gno.land/r/samcrew/daoidentity/dao.CrossOut"

	// ActionReenter is an action whose handler calls back into this realm's own
	// Execute, which is the one re-entrancy shape the realm gate cannot refuse:
	// the realm is genuinely this one's, and genuinely live.
	ActionReenter = "gno.land/r/samcrew/daoidentity/dao.Reenter"
)

var (
	localDAO   daokit.DAO
	daoPrivate *basedao.DAOPrivate

	// seenByCallerID records the realm a custom CallerIDFn was handed, so a
	// test can show the entry gate ran before it.
	seenByCallerID string

	reenterTarget uint64
	// ReenterAttempted records that the re-entrant handler ran at all, so a
	// test can tell a refusal apart from the action never firing.
	ReenterAttempted bool
	// ReenterSucceeded records that the re-entrant Execute returned.
	ReenterSucceeded bool
)

// NewReenterRequest builds a proposal whose execution re-enters Execute on the
// proposal id given, through this realm's own crossing function.
func ArmReenter(id uint64) { reenterTarget = id }

// NewReenterRequest builds the re-entrant proposal.
func NewReenterRequest() daokit.ProposalRequest {
	return daokit.ProposalRequest{
		Title:       "reenter",
		Description: "calls back into Execute while executing",
		Action:      daokit.NewAction(ActionReenter, nil),
	}
}

// SeenByCallerID reports the realm the DAO's CallerIDFn last observed.
func SeenByCallerID() string { return seenByCallerID }

// StatusOf reports a proposal's status.
func StatusOf(id uint64) string {
	return daoPrivate.Core.Proposals.GetProposal(id).Status.String()
}

func init(cur realm) {
	members := basedao.NewMembersStore(nil, []basedao.Member{
		{Address: RelayID},
		{Address: SuiteID},
		// The DAO is a member of itself so a re-entrant call reaches the
		// proposal machinery instead of stopping at the membership check.
		{Address: Self},
	})

	// Any single member can carry a proposal, so nothing in these tests turns
	// on vote arithmetic.
	cond := daocond.MembersThreshold(0.1, members.IsMember, members.MembersCount)

	localDAO, daoPrivate = basedao.New(&basedao.Config{
		Name:             "Identity DAO",
		Description:      "realm-to-realm identity fixture",
		Members:          members,
		InitialCondition: cond,
		GetProfileString: func(addr address, field, def string) string { return "" },
		PrivateVarName:   "daoPrivate",
		NoCreationEvent:  true,
		// A custom CallerIDFn is a frozen extension point, so what it is handed
		// is part of the contract: it must only ever see the DAO's own realm.
		CallerID: func(d *basedao.DAOPrivate, rlm realm) string {
			seenByCallerID = rlm.PkgPath()
			p := rlm.Previous()
			if p.IsUser() {
				return p.Address().String()
			}
			return p.PkgPath()
		},
	}, cur)

	daoPrivate.Core.Resources.Set(&daokit.Resource{
		Handler: daokit.NewActionHandler(ActionCrossOut, func(payload interface{}, rlm realm) {
			callback.Reenter(cross(rlm), payload.(daokit.ProposalRequest))
		}),
		Condition:   cond,
		DisplayName: "Cross Out",
		Description: "Crosses out of the DAO, handing a callee the DAO's realm.",
	})

	daoPrivate.Core.Resources.Set(&daokit.Resource{
		Handler: daokit.NewActionHandler(ActionReenter, func(payload interface{}, rlm realm) {
			ReenterAttempted = true
			// Straight back through this realm's own crossing entry point.
			Execute(cross(rlm), reenterTarget)
			ReenterSucceeded = true
		}),
		Condition:   cond,
		DisplayName: "Reenter",
		Description: "Calls back into this realm's own Execute while executing.",
	})

	// A private extension, to show the gate does real work.
	daoPrivate.Core.Extensions.Set(&secretExtension{})

	callback.SetTarget(cross(cur), localDAO)
}

// Propose is the legitimate entry point, declared exactly as the demo realms
// declare theirs.
func Propose(cur realm, req daokit.ProposalRequest) uint64 {
	return localDAO.Propose(req, cur)
}

// Vote is the legitimate voting entry point.
func Vote(cur realm, id uint64, vote daocond.Vote) {
	localDAO.Vote(id, vote, cur)
}

// Execute is the legitimate execution entry point.
func Execute(cur realm, id uint64) {
	localDAO.Execute(id, cur)
}

// Handle hands out the DAO value. basedao's README teaches realms to expose
// this, and it is the precondition for the whole donation class: a third realm
// that holds it can call the entry points directly, bypassing this realm's
// crossing functions entirely.
func Handle() daokit.DAO {
	return localDAO
}

// SecretPath is a private extension only this realm may fetch.
const SecretPath = "gno.land/r/samcrew/daoidentity/dao.Secret"

type secretExtension struct{}

func (s *secretExtension) Info() daokit.ExtensionInfo {
	return daokit.ExtensionInfo{Path: SecretPath, Version: "1", Private: true}
}

func (s *secretExtension) Secret() string { return "TOP-SECRET" }

// ReadSecret fetches the private extension using this realm's own live realm,
// which is the only thing allowed to.
func ReadSecret(cur realm) string {
	ext := localDAO.Extension(SecretPath, cur)
	return ext.(*secretExtension).Secret()
}

// ReadPublicExtension shows a public extension ignores the realm.
func ReadPublicExtension(cur realm) bool {
	ext := localDAO.Extension(basedao.MembersViewExtensionPath, cur)
	return ext != nil
}

// PersistStatus writes the status implied by the current votes, which is what
// UpdateStatus is for. A realm may legitimately do this.
func PersistStatus(id uint64) {
	daoPrivate.Core.Proposals.GetProposal(id).UpdateStatus()
}

// ProposerOf reports the identity the DAO resolved for a proposal's creator.
func ProposerOf(id uint64) string {
	return daoPrivate.Core.Proposals.GetProposal(id).ProposerID
}

// NewCrossOutRequest builds a proposal whose execution crosses out of the DAO.
func NewCrossOutRequest(inner daokit.ProposalRequest) daokit.ProposalRequest {
	return daokit.ProposalRequest{
		Title:       "cross out",
		Description: "hands the DAO's realm to a callee",
		Action:      daokit.NewAction(ActionCrossOut, inner),
	}
}
