package basedao

import "gno.land/p/samcrew/daokit"

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
