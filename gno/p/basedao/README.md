# basedao: Membership and Role Management for DAOs

`basedao` is a gnolang package that extends the daokit framework with comprehensive membership and role management capabilities. It provides a complete solution for building DAOs with structured governance, member onboarding, and permission systems. It serves as the foundation for most DAO implementations, offering both the infrastructure and common actions needed for decentralized governance.

## Core Components

Provides three main types for managing DAO membership and roles:

```go
// DAO member with assigned roles
type Member struct { 
    Address string    
    Roles   []string  
}

// Contains metadata about DAO roles
type RoleInfo struct { 
    Name        string 
    Description string 
    Color       string 
}

// Central component for managing members and roles
type MembersStore struct { 
    Roles   *avl.Tree 
    Members *avl.Tree 
}
```

### MembersStore Usage

**Creating and initializing**:
```go
// Create with initial data
store := basedao.NewMembersStore(
    []basedao.RoleInfo{
        {Name: "admin", Description: "Administrators", Color: "#329175"},
        {Name: "treasurer", Description: "Treasury management", Color: "#F3D3BC"},
    },
    []basedao.Member{
        {Address: "g1admin...", Roles: []string{"admin"}},
        {Address: "g1user...", Roles: []string{}},
    },
)

// Create empty store for dynamic management
store := basedao.NewMembersStore(nil, nil)
```

**Common operations**:
```go
// Member operations
store.AddMember("g1new...", []string{"moderator"})
store.RemoveMember("g1former...")
isMember := store.IsMember("g1user...")
count := store.MembersCount()

// Role operations  
store.AddRole(basedao.RoleInfo{Name: "secretary", Description: "Records keeper", Color: "#4A90E2"})
store.RemoveRole("obsolete-role")
store.AddRoleToMember("g1user...", "secretary")
store.RemoveRoleFromMember("g1user...", "moderator")

// Query operations
hasRole := store.HasRole("g1user...", "admin")
memberRoles := store.GetMemberRoles("g1user...")
roleMembers := store.GetMembersWithRole("admin")
adminCount := store.CountMembersWithRole("admin")
membersWithoutRoles := store.GetMembersWithoutRole()
roleInfo := store.RoleInfo("admin")  // Get role metadata
membersJSON := store.GetMembersJSON() // Export as JSON
```

## Built-in Actions

Provides built-in actions for common DAO operations. Each action has a unique type identifier:

### Action Type Constants
```go
const ActionAddMemberKind = "gno.land/p/samcrew/basedao.AddMember"
const ActionRemoveMemberKind = "gno.land/p/samcrew/basedao.RemoveMember"  
const ActionAssignRoleKind = "gno.land/p/samcrew/basedao.AssignRole"
const ActionUnassignRoleKind = "gno.land/p/samcrew/basedao.UnassignRole"
const ActionEditProfileKind = "gno.land/p/samcrew/basedao.EditProfile"
const ActionChangeDAOImplementationKind = "gno.land/p/samcrew/basedao.ChangeDAOImplementation"
```

### Creating Actions
```go
// Add a member with roles
action := basedao.NewAddMemberAction(&basedao.ActionAddMember{
    Address: address("g1newmember..."),
    Roles:   []string{"moderator", "treasurer"},
})

// Remove member
action := basedao.NewRemoveMemberAction(address("g1member..."))

// Assign role to member
action := basedao.NewAssignRoleAction(&basedao.ActionAssignRole{
    Address: address("g1member..."),
    Role:    "admin",
})

// Remove role from member
action := basedao.NewUnassignRoleAction(&basedao.ActionUnassignRole{
    Address: address("g1member..."),
    Role:    "moderator",
})

// Edit DAO profile
action := basedao.NewEditProfileAction(
    [2]string{"DisplayName", "My Updated DAO Name"},
    [2]string{"Bio", "An improved description of our DAO"},
    [2]string{"Avatar", "https://example.com/new-logo.png"},
)
```

## Core Governance Interface

Allow DAO's members to interact through proposals and voting.

### Creating Proposals
```go
// Create a new proposal for members to vote on
// Returns its proposal ID
func Propose(req daokit.ProposalRequest) uint64 {...}

type ProposalRequest struct {
	Title       string 
	Description string 
	Action      Action
}
```

**Example - Adding a new member:**
```go
addMemberAction := basedao.NewAddMemberAction(&basedao.ActionAddMember{
    Address: "g1alice...",
    Roles:   []string{"treasurer"},
})

proposal := daokit.ProposalRequest{
    Title:       "Add new treasurer",
    Description: "Proposal to add Alice as treasurer for better fund management",
    Action:      addMemberAction,
}
proposalID := Propose(proposal)
```

