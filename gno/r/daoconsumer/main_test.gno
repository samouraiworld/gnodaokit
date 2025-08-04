package daoconsumer

import (
	"testing"

	"gno.land/p/demo/urequire"
	"gno.land/p/samourai/basedao"
	"gno.land/r/samourai/daodemo"
)

func TestQueryExtension(t *testing.T) {
	ext := daodemo.DAO.QueryExtension(basedao.DAOPrivateQueryExtensionV1Kind)
	if ext == nil {
		t.Fatalf("expected to get an extension, got nil")
	}
	urequire.Equal(t, "gno.land/r/samourai/daodemo.daoPrivate", ext.Path)
}

func TestObjExtension(t *testing.T) {
	urequire.True(t, IsDemoMember("g1r69l0vhp7tqle3a0rk8m8fulr8sjvj4h7n0tth"))
	urequire.False(t, IsDemoMember("not a member"))
}

func TestLocalExtenstion(t *testing.T) {
	urequire.True(t, daodemo.IsMember("g1r69l0vhp7tqle3a0rk8m8fulr8sjvj4h7n0tth"))
	urequire.False(t, daodemo.IsMember("not a member"))
}

// TODO: multy-party realm extension example
