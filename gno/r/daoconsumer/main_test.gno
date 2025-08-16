package daoconsumer

import (
	"testing"

	"gno.land/p/demo/urequire"
	"gno.land/p/samcrew/basedao"
	"gno.land/r/samcrew/daodemo/simple_dao"
	_ "gno.land/r/samcrew/daodemo/simple_dao_external" // WARNING: this is needed during testing to ensure this realm is loaded and it's memberstore is registered
)

func TestQueryExtension(t *testing.T) {
	ext := simple_dao.DAO.QueryExtension(basedao.DAOPrivateQueryExtensionV1Kind)
	if ext == nil {
		t.Fatalf("expected to get an extension, got nil")
	}
	urequire.Equal(t, "gno.land/r/samcrew/daodemo/simple_dao.daoPrivate", ext.Path)
	// NOTE: this string is meant to be used outside of gno code by client that use the query rpc
}

func TestObjExtension(t *testing.T) {
	urequire.True(t, IsDemoMemberViaExtension("g1r69l0vhp7tqle3a0rk8m8fulr8sjvj4h7n0tth"))
	urequire.False(t, IsDemoMemberViaExtension("not a member"))
}

func TestLocalExtenstion(t *testing.T) {
	urequire.True(t, simple_dao.IsMember("g1r69l0vhp7tqle3a0rk8m8fulr8sjvj4h7n0tth"))
	urequire.False(t, simple_dao.IsMember("not a member"))
}

func TestThirdPartyMemberStore(t *testing.T) {
	urequire.True(t, IsDemoMemberViaThirdParty("g1r69l0vhp7tqle3a0rk8m8fulr8sjvj4h7n0tth"))
	urequire.False(t, IsDemoMemberViaThirdParty("not a member"))
}

func TestExtensionProtection(t *testing.T) {
	_, ok := basedao.MustGetMemberStoreExtension(simple_dao.DAO).(basedao.IMembersStorePrivate)
	urequire.False(t, ok)
}