#### Voting on Proposals
```go
// Cast your vote on an active proposal
// Available vote: VoteYes, VoteNo, VoteAbstain
func Vote(proposalID uint64, vote daocond.Vote) {...}

Vote(1, daocond.VoteYes) // Vote yes on proposal #1
Vote(2, daocond.VoteNo) // Vote no on proposal #2
Vote(3, daocond.VoteAbstain) // Vote abstain on proposal #3
```

#### Executing Proposals  
```go
// Execute a proposal that has passed its voting requirements
func Execute(proposalID uint64) {...}

Execute(1) // Execute proposal #1 -- only works if it has enough votes
```

#### Instant Execution

Skip the voting process and execute a proposal immediately if you have the required permissions:

```go
// This performs: Propose() -> Vote(VoteYes) -> Execute()
proposalID := daokit.InstantExecute(DAO, proposal)
```

Useful for admin actions, migrations, and emergency procedures.

### Rendering DAO Information

**Built-in render paths**:
- `/` - Main DAO overview with basic info
- `/members` - Member list with roles and permissions
- `/proposals` - Proposal list with their status and voting progress  
- `/proposals/{id}` - Detailed view of a proposal with vote breakdown
- `/config` - DAO configuration and governance rules
- `/roles` - Available roles and their descriptions

You can add or overwrite renders by providing a custom `RenderFn` in the DAO configuration.

## Creating a DAO with basedao

### Basic DAO Setup

```go
package my_dao

import (
    "gno.land/p/samcrew/basedao"
    "gno.land/p/samcrew/daocond"
    "gno.land/p/samcrew/daokit"
    "gno.land/r/demo/profile"
)

var (
    DAO        daokit.DAO
    daoPrivate *basedao.DAOPrivate
)

func init() {
    // Define initial roles in the DAO
    initialRoles := []basedao.RoleInfo{
        {Name: "admin", Description: "Administrators with full access", Color: "#329175"},
        {Name: "public-relationships", Description: "Responsible for communication with the public", Color: "#21577A"},
        {Name: "finance-officer", Description: "Responsible for funds management", Color: "#F3D3BC"},
    }

    // Define initial members and their roles
    initialMembers := []basedao.Member{
        {Address: "g126gx6p6d3da4ymef35ury6874j6kys044r7zlg", Roles: []string{"admin", "public-relationships"}},
        {Address: "g1ld6uaykyugld4rnm63rcy7vju4zx23lufml3jv", Roles: []string{"public-relationships"}},
        {Address: "g1r69l0vhp7tqle3a0rk8m8fulr8sjvj4h7n0tth", Roles: []string{"finance-officer"}},
        {Address: "g16jv3rpz7mkt0gqulxas56se2js7v5vmc6n6e0r", Roles: []string{}},
    }

    // Create the member store to use in conditions
    memberStore := basedao.NewMembersStore(initialRoles, initialMembers)

    // Define governance conditions using `daocond`
    membersMajority := daocond.MembersThreshold(0.6, memberStore.IsMember, memberStore.MembersCount)

    // Create the DAO with comprehensive configuration
    DAO, daoPrivate = basedao.New(&basedao.Config{
        Name:             "Demo DAOKIT DAO",
        Description:      "This is a demo DAO built with DAOKIT",
        Members:          memberStore,
        InitialCondition: membersMajority,
        GetProfileString: profile.GetStringField,
        SetProfileString: profile.SetStringField,
        PrivateVarName:   "daoPrivate",
        RenderFn: func(path string, dao *basedao.DAOPrivate) string {
            if path == "demo" {
                return renderDemo()
            }
            return dao.RenderRouter.Render(path)
        },
    })
}
```

### Configuration Options

```go
type Config struct {
	// Basic DAO information
	Name        string
	Description string
	ImageURI    string

	// Core components
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
	CrossFn           daokit.CrossFn    // Cross-realm communication function for multi-realm DAOs
	CallerID          CallerIDFn        // Custom function to identify the current caller, defaults to realmid.Previous

	// Internal configuration
	PrivateVarName string // Name of the private DAO variable for member querying extensions
}
```

## DAO Upgrades and Migration

Supports upgrading DAO implementations through governance proposals, allowing DAOs to evolve over time.

### Configuration for Upgrades

```go
DAO, daoPrivate = basedao.New(&basedao.Config{
    // ... other config
    MigrationParamsFn: func() []any { return nil }, // Parameters passed to migration function

    SetImplemFn:      setImplem,           
    CrossFn:          crossFn,             
})

// Update DAO variables after migration
func setImplem(newLocalDAO daokit.DAO, newDAO daokit.DAO) {
    localDAO, DAO = newLocalDAO, newDAO
}

// Necessary due to crossing constraint
func crossFn(_ realm, callback func()) {
	callback()
}
```

### Migration Process

1. Create Migration Function
2. Create Upgrade Proposal
3. Execute Migration

