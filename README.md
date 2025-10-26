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
- [🚀 Quick Start](#4-quick-start)
- [🎮 Examples & Live Demos](#5-examples--live-demos)

---

# 1. Introduction

A **Decentralized Autonomous Organization (DAO)** is a self-governing entity that operates through smart contracts, enabling transparent decision-making without centralized control.

`daokit` is a gnolang framework for creating complex DAO models based on conditions. It is composed of :
- `daokit` : Core package for building DAOs, proposals, and actions
- `basedao` : Extension with membership and role management
- `daocond`: Stateless condition engine for evaluating proposals

### Key Concepts

- **Proposal**: A request to execute a **Resource**. Proposals are voted on and executed only if predefined **Conditions** are met.
- **Resource**: An executable action within the DAO. Each resource is governed by a **Condition**.
- **Condition**: A set of rules that determine whether a proposal can be executed.
- **Role**: Labels that assign governance power or permissions to DAO members.

**Example**: Treasury spending requires 50% CFO approval + CEO approval. Only CFO and CEO can vote.

# 3. Architecture

## 3.1 [daocond](./gno/p/daocond/) - Stateless Condition Engine

`daocond` is a stateless condition engine used to evaluate if a proposal should be executed. It serves as the decision-making core of the daokit framework.

> 📖 **[Full Documentation](./gno/p/daocond/README.md)** - Comprehensive guide with examples

### 3.1.1 Core Interface
```go
type Condition interface {
	Eval(ballot Ballot) bool              // Check if condition is satisfied
	Signal(ballot Ballot) float64         // Progress indicator (0.0 to 1.0)
	Render() string                       // Human-readable description
	RenderWithVotes(ballot Ballot) string // Description with vote context
}
```

### 3.1.2 Common Usage Patterns

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

### 3.1.3 Custom Conditions

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

## 3.2 [daokit](./gno/p/daokit/) - Core DAO Framework

`daokit` is the core mechanics for DAO governance, proposal management, and resource execution.

### 3.2.1 Core Structure

```go
type Core struct {
	Resources *ResourcesStore  // Available actions that can be proposed
	Proposals *ProposalsStore  // Active and historical proposals
}
```

### 3.2.2 DAO Interface

Defines the external functions that users or other modules interact with. 

```go
type DAO interface {
	Propose(req ProposalRequest) uint64  // Create a new proposal, returns proposal ID
	Vote(id uint64, vote daocond.Vote)   // Cast a vote on an existing proposal
	Execute(id uint64)                   // Execute a passed proposal
}
```

### 3.2.3 Proposal Lifecycle

Proposals follow three states:

1. **Open** - Accepts votes from members
2. **Passed** - Condition met, ready for execution
3. **Executed** - Action completed

> 📖 [Quick Start Example](#4-quick-start)

## 3.3 [basedao](./gno/p/basedao/) - Membership and Role Management

`basedao` extends `daokit` to handle members and roles management.

> 📖 **[Full Documentation](./gno/p/basedao/README.md)**

### 3.3.1 Quick Start
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

### 3.3.2 Built-in Actions
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

### 3.3.3 Configuration:
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

# 4. Quick Start

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
func Propose(cur realm, req daokit.ProposalRequest) {
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
	return daoPrivate.Render(path)
}
```

# 5. Examples & Live Demos

DAOkit provides three complete example implementations demonstrating different capabilities:

## 5.1 [Simple DAO](./gno/r/daodemo/simple_dao/)
Basic DAO with roles and member voting. [Documentation](./gno/r/daodemo/simple_dao/README.md)

## 5.2 [Custom Resource](./gno/r/daodemo/custom_resource/)
DAO with custom actions (blog management). [Documentation](./gno/r/daodemo/custom_resource/README.md)

## 5.3 [Custom Condition](./gno/r/daodemo/custom_condition/)
DAO with custom voting rules. [Documentation](./gno/r/daodemo/custom_condition/README.md)

## Running the Examples

Each example includes ready-to-use transaction scripts in the `tx_script` directory:

```bash
gnokey maketx run \
  --gas-fee 1gnot \
  --gas-wanted 10000 \
  --broadcast \
  -chainid "dev" -remote "tcp://127.0.0.1:26657" \
  mykeyname \
  ./tx_script/create_proposal.gno
```
> [`gnokey maketx run` Gnoland Docs](https://docs.gno.land/users/interact-with-gnokey#run)

**Getting Started with Live Demos:**
1. Register yourself as a member using the `AddMember` function
2. Create proposals using the transaction scripts
3. Vote on proposals to see governance in action

## 5.4 Video Tutorial

Watch our comprehensive video tutorial on our [`Youtube Channel`](https://www.youtube.com/@peerdevlearning) for a walkthrough of all examples.
> [Video Tutorial](https://youtu.be/SphPgsjKQyQ)

# 6. Create Custom Resources

To add new behavior to your DAO — or to enable others to integrate your package into their own DAOs — define custom resources by implementing:

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



---

Have fun hacking! :)
