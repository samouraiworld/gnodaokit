package daoconsumer

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/r/samcrew/daodemo/simple_dao"
)

func IsDemoMember(memberId string) bool {
	members := basedao.MustGetMemberStoreExtension(simple_dao.DAO)
	return members.IsMember(memberId)
}
