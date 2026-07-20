package basedao

import (
	"chain"
	"chain/runtime"
	"chain/runtime/unsafe"
	"errors"

	"gno.land/p/nt/mux/v0"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
)

type daoPublic struct {
	impl *DAOPrivate
}

type SetImplemRaw func(newDAO daokit.DAO)

type RenderFn func(path string, dao *DAOPrivate) string

func (d *daoPublic) Extension(path string) daokit.Extension {
	ext, ok := d.impl.Core.Extensions.Get(path)
	if !ok {
		return nil
	}
	if ext.Info().Private && unsafe.CurrentRealm().PkgPath() != d.impl.Realm.PkgPath() {
		panic("attempt to get private extension outside of DAO realm")
	}
	return ext
}

func (d *daoPublic) ExtensionsList() daokit.ExtensionsList {
	return d.impl.Core.Extensions.List()
}

func (d *daoPublic) Propose(req daokit.ProposalRequest, rlm realm) uint64 {
	return d.impl.Propose(req, rlm)
}

func (d *daoPublic) Execute(id uint64, rlm realm) {
	d.impl.Execute(id, rlm)
}

func (d *daoPublic) Vote(id uint64, vote daocond.Vote, rlm realm) {
	d.impl.Vote(id, vote, rlm)
}

func (d *daoPublic) Render(path string) string {
	return d.impl.Render(path)
}

// DAO is meant for internal realm usage and should not be exposed.
type DAOPrivate struct {
	Core             *daokit.Core
	Members          *MembersStore
	RenderRouter     *mux.Router
	GetProfileString ProfileStringGetter
	Realm            runtime.Realm
	RenderFn         func(path string, dao *DAOPrivate) string
	CallerID         CallerIDFn

	InitialConfig *Config // mostly there in case we need this data during upgrade
}

// Function type that returns the identifier of the current caller.
// Used to identify who is making calls to DAO functions.
// CallerIDFn resolves the identity of the DAO's immediate caller.
//
// It receives the DAO realm's own threaded realm, so the implementation can use
// rlm.Previous() — which is statically scoped to that crossing function and
// cannot lie about who called it. It deliberately does NOT stack-walk: a walk
// finds whichever realm was outermost-crossing in the chain, so in an
// EOA -> intermediary -> DAO call it names the EOA rather than the intermediary.
// The realm is deliberately the SECOND parameter: a function whose first
// parameter is a realm is read as crossing, and /p/ packages may not declare
// crossing functions.
type CallerIDFn func(dao *DAOPrivate, rlm realm) string

type Config struct {
	// Basic DAO information
	Name        string
	Description string
	ImageURI    string

	// Storage handler
	Members *MembersStore

	// Feature toggles
	NoDefaultHandlers  bool // Skips registration of default management actions (add/remove members, etc.)
	NoDefaultRendering bool // Skips setup of default web UI rendering routes
	NoCreationEvent    bool // Skips emitting the DAO creation event

	// Governance configuration
	InitialCondition daocond.Condition // Default condition for all built-in actions, defaults to 60% member majority

	// Profile integration (optional)
	SetProfileString ProfileStringSetter // Function to update profile fields (DisplayName, Bio, Avatar)
	GetProfileString ProfileStringGetter // Function to retrieve profile fields for members

	// Advanced customization hooks
	SetImplemFn       SetImplemRaw      // Function called when DAO implementation changes via governance
	MigrationParamsFn MigrationParamsFn // Function providing parameters for DAO upgrades
	RenderFn          RenderFn          // Rendering function for Gnoweb
	CallerID          CallerIDFn        // Resolves the immediate caller from the DAO's threaded realm; defaults to defaultCallerID

	// Internal configuration
	PrivateVarName string // Name of the private DAO variable for member querying extensions
}

type ProfileStringSetter func(cur realm, field string, value string) bool
type ProfileStringGetter func(addr address, field string, def string) string

const EventBaseDAOCreated = "BaseDAOCreated"

