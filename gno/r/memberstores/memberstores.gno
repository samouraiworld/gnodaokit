package memberstores

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/samcrew/basedao"
)

// XXX: maybe add slugs so an owner can have multiple

var (
	stores avl.Tree
)

func Set(cur realm, store basedao.IMembersStorePrivate) {
	owner := std.PreviousRealm().Address().String()
	if store == nil {
		stores.Remove(owner)
		return
	}
	stores.Set(owner, store)
}

func Get(owner std.Address) basedao.IMembersStore {
	store := getPrivateInternal(owner.String())
	return basedao.NewReadOnlyMembersStore(store)
}

func GetPrivate() basedao.IMembersStorePrivate {
	owner := std.CurrentRealm().Address().String()
	return getPrivateInternal(owner)
}

func getPrivateInternal(owner string) basedao.IMembersStorePrivate {
	i, ok := stores.Get(owner)
	if !ok {
		return nil
	}
	return i.(basedao.IMembersStorePrivate)
}