```go
// Migration function signature
type MigrateFn = func(prev *DAOPrivate, params []any) daokit.DAO

// Parameters function signature  
type MigrationParamsFn = func() []any

// 1. Define migration function
// params contains data from MigrationParamsFn - use for config, settings, etc.
func migrateTo2_0(prev *basedao.DAOPrivate, params []any) daokit.DAO {
    // Preserve existing member store
    memberStore := prev.Members
    
    // Add new roles for v2.0
    memberStore.AddRole(basedao.RoleInfo{
        Name: "auditor", 
        Description: "Financial oversight",
    })
    
    // Create new DAO with enhanced features
    newLocalDAO, newPrivate := basedao.New(&basedao.Config{
        Name:             prev.InitialConfig.Name + " v2.0",
        Description:      "Upgraded DAO with audit capabilities",
        Members:          memberStore,
        InitialCondition: prev.InitialConfig.InitialCondition,
        // ... other configuration
    })
    
    return newLocalDAO
}

// 2. Create and submit upgrade proposal
action := basedao.NewChangeDAOImplementationAction(migrateTo2_0)
proposal := daokit.ProposalRequest{
    Title:       "Upgrade to DAO v2.0",
    Description: "Adds auditor role and enhanced governance",
    Action:      action,
}
proposalID := DAO.Propose(proposal)

// 3. Execute Migration
DAO.Execute(proposalID)

// Alternatively, you can use InstantExecute to skip the voting process
// if you have sufficient permissions to execute the action directly
daokit.InstantExecute(DAO, proposal) 
```

## Extensions System

Enables DAOs to expose additional functionality that can be accessed by other packages or realms. It provide a secure way to make specific DAO capabilities available without exposing internal implementation details.

### Extension Interface

All extensions must implement the `Extension` interface:

```go
type Extension interface {
    // Returns metadata about this extension including its path, version,
    // query path for external access, and privacy settings.
    Info() ExtensionInfo
}

type ExtensionInfo struct {
    Path      string // Unique extension identifier (e.g., "gno.land/p/demo/basedao.MembersView")
    Version   string // Extension version (e.g., "1", "2.0", etc.)
    QueryPath string // Path for external queries to access this extension's data
    Private   bool   // If true, extension is only accessible from the same realm
}
```

### Accessing Extensions

```go
// Get a specific extension by path
ext := dao.Extension("gno.land/p/demo/basedao.MembersView")

// List all available extensions
extList := dao.ExtensionsList()
count := extList.Len()

// Iterate through extensions
extList.ForEach(func(index int, info ExtensionInfo) bool {
    fmt.Printf("Extension: %s v%s\n", info.Path, info.Version)
    return false // continue iteration
})

// Get extension info by index
info := extList.Get(0)
if info != nil {
    fmt.Printf("First extension: %s\n", info.Path)
}

// Get a slice of extensions
extensions := extList.Slice(0, 5) // Get first 5 extensions
```

### MembersViewExtension

Built-in `MembersViewExtension` allows external packages to check DAO membership:

```go
// Interface for membership queries
type MembersViewExtension interface {
    IsMember(memberId string) bool
}

// Check if someone is a DAO member from any realm
ext := basedao.MustGetMembersViewExtension(dao)
isMember := ext.IsMember("g1user...")

// Extension path constant
const MembersViewExtensionPath = "gno.land/p/demo/basedao.MembersView"
```

### Creating Custom Extensions

You can register custom extensions in your DAO:

```go
// Custom extension implementation
type MyCustomExtension struct {
    queryPath string
}

func (e *MyCustomExtension) Info() daokit.ExtensionInfo {
    return daokit.ExtensionInfo{
        Path:      "gno.land/p/mydao/custom.CustomView",
        Version:   "1.0",
        QueryPath: e.queryPath,
        Private:   false, // Accessible from other realms
    }
}

// Register the extension
daoPrivate.Core.Extensions.Set(&MyCustomExtension{
    queryPath: "custom-data",
})

// Remove an extension
removed, ok := daoPrivate.Core.Extensions.Remove("gno.land/p/mydao/custom.CustomView")
```

## Custom Actions Registration

```go
// Register custom resource after DAO creation
customResource := daokit.Resource{
    Handler:     MyCustomHandler(),
    Condition:   customCondition,
    DisplayName: "Custom Action",
    Description: "My custom DAO action",
}
daoPrivate.Core.Resources.Set(&customResource)
```

## Event System

Events are emitted when actions happen in your DAO. This helps track activities.

```go
// DAO creation (only if NoCreationEvent is false)
chain.Emit("BaseDAOCreated")

// Member management
chain.Emit("BaseDAOAddMember", "address", memberAddr)
chain.Emit("BaseDAORemoveMember", "address", memberAddr)
```

---

*Part of the daokit framework for building decentralized autonomous organizations in gnolang.*