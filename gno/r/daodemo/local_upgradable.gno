package daodemo

import (
	"gno.land/p/samourai/daokit"
)

// example of dao-specific upgradable custom behavior

var (
	isMemberFn func(memberId string) bool
)

type changeIsMemberFnPayload struct {
	newIsMemberFn func(memberId string) bool
}

func (p *changeIsMemberFnPayload) String() string {
	return "Change IsMember implementation.\nWARNING: check the new function implementation!"
}

const ActionKindChangeIsMemberFn = "gno.land/r/daodemo.ChangeIsMemberFn"

func NewChangeIsMemberFnAction(newIsMemberFn func(memberId string) bool) daokit.Action {
	if newIsMemberFn == nil {
		panic("nil newIsMemberFn")
	}
	return daokit.NewAction(ActionKindChangeIsMemberFn, &changeIsMemberFnPayload{newIsMemberFn: newIsMemberFn})
}

func NewChangeIsMemberFnActionHandler(setFn func(isMemberFn func(memberId string) bool)) daokit.ActionHandler {
	if setFn == nil {
		panic("nil setFn")
	}
	return daokit.NewActionHandler(ActionKindChangeIsMemberFn, func(i interface{}) {
		payload := i.(*changeIsMemberFnPayload)
		setFn(payload.newIsMemberFn)
	})
}
