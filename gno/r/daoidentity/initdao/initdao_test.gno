package initdao

import (
	"testing"

	"gno.land/p/nt/urequire/v0"
)

// The gate requires the threaded realm to be current. A realm's own init must
// therefore hold its live realm, or publishing any DAO would panic on the first
// gated call it makes during construction.
func TestARealmsOwnInitHoldsItsLiveRealm(t *testing.T) {
	urequire.True(t, RealmWasCurrentDuringInit,
		"a realm's init must hold its own live realm, or the gate would brick construction")
}

// And init sits at the root of the chain: no realm called it, so the identity
// resolved there is the signing account, not another realm.
func TestInitSitsAtTheRootOfTheCallChain(t *testing.T) {
	urequire.True(t, PreviousWasTheOriginRealm,
		"init's previous realm must be the origin realm, so the caller resolves to the signer")
	urequire.Equal(t, uint64(1), Members(),
		"construction must not have added anyone on its own")
}
