package basedao

import "gno.land/p/samourai/daokit"

type MemberStoreExtension interface {
	IsMember(memberId string) bool
}

const MemberStoreExtensionV1Kind = "gno.land/p/demo/basedao.MemberStore@v1"

// implements daokit.ObjExtension
func (m *MembersStore) Kind() string {
	return MemberStoreExtensionV1Kind
}

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
