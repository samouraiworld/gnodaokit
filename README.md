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

---

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
        daocond.RoleThreshold(0.5, "finance", store.HasRole, store.CountMembersWithRole),
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

Interface functions for creating proposals, voting, and executing actions.

```go
type DAO interface {
	Propose(req ProposalRequest, rlm realm) uint64  // Create a new proposal, returns proposal ID
	Vote(id uint64, vote daocond.Vote, rlm realm)   // Cast a vote on an existing proposal
	Execute(id uint64, rlm realm)                   // Execute a passed proposal
}
```

Every entry point threads the DAO realm's own realm value. The implementation
requires it to be the DAO's own and to be current, which is what lets it name
the DAO's immediate caller — and what stops a realm holding this handle from
making the DAO act under the caller's identity.

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

// Create DAO (cur is the realm received by init/the calling crossing function)
DAO, daoPrivate := basedao.New(&basedao.Config{
	Name:             "My DAO",
	Description:      "A sample DAO",
	Members:          store,
	InitialCondition: memberMajority,
	// Required: New() panics without it.
	GetProfileString: profile.GetStringField,
}, cur)
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
	CallerID          CallerIDFn        // Custom function to identify the current caller, defaults to the DAO's immediate caller

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
    "gno.land/r/demo/profile"
)

var (
	// Unexported deliberately: anything that can reach this value can call the
	// DAO's entry points directly, bypassing this realm's crossing functions.
	localDAO   daokit.DAO
	daoPrivate *basedao.DAOPrivate // Full access to internal DAO state
)

func init(cur realm) {
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

    // Create the DAO (cur is threaded so the DAO can perform cross-realm calls)
    localDAO, daoPrivate = basedao.New(&basedao.Config{
        Name:             "My DAO",
        Description:      "A simple DAO example",
        Members:          store,
        InitialCondition: condition,
        // Required: New() panics without it.
        GetProfileString: profile.GetStringField,
        SetProfileString: profile.SetStringField,
    }, cur)
}

// Create a new Proposal to be voted on
// To execute this function, you must use a MsgRun (maketx run)
// See why it is necessary in Gno Documentation: https://docs.gno.land/users/interact-with-gnokey#run
func Propose(cur realm, req daokit.ProposalRequest) {
	localDAO.Propose(req, cur)
}

// Allows DAO members to cast their vote on a specific proposal
func Vote(cur realm, proposalID uint64, vote daocond.Vote) {
    localDAO.Vote(proposalID, vote, cur)
}

// Triggers the implementation of a proposal's actions
func Execute(cur realm, proposalID uint64) {
	localDAO.Execute(proposalID, cur)
}

// Render generates a UI representation of the DAO's state
func Render(path string) string {
	return localDAO.Render(path)
}
```

# 4. Examples & Live Demos

DAOkit provides three complete example implementations demonstrating different capabilities:

## 4.1 [Simple DAO](./gno/r/daodemo/simple_dao/) - [Documentation](./gno/r/daodemo/simple_dao/README.md)
Basic DAO with roles and member voting. 

## 4.2 [Custom Resource](./gno/r/daodemo/custom_resource/) - [Documentation](./gno/r/daodemo/custom_resource/README.md)
DAO with custom actions (blog management).

## 4.3 [Custom Condition](./gno/r/daodemo/custom_condition/) - [Documentation](./gno/r/daodemo/custom_condition/README.md)
DAO with custom voting rules.

## Getting Started with Live Demos

1. Register yourself as a member using the `AddMember` function
2. Create proposals using the utils function (as `ProposeAddMember`)
3. Vote on proposals to see governance in action

To create your personalised proposal, modify the transaction script available in the `./tx_script/` directory, and execute it by doing:

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

A tutorial and a walkthrough in video of all our examples video is available on our [`Youtube Channel`](https://www.youtube.com/@peerdevlearning).
> [Video Tutorial](https://youtu.be/SphPgsjKQyQ)

# 5. Create Custom Resources

To add new behavior to your DAO or to enable others to integrate your package into their own DAOs, define custom resources by implementing:

```go
type Action interface {
	Type() string // return the type of the action. e.g.: "gno.land/p/samcrew/blog.NewPost"
	String() string // return stringify content of the action
}