func New(conf *Config, rlm realm) (daokit.DAO, *DAOPrivate) {
	// XXX: emit events from memberstore

	members := conf.Members
	if members == nil {
		members = NewMembersStore(nil, nil)
	}

	if conf.GetProfileString == nil {
		panic(errors.New("GetProfileString is required"))
	}

	if conf.CallerID == nil {
		conf.CallerID = defaultCallerID
	}

	core := daokit.NewCore()
	dao := &DAOPrivate{
		Core:             core,
		Members:          members,
		GetProfileString: conf.GetProfileString,
		Realm:            unsafe.CurrentRealm(),
		RenderFn:         conf.RenderFn,
		CallerID:         conf.CallerID,
		InitialConfig:    conf,
	}

	pubdao := &daoPublic{impl: dao}

	dao.Core.Extensions.Set(&membersViewExtension{
		getStore:  func() *MembersStore { return dao.Members },
		queryPath: dao.Realm.PkgPath() + "." + conf.PrivateVarName + ".Members",
	})

	dao.initRenderingRouter()

	if !conf.NoDefaultRendering {
		dao.InitDefaultRendering()
	}

	if conf.SetProfileString != nil {
		conf.SetProfileString(cross(rlm), "DisplayName", conf.Name)
		conf.SetProfileString(cross(rlm), "Bio", conf.Description)
		conf.SetProfileString(cross(rlm), "Avatar", conf.ImageURI)
	}

	if !conf.NoDefaultHandlers {
		if conf.InitialCondition == nil {
			conf.InitialCondition = daocond.MembersThreshold(0.6, members.IsMember, members.MembersCount)
		}

		if conf.SetProfileString != nil {
			dao.Core.Resources.Set(&daokit.Resource{
				Handler:     NewEditProfileHandler(conf.SetProfileString, []string{"DisplayName", "Bio", "Avatar"}),
				Condition:   conf.InitialCondition,
				DisplayName: "Edit Profile",
				Description: "This proposal allows you to edit this DAO profile.",
			})
		}

		if conf.SetImplemFn != nil {
			setImplemFn := func(dao daokit.DAO) {
				conf.SetImplemFn(dao)
			}
			setImplemFn(pubdao)

			if conf.MigrationParamsFn == nil {
				conf.MigrationParamsFn = func() []any { return nil }
			}

			dao.Core.Resources.Set(&daokit.Resource{
				Handler:     NewChangeDAOImplementationHandler(dao, setImplemFn, conf.MigrationParamsFn),
				Condition:   conf.InitialCondition,
				DisplayName: "Change DAO Implementation",
				Description: "Change the underlying DAO implementation.",
			})
		}

		defaultResources := []daokit.Resource{
			{
				Handler:     NewAddMemberHandler(dao),
				Condition:   conf.InitialCondition,
				DisplayName: "Add Member",
				Description: "This proposal allows you to add a new member to the DAO.",
			},
			{
				Handler:     NewRemoveMemberHandler(dao),
				Condition:   conf.InitialCondition,
				DisplayName: "Remove Member",
				Description: "This proposal allows you to remove a member from the DAO.",
			},
			{
				Handler:     NewAssignRoleHandler(dao),
				Condition:   conf.InitialCondition,
				DisplayName: "Assign Role",
				Description: "This proposal allows you to assign a role to a member.",
			},
			{
				Handler:     NewUnassignRoleHandler(dao),
				Condition:   conf.InitialCondition,
				DisplayName: "Unassign Role",
				Description: "This proposal allows you to unassign a role from a member.",
			},
		}
		// register management handlers
		for _, resource := range defaultResources {
			dao.Core.Resources.Set(&resource)
		}

	}

	if !conf.NoCreationEvent {
		chain.Emit(EventBaseDAOCreated)
	}

	return pubdao, dao
}

func (d *DAOPrivate) Vote(proposalID uint64, vote daocond.Vote, rlm realm) {
	if len(vote) > 16 {
		panic("invalid vote")
	}

	d.assertRealmIsOwn(rlm.PkgPath())
	voterID := d.assertCallerIsMember(d.CallerID(d, rlm))
	d.Core.Vote(voterID, proposalID, vote)
}

func (d *DAOPrivate) Execute(proposalID uint64, rlm realm) {
	d.assertRealmIsOwn(rlm.PkgPath())
	_ = d.assertCallerIsMember(d.CallerID(d, rlm))
	d.Core.Execute(proposalID, rlm)
}

func (d *DAOPrivate) Propose(req daokit.ProposalRequest, rlm realm) uint64 {
	d.assertRealmIsOwn(rlm.PkgPath())
	proposerID := d.assertCallerIsMember(d.CallerID(d, rlm))
	return d.Core.Propose(proposerID, req)
}

// The realm threaded into an entry point must be the DAO's own.
//
// Execute forwards this realm to the action handlers, which cross out under it,
// so whoever supplies it decides the identity the DAO acts as. Left unchecked, a
// third realm holding the DAO value could pass its own realm and have the DAO
// write to that realm's profile — or, through MigrateFn, reach anywhere the
// caller controls. Realm values are unforgeable and cannot be persisted across
// transactions, so a caller can only ever pass its own; requiring it to equal
// the DAO's own realm therefore closes the donation path outright.
//
// It also underpins caller identity: once the realm is known to be the DAO's,
// rlm.Previous() is by construction the DAO's immediate caller.
// Resolves the DAO's immediate caller from the DAO's own threaded realm.
// rlm.Previous() is statically scoped to the DAO realm's crossing function, so
// unlike a stack walk it cannot be shifted by how deep the call chain is.
func defaultCallerID(dao *DAOPrivate, rlm realm) string {
	p := rlm.Previous()
	if p.IsUser() {
		return p.Address().String()
	}
	return p.PkgPath()
}

func (d *DAOPrivate) assertRealmIsOwn(pkgPath string) {
	if pkgPath != d.Realm.PkgPath() {
		panic("realm mismatch: the DAO may only act as " + d.Realm.PkgPath())
	}
}

func (d *DAOPrivate) assertCallerIsMember(id string) string {
	// An empty id is never a real caller, and the store can hold one: Members is
	// an exported avl.Tree, so a same-realm write or a MigrateFn can seed "" past
	// the AddMember guard. Reject it here, where every entry point passes.
	if id == "" {
		panic(errors.New("caller id is empty"))
	}
	if !d.Members.IsMember(id) {
		panic(errors.New("caller is not a member"))
	}
	return id
}
