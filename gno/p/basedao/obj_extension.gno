package basedao

import "gno.land/p/samcrew/daokit"

// XXX: do we need to split ObjExtension and PrivateObjExtension ?
// due to object borrowing we can't expose unsafe object via ObjExtension on daokit.DAO
// but we might want mutable extensions, thus have also PrivateObjExtension maybe that is only available on DAOPrivate

type MemberStoreExtension interface {
	IsMember(memberId string) bool
}

const MemberStoreExtensionV1Kind = "gno.land/p/demo/basedao.MemberStore@v1"

func MustGetMemberStoreExtension(dao daokit.DAO) MemberStoreExtension {
	ext := dao.ObjExtension(MemberStoreExtensionV1Kind)
	if ext == nil {
		panic("no such extension: " + MemberStoreExtensionV1Kind)
	}
	val, ok := ext.(MemberStoreExtension)
	if !ok {
		panic("invalid extension type for " + MemberStoreExtensionV1Kind)
	}
	return val
}
