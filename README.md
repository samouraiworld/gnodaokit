# DAOkit: A Framework for Building Decentralized Autonomous Organizations (DAOs) in Gnolang

**Note for Contributors**: Currently, building and testing require using the Makefile. Direct use of `gnodev` won't work. 

```bash
# For `gnodev`
make dev
# For `gnodev test`
make test
```

## 📚 Documentation Index

### Core Packages
- **[daocond](./gno/p/daocond/)** - Stateless condition engine for DAO governance
- **[daokit](./gno/p/daokit/)** - Core DAO framework and proposal system  
- **[basedao](./gno/p/basedao/)** - Membership and role management for DAOs

### Utils Package
- **[realmid](./gno/p/realmid/)** - Realm and user identification utilities

### Interactive Examples & Templates
- **[Demo Overview](./gno/r/daodemo/)** - Collection of DAO templates and examples
- **[Simple DAO](./gno/r/daodemo/simple_dao/)** - Basic DAO with roles and member voting
- **[Custom Resource](./gno/r/daodemo/custom_resource/)** - DAO with custom actions (blog posts example)
- **[Custom Condition](./gno/r/daodemo/custom_condition/)** - DAO with custom voting rules

### Quick Navigation
- [Architecture Overview](#2-architecture)
- [Quick Start](#3-quick-start)
- [Examples & Live Demos](#4-examples--live-demos)
- [Create Custom Resources](#5-create-custom-resources)
- [DAO Migration](#6-dao-migration)
- [Extensions](#7-extensions)

---

# 1. Introduction

A **Decentralized Autonomous Organization (DAO)** is a self-governing entity that operates through smart contracts, enabling transparent decision-making without centralized control.

DAOkit is a Gnolang framework for building complex DAOs with programmable governance rules and role-based access control. It is based on the following packages:

- **[`daokit`](./gno/p/daokit/)** - Core package for building DAOs, proposals, and actions
- **[`basedao`](./gno/p/basedao/)** - Extension with membership and role management
- **[`daocond`](./gno/p/daocond/)** - Stateless condition engine for evaluating proposals

It works using **Proposals** (requests to execute actions), **Resources** (the actual executable actions), **Conditions** (voting rules that must be met), and **Roles** (member permissions). 

**Example**: Treasury spending requires 50% CFO approval + CEO approval, where only CFO and CEO members can vote.

# 2. Architecture

## 2.1 [daocond](./gno/p/daocond/) - Stateless Condition Engine

`daocond` is a stateless condition engine used to evaluate if a proposal should be executed. It serves as the decision-making core of the daokit framework.

> 📖 **[Full Documentation](./gno/p/daocond/README.md)** - Comprehensive guide with examples

### 2.1.1 Core Interface
```go
type Condition interface {
	Eval(ballot Ballot) bool              // Check if condition is satisfied
	Signal(ballot Ballot) float64         // Progress indicator (0.0 to 1.0)
	Render() string                       // Human-readable description
	RenderWithVotes(ballot Ballot) string // Description with vote context
}
```

### 2.1.2 Common Usage Patterns

```go
// Simple majority of all members
memberMajority := daocond.MembersThreshold(0.6, store.IsMember, store.MembersCount)

// Multi-tier approval system
governance := daocond.And(
    daocond.MembersThreshold(0.3, store.IsMember, store.MembersCount),
    daocond.RoleCount(2, "core-contributor", store.HasRole),
    daocond.Or(
        daocond.RoleCount(1, "CTO", store.HasRole),
        daocond.RoleThreshold(0.5, "finance", store.HasRole, store.RoleCount),
    ),
)
```

### 2.1.3 Custom Conditions

Implement the `Condition` interface for custom voting rules:

```go
type MyCondition struct{}

func (c *MyCondition) Eval(ballot daocond.Ballot) bool {
    // Your voting logic here
    return true
}
// ... implement Signal(), Render(), RenderWithVotes()
```

> 📖 **[See full example](./gno/r/daodemo/custom_condition/README.md)**

## 2.2 [daokit](./gno/p/daokit/) - Core DAO Framework

`daokit` is the core mechanics for DAO governance, proposal management, and resource execution.

### 2.2.1 Core Structure

```go
type Core struct {
	Resources *ResourcesStore  // Available actions that can be proposed
	Proposals *ProposalsStore  // Active and historical proposals
}
```

### 2.2.2 DAO Interface

Defines the external functions that users or other modules interact with. 

```go
type DAO interface {
	Propose(req ProposalRequest) uint64  // Create a new proposal, returns proposal ID
	Vote(id uint64, vote daocond.Vote)   // Cast a vote on an existing proposal
	Execute(id uint64)                   // Execute a passed proposal
}
```

### 2.2.3 Proposal Lifecycle

Proposals follow three states:

1. **Open** - Accepts votes from members
2. **Passed** - Condition met, ready for execution
3. **Executed** - Action completed

> 📖 [Quick Start Example](#3-quick-start)

## 2.3 [basedao](./gno/p/basedao/) - Membership and Role Management

`basedao` extends `daokit` to handle members and roles management.

> 📖 **[Full Documentation](./gno/p/basedao/README.md)**

### 2.3.1 Quick Start
```go
// Initialize with roles and members
roles := []basedao.RoleInfo{
	{Name: "admin", Description: "Administrators", Color: "#329175"},
	{Name: "finance", Description: "Handles treasury", Color: "#F3D3BC"},
}

members := []basedao.Member{
	{Address: "g1abc...", Roles: []string{"admin"}},
	{Address: "g1xyz...", Roles: []string{"finance"}},
}

store := basedao.NewMembersStore(roles, members)

// Create DAO
DAO, daoPrivate := basedao.New(&basedao.Config{
	Name:             "My DAO",
	Description:      "A sample DAO",
	Members:          store,
	InitialCondition: memberMajority,
})
```

### 2.3.2 Built-in Actions
Provides ready-to-use governance actions:

```go
// Add a member with roles
action := basedao.NewAddMemberAction(&basedao.ActionAddMember{
    Address: "g1newmember...",
    Roles:   []string{"moderator", "treasurer"},
})

// Remove member
action := basedao.NewRemoveMemberAction("g1member...")

// Assign role to member
action := basedao.NewAssignRoleAction(&basedao.ActionAssignRole{
    Address: "g1member...",
    Role:    "admin",
})

// Edit DAO profile
action := basedao.NewEditProfileAction(
    [2]string{"DisplayName", "My Updated DAO Name"},
    [2]string{"Bio", "An improved description"},
)
```

### 2.3.3 Configuration:
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

# 3. Quick Start

Create a DAO with roles and member voting in just a few steps:

```go
package my_dao

import (
    "gno.land/p/samcrew/basedao"
    "gno.land/p/samcrew/daocond"
    "gno.land/p/samcrew/daokit"
)

var (
	DAO        daokit.DAO          // External interface for DAO interaction
	daoPrivate *basedao.DAOPrivate // Full access to internal DAO state
)

func init() {
    // Set up roles
    roles := []basedao.RoleInfo{
        {Name: "admin", Description: "Administrators", Color: "#329175"},
        {Name: "member", Description: "Regular members", Color: "#21577A"},
    }

    // Add initial members
    members := []basedao.Member{
        {Address: "g1admin...", Roles: []string{"admin"}},
        {Address: "g1user1...", Roles: []string{"member"}},
        {Address: "g1user2...", Roles: []string{"member"}},
    }

    store := basedao.NewMembersStore(roles, members)

    // Require 60% of members to approve proposals
    condition := daocond.MembersThreshold(0.6, store.IsMember, store.MembersCount)

    // Create the DAO
    DAO, daoPrivate = basedao.New(&basedao.Config{
        Name:             "My DAO",
        Description:      "A simple DAO example",
        Members:          store,
        InitialCondition: condition,
    })
}

// Create a new Proposal to be voted on
// To execute this function, you must use a MsgRun (maketx run)
// See why it is necessary in Gno Documentation: https://docs.gno.land/users/interact-with-gnokey#run
func Propose(req daokit.ProposalRequest) {
	DAO.Propose(req)
}

// Allows DAO members to cast their vote on a specific proposal
func Vote(proposalID uint64, vote daocond.Vote) {
    DAO.Vote(proposalID, vote)
}

// Triggers the implementation of a proposal's actions
func Execute(proposalID uint64) {
	DAO.Execute(proposalID)
}

// Render generates a UI representation of the DAO's state
func Render(path string) string {
	return DAO.Render(path)
}
```

# 4. Examples & Live Demos

DAOkit provides three complete example implementations demonstrating different capabilities:

## 4.1 [Simple DAO](./gno/r/daodemo/simple_dao/)
Basic DAO with roles and member voting. [Documentation](./gno/r/daodemo/simple_dao/README.md)

## 4.2 [Custom Resource](./gno/r/daodemo/custom_resource/)
DAO with custom actions (blog management). [Documentation](./gno/r/daodemo/custom_resource/README.md)

## 4.3 [Custom Condition](./gno/r/daodemo/custom_condition/)
DAO with custom voting rules. [Documentation](./gno/r/daodemo/custom_condition/README.md)

## Getting Started with Live Demos

1. Register yourself as a member using the `AddMember` function
2. Create proposals using the utils function (as `ProposeAddMember`)
3. Vote on proposals to see governance in action

To create your personalised proposal, modify and execute the transaction script available in the `./tx_script` directory by doing:

```bash
gnokey maketx run \
  --gas-fee 1gnot \
  --gas-wanted 10000 \
  --broadcast \
  -chainid "dev" -remote "tcp://127.0.0.1:26657" \
  mykeyname \
  ./tx_script/create_proposal.gno
```
> [Gnoland Docs](https://docs.gno.land/users/interact-with-gnokey#run)

## 4.4 Video Tutorial

Watch our comprehensive video tutorial on our [`Youtube Channel`](https://www.youtube.com/@peerdevlearning) for a walkthrough of all examples.
> [Video Tutorial](https://youtu.be/SphPgsjKQyQ)

# 5. Create Custom Resources

To add new behavior to your DAO or to enable others to integrate your package into their own DAOs, define custom resources by implementing:

```go
type Action interface {
	Type() string // return the type of the action. e.g.: "gno.land/p/samcrew/blog.NewPost"
	String() string // return stringify content of the action
}

type ActionHandler interface {
	Type() string // return the type of the action. e.g.: "gno.land/p/samcrew/blog"
	Execute(action Action) // executes logic associated with the action
}
```
This allows DAOs to execute arbitrary logic or interact with Gno packages through governance-approved decisions.

## Steps to Add a Custom Resource:
1. Define the path of the action, it should be unique 
```go
// XXX: pkg "/p/samcrew/blog" - does not exist, it's just an example
const ActionNewPostKind = "gno.land/p/samcrew/blog.NewPost"
```

2. Create the structure type of the payload
```go
type ActionNewPost struct {
	Title string
	Content string
}
```

3. Implement the action and handler
```go
func NewPostAction(title, content string) daokit.Action {
	// def: daoKit.NewAction(kind: String, payload: interface{})
	return daokit.NewAction(ActionNewPostKind, &ActionNewPost{
		Title:   title,
		Content: content,
	})
}

func NewPostHandler(blog *Blog) daokit.ActionHandler {
	// def: daoKit.NewActionHandler(kind: String, payload: func(interface{}))
	return daokit.NewActionHandler(ActionNewPostKind, func(payload interface{}) {
		action, ok := payload.(*ActionNewPost)
		if !ok {
			panic(errors.New("invalid action type"))
		}
		blog.NewPost(action.Title, action.Content)
	})
}
```

4. Register the resource
```go
resource := daokit.Resource{
    Condition: daocond.NewRoleCount(1, "CEO", daoPrivate.Members.HasRole),
    Handler: blog.NewPostHandler(blog),
}
daoPrivate.Core.Resources.Set(&resource)
```

# 6. DAO Migration

DAOs can evolve over time through governance-approved migrations. This allows adding new features, fixing bugs, or changing governance rules while preserving member data and history.

```go
// 1. Define migration function that preserves existing data
func migrateTo2_0(prev *basedao.DAOPrivate, params []any) daokit.DAO {
    // Keep existing members and add new features
    memberStore := prev.Members
    memberStore.AddRole(basedao.RoleInfo{Name: "auditor", Description: "Financial oversight"})
    
    // Create upgraded DAO
    newDAO, _ := basedao.New(&basedao.Config{
        Name:             prev.InitialConfig.Name + " v2.0",
        Members:          memberStore,
        InitialCondition: prev.InitialConfig.InitialCondition,
    })
    return newDAO
}

// 2. Create and vote on upgrade proposal
action := basedao.NewChangeDAOImplementationAction(migrateTo2_0)
proposal := daokit.ProposalRequest{
    Title:       "Upgrade to DAO v2.0",
    Description: "Add auditor role and enhanced governance",
    Action:      action,
}
proposalID := DAO.Propose(proposal)

// 3. Execute migration after approval
DAO.Execute(proposalID)
```

# 7. Extensions

Extensions allow DAOs to expose controlled functionality to other packages while maintaining security. The most common use case is checking membership from external contracts.

```go
// Built-in membership extension - check if someone is a DAO member
ext := basedao.MustGetMembersViewExtension(dao)
isMember := ext.IsMember("g1user...")

// List all available extensions
extList := dao.ExtensionsList()
fmt.Printf("Available extensions: %d\n", extList.Len())

// Create custom extension for specialized queries
type CustomExtension struct {
    dao *basedao.DAOPrivate
}

func (e *CustomExtension) Info() daokit.ExtensionInfo {
    return daokit.ExtensionInfo{
        Path:      "gno.land/p/mydao/custom.View",
        Version:   "1.0",
        QueryPath: "custom-queries",
        Private:   false, // Accessible from other realms
    }
}

// Register custom extension
daoPrivate.Core.Extensions.Set(&CustomExtension{dao: daoPrivate})
```

---

Have fun hacking! :)
