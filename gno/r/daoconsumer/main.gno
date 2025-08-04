package daoconsumer

import (
	"gno.land/p/samourai/basedao"
	"gno.land/r/samourai/daodemo"
)

func IsDemoMember(memberId string) bool {
	members := basedao.MustGetMemberStoreExtension(daodemo.DAO)
	return members.IsMember(memberId)
}
