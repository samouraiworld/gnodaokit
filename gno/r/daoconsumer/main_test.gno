package daoconsumer

import (
	"testing"

	"gno.land/p/demo/urequire"
	"gno.land/p/samcrew/basedao"
	"gno.land/r/samcrew/daodemo/simple_dao"
)

func TestQueryExtension(t *testing.T) {
	ext := simple_dao.DAO.QueryExtension(basedao.DAOPrivateQueryExtensionV1Kind)
	if ext == nil {
		t.Fatalf("expected to get an extension, got nil")
	}
	urequire.Equal(t, "gno.land/r/samcrew/daodemo/simple_dao.daoPrivate", ext.Path)
}

func TestObjExtension(t *testing.T) {
	// TODO: example of `gnokey query`
	urequire.True(t, IsDemoMember("g1r69l0vhp7tqle3a0rk8m8fulr8sjvj4h7n0tth"))
	urequire.False(t, IsDemoMember("not a member"))
}

func TestLocalExtenstion(t *testing.T) {
	urequire.True(t, simple_dao.IsMember("g1r69l0vhp7tqle3a0rk8m8fulr8sjvj4h7n0tth"))
	urequire.False(t, simple_dao.IsMember("not a member"))
}

// TODO: multy-party realm extension example
