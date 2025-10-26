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
- [🚀 Quick Start](#4-code-example-of-a-basic-dao)
- [🎮 Interactive Examples](#6-interactive-examples--youtube-video)

---

# 1. Introduction

A **Decentralized Autonomous Organization (DAO)** is a self-governing entity that operates through smart contracts, enabling transparent decision-making without centralized control.

`daokit` is a gnolang package for creating complex DAO models. It introduces a new framework based on conditions, composed of :
- `daokit` : Core package for building DAOs, proposals, and actions
- `basedao` : Extension with membership and role management
- `daocond`: Stateless condition engine for evaluating proposals

# 2. What is `daokit`?

`daokit` is a Gnolang framework for building Decentralized Autonomous Organizations (DAO) with programmable governance rules and role-based access control.

## 2.1 Key Concepts

- **Proposal**: A request to execute a **Resource**. Proposals are voted on and executed only if predefined **Conditions** are met.
- **Resource**: An executable action within the DAO. Each resource is governed by a **Condition**.
- **Condition**: A set of rules that determine whether a proposal can be executed.
- **Role**: Labels that assign governance power or permissions to DAO members.

**Example**: Treasury spending requires 50% developer approval + CEO approval. Anyone can propose, but only developers and CEO can vote.

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

> 📖 [Code Example of a Basic DAO](#4-code-example-of-a-basic-dao)

## 3.3 [basedao](./gno/p/basedao/) - Membership and Role Management

`basedao` extends `daokit` to handle members and roles management. It provides a complete solution for building DAOs with structured governance, member onboarding, and permission systems.

> 📖 **[Full Documentation](./gno/p/basedao/README.md)** - Complete guide including built-in actions, governance interface, upgrades, and extensions system


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
- **Member Management**: Add/remove members, assign/unassign roles
- **Profile Management**: Update DAO profile information
- **DAO Upgrades**: Migrate to new implementations via governance


### 3.3.3 Configuration:
```go
type Config struct {
	Name              string
	Description       string
	ImageURI          string
	// Use `basedao.NewMembersStore(...)` to create members and roles.
	Members           *MembersStore
	// Set to `true` to disable built-in actions like add/remove member.
	NoDefaultHandlers bool
	// Default rule applied to all built-in DAO actions.
	InitialCondition  daocond.Condition
	// Optional helpers to store profile data (e.g., from `/r/demo/profile`).
	SetProfileString  ProfileStringSetter
	GetProfileString  ProfileStringGetter
	// Set to `true` if you don’t want a "DAO Created" event to be emitted.
	NoCreationEvent   bool
}
```

# 4. Code Example of a Basic DAO

```go
package simple_dao

// This is the most basic example of a DAO using DAOKIT.
// It is a simple DAO that has a single admin role and a single public-relationships role.
// It is used to demonstrate the basic functionality of DAOKIT.

import (
	"gno.land/p/samcrew/basedao"
	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
	"gno.land/r/demo/profile"
)

var (
	DAO        daokit.DAO          // External interface for DAO interaction
	daoPrivate *basedao.DAOPrivate // Full access to internal DAO state
)

// Initializes the DAO with predefined roles, members, and governance rules.
func init() {
	// Define initial roles in the DAO
	initialRoles := []basedao.RoleInfo{
		{Name: "admin", Description: "Admin is the superuser", Color: "#329175"},
		{Name: "public-relationships", Description: "Responsible of communication with the public", Color: "#21577A"},
		{Name: "finance-officer", Description: "Responsible of funds management", Color: "#F3D3BC"},
	}

	// Define initial members and their roles
	initialMembers := []basedao.Member{
		{Address: "g126gx6p6d3da4ymef35ury6874j6kys044r7zlg", Roles: []string{"admin", "public-relationships"}},
		{Address: "g1ld6uaykyugld4rnm63rcy7vju4zx23lufml3jv", Roles: []string{"public-relationships"}},
		{Address: "g1r69l0vhp7tqle3a0rk8m8fulr8sjvj4h7n0tth", Roles: []string{"finance-officer"}},
		{Address: "g16jv3rpz7mkt0gqulxas56se2js7v5vmc6n6e0r", Roles: []string{}},
	}

	// create the member store now to be able to use it in the condition
	memberStore := basedao.NewMembersStore(initialRoles, initialMembers)

	// Define governance conditions using daocond
	membersMajority := daocond.MembersThreshold(0.6, memberStore.IsMember, memberStore.MembersCount)
	publicRelationships := daocond.RoleCount(1, "public-relationships", memberStore.HasRole)
	financeOfficer := daocond.RoleCount(1, "finance-officer", memberStore.HasRole)

	// `and` and `or` use va_args so you can pass as many conditions as needed
	adminCond := daocond.And(membersMajority, publicRelationships, financeOfficer)

	// Initialize DAO with configuration
	DAO, daoPrivate = basedao.New(&basedao.Config{
		Name:             "Demo DAOKIT DAO",
		Description:      "This is a demo DAO built with DAOKIT",
		Members:          memberStore,
		InitialCondition: adminCond,
		GetProfileString: profile.GetStringField,
		SetProfileString: profile.SetStringField,
	})
}

// Vote allows DAO members to cast their vote on a specific proposal
func Vote(proposalID uint64, vote daocond.Vote) {
	DAO.Vote(proposalID, vote)
}

// Execute triggers the implementation of a proposal's actions
func Execute(proposalID uint64) {
	DAO.Execute(proposalID)
}

// Execute triggers the implementation of a proposal's actions
// To execute this function, you must use a MsgRun (maketx run)
// See why it is necessary in Gno Documentation: https://docs.gno.land/users/interact-with-gnokey#run
func Propose(cur realm, req daokit.ProposalRequest) {
	DAO.Propose(req)
}

// Render generates a UI representation of the DAO's state
func Render(path string) string {
	return daoPrivate.Render(path)
}
```

## Live Demo

An interactive demo of this DAO is available at `/r/samcrew/daodemo/simple_dao:demo`. You are required to register yourself in the DAO before registering your proposal using the `AddMember` function.

> 📖 **See [Interactive Examples & Templates](#6-interactive-examples--templates)** for more examples and detailed documentation.

Every `daodemo` directory contains a `tx_script` directory with executable script files:

```bash
gnokey maketx run \
  --gas-fee 1gnot \
  --gas-wanted 10000 \
  --broadcast \
  -chainid "dev" -remote "tcp://127.0.0.1:26657" \ # For local development
  mykeyname \
  ./tx_script/script.gno
```

For additional details, refer to the [official Gnoland documentation](https://docs.gno.land/users/interact-with-gnokey#run).

# 5. Create Custom Resources

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

# 6. Examples

Three example DAOs demonstrating different features:

### 6.1 [Simple DAO](./gno/r/daodemo/simple_dao/)
Basic DAO with roles and voting. [Documentation](./gno/r/daodemo/simple_dao/README.md)

### 6.2 [Custom Resource](./gno/r/daodemo/custom_resource/)
DAO with custom blog post actions. [Documentation](./gno/r/daodemo/custom_resource/README.md)

### 6.3 [Custom Condition](./gno/r/daodemo/custom_condition/)
DAO with custom voting rules. [Documentation](./gno/r/daodemo/custom_condition/README.md)

## 6.2 Running the Examples

Each example includes transaction scripts for testing:

```bash
# Create a proposal using any example
gnokey maketx run \
  --gas-fee 100000ugnot \
  --gas-wanted 10000000 \
  --broadcast \
  MYKEYNAME \
  ./tx_script/create_proposal.gno
```

## 6.3 Video Tutorial

Watch our comprehensive video tutorial on our [`Youtube Channel`](https://youtu.be/SphPgsjKQyQ) for a walkthrough of all examples.

---

Have fun hacking! :)
