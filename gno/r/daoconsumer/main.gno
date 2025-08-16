package daoconsumer

import (
	"std"

	"gno.land/p/samcrew/basedao"
	"gno.land/r/samcrew/daodemo/simple_dao"
	"gno.land/r/samcrew/memberstores"
)

func IsDemoMemberViaExtension(memberId string) bool {
	members := basedao.MustGetMemberStoreExtension(simple_dao.DAO)
	return members.IsMember(memberId)
}

func IsDemoMemberViaThirdParty(memberId string) bool {
	members := memberstores.Get(std.DerivePkgAddr("gno.land/r/samcrew/daodemo/simple_dao_external"))
	return members.IsMember(memberId)
}