type ActionHandler interface {
	Type() string // return the type of the action. e.g.: "gno.land/p/samcrew/blog.NewPost"
	Execute(action Action, rlm realm) // executes logic associated with the action (rlm is threaded for cross-calls)
}
```

This allows DAOs to execute code through governance-approved decisions.

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
	// def: daoKit.NewActionHandler(kind: String, executor: func(interface{}, realm))
	return daokit.NewActionHandler(ActionNewPostKind, func(payload interface{}, _ realm) {
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
    Condition: daocond.RoleCount(1, "CEO", daoPrivate.Members.HasRole),
    Handler: blog.NewPostHandler(blog),
}
daoPrivate.Core.Resources.Set(&resource)
```

# 6. DAO Migration

DAOs can evolve over time through governance-approved migrations. This allows adding new features, fixing bugs, or changing governance rules while preserving member data and history.

> 📖 **[Full Documentation](./gno/p/basedao/README.md#5-dao-upgrades-and-migration)** - Complete migration guide

# 7. Extensions

Extensions allows DAOs to expose additional functionality that can be accessed by other packages or realms. They provide a secure way to make specific DAO capabilities available without exposing internal implementation details.

## 7.1 Extension Interface

All extensions must implement the `Extension` interface:

```go
type Extension interface {
    // Returns metadata about this extension including its path, version,
    // query path for external access, and privacy settings.
    Info() ExtensionInfo
}

type ExtensionInfo struct {
    Path      string // Unique extension identifier (e.g., "gno.land/p/samcrew/basedao.MembersView")
    Version   string // Extension version (e.g., "1", "2.0", etc.)
    QueryPath string // Path for external queries to access this extension's data
    Private   bool   // If true, extension is only accessible from the same realm
}
```

## 7.2 Accessing Extensions

```go
// Get a specific extension by path
ext := dao.Extension("gno.land/p/samcrew/basedao.MembersView", cur)

// List all available extensions
extList := dao.ExtensionsList()
count := extList.Len()

// Iterate through extensions
extList.ForEach(func(index int, info ExtensionInfo) bool {
    fmt.Printf("Extension: %s v%s\n", info.Path, info.Version)
    return false // continue iteration
})


// Get a slice of extensions
extensions := extList.Slice(0, 5) // Get first 5 extensions

// Get extension by index
extIndex := extList.Get(0)
if extIndex != nil {
    fmt.Printf("First extension: %s\n", extIndex.Path)
}

// Use your extension. Get(i) returns an *ExtensionInfo — metadata, not the
// extension itself — so fetch the extension by path and assert the interface.
ext, ok := dao.Extension(extIndex.Path, cur).(basedao.MembersViewExtension)
if !ok {
    panic("Invalid extension type")
}
ext.IsMember("g1user...")
```

## 7.3 Creating Custom Extensions

You can register custom extensions in your DAO:

```go
// Custom extension implementation
type MyCustomExtension struct {
    queryPath string
    greeting  string
}

func (e *MyCustomExtension) Info() daokit.ExtensionInfo {
    return daokit.ExtensionInfo{
        Path:      "gno.land/p/mydao/custom.CustomView",
        Version:   "1.0",
        QueryPath: e.queryPath,
        Private:   false, // Accessible from other realms
    }
}

// Custom method: Example with parameters
func (e *MyCustomExtension) SayHello(name string) string {
    return "Hello " + name + "! " + e.greeting
}

// Register the extension
daoPrivate.Core.Extensions.Set(&MyCustomExtension{
    queryPath: "custom-data",
    greeting:  "Welcome to our DAO!",
})

// Remove an extension
removed, ok := daoPrivate.Core.Extensions.Remove("gno.land/p/mydao/custom.CustomView")
```

### Using Your Custom Extension

```go
ext := dao.Extension("gno.land/p/mydao/custom.CustomView", cur)
if ext == nil {
    panic("Extension not found")
}

customExt, ok := ext.(*MyCustomExtension)
if !ok {
    panic("Invalid extension type")
}

message := customExt.SayHello("Alice")
```

## 7.4 MembersViewExtension

Built-in [`basedao.MembersViewExtension`](./gno/p/basedao/README.md#7-membership-extension) allows external packages to check DAO membership from any realm:

```go
const MembersViewExtensionPath = "gno.land/p/samcrew/basedao.MembersView"

// Check if someone is a DAO member
ext := basedao.MustGetMembersViewExtension(dao, cur)
isMember := ext.IsMember("g1user...")
```

---

Have fun hacking! :)
