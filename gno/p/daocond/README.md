# daocond: Stateless Condition Engine for DAO Governance

`daocond` is a gnolang package that provides a powerful stateless condition engine for evaluating DAO proposal execution. It serves as the decision-making core of the daokit framework, determining whether proposals should be executed based on configurable governance rules.

## Overview

The `daocond` package implements a flexible condition system that allows DAOs to define complex governance rules without maintaining state. Conditions evaluate votes in real-time to determine if proposals meet the required criteria for execution.

## Core Interfaces

### Condition Interface

```go
type Condition interface {
    // Eval checks if the condition is satisfied based on current votes
    Eval(ballot Ballot) bool
    
    // Signal returns a value from 0.0 to 1.0 indicating progress toward satisfaction
    Signal(ballot Ballot) float64
    
    // Render returns a static human-readable representation of the condition
    Render() string
    
    // RenderWithVotes returns a dynamic representation with vote context
    RenderWithVotes(ballot Ballot) string
}
```

### Ballot Interface

```go
type Ballot interface {
    // Vote allows a user to vote on a proposal
    Vote(voter string, vote Vote)
    
    // Get returns the vote of a specific user
    Get(voter string) Vote
    
    // Total returns the total number of votes cast
    Total() int
    
    // Iterate iterates over all votes
    Iterate(fn func(voter string, vote Vote) bool)
}
```

### Vote Types

```go
type Vote int

const (
    VoteAbstain Vote = iota  // Neutral vote
    VoteNo                   // Against the proposal
    VoteYes                  // In favor of the proposal
)
```

## Built-in Conditions

### MembersThreshold

Requires a specified fraction of all DAO members to approve the proposal.

```go
func MembersThreshold(
    threshold float64,                           // Fraction required (0.0 to 1.0)
    isMemberFn func(memberId string) bool,       // Function to check membership
    membersCountFn func() uint64                 // Function to get total member count
) Condition
```

**Example**: Require 60% of all members to approve
```go
condition := daocond.MembersThreshold(0.6, store.IsMember, store.MembersCount)
```

### RoleThreshold

Requires a certain percentage of members holding a specific role to approve.

```go
func RoleThreshold(
    threshold float64,                                       // Fraction required (0.0 to 1.0)
    role string,                                             // Role name to check
    hasRoleFn func(memberId string, role string) bool,       // Function to check role membership
    usersRoleCountFn func(role string) uint32                // Function to count role members
) Condition
```

**Example**: Require 50% of admins to approve
```go
condition := daocond.RoleThreshold(0.5, "admin", store.HasRole, store.RoleCount)
```

### RoleCount

Requires a fixed minimum number of members holding a specific role to approve.

```go
func RoleCount(
    count uint64,                                      // Minimum number of approvals needed
    role string,                                       // Role name to check
    hasRoleFn func(memberId string, role string) bool  // Function to check role membership
) Condition
```

**Example**: Require at least 2 CFO approvals
```go
condition := daocond.RoleCount(2, "CFO", store.HasRole)
```

## Logical Composition

Combine multiple conditions to create sophisticated governance rules:

### And Condition

All provided conditions must be satisfied.

```go
func And(conditions ...Condition) Condition
```

### Or Condition

At least one of the provided conditions must be satisfied.

```go
func Or(conditions ...Condition) Condition
```

**Example**: Complex governance rule
```go
// Require BOTH admin majority AND at least one CFO approval
complexCondition := daocond.And(
    daocond.RoleThreshold(0.5, "admin", store.HasRole, store.RoleCount),
    daocond.RoleCount(1, "CFO", store.HasRole),
)

// Require EITHER admin majority OR unanimous board approval
flexibleCondition := daocond.Or(
    daocond.RoleThreshold(0.5, "admin", store.HasRole, store.RoleCount),
    daocond.RoleThreshold(1.0, "board", store.HasRole, store.RoleCount),
)
```

## Creating Custom Conditions

Implement the `Condition` interface to create custom governance rules:

```go
type customCondition struct {
    // Your custom fields
}

func (c *customCondition) Eval(ballot daocond.Ballot) bool {
    // Implement your evaluation logic
    return true // or false based on your criteria
}

func (c *customCondition) Signal(ballot daocond.Ballot) float64 {
    // Return progress from 0.0 to 1.0
    return 0.5
}

func (c *customCondition) Render() string {
    return "Custom condition description"
}

func (c *customCondition) RenderWithVotes(ballot daocond.Ballot) string {
    return "Custom condition with current vote status"
}
```

## Usage Examples

### Basic Usage

```go
import "gno.land/p/samcrew/daocond"

// Create a simple majority condition
condition := daocond.MembersThreshold(0.5, store.IsMember, store.MembersCount)

// Evaluate the condition against a ballot
if condition.Eval(ballot) {
    // Proposal meets the condition requirements
    executeProposal()
}

// Check progress toward satisfaction
progress := condition.Signal(ballot) // Returns 0.0 to 1.0
```

### Advanced Governance Rules

```go
// Multi-tier approval system
governance := daocond.And(
    // Require 30% of all members
    daocond.MembersThreshold(0.3, store.IsMember, store.MembersCount),
    
    // AND at least 2 T! approvals
    daocond.RoleCount(2, "T1", store.HasRole),
    
    // AND either CTO approval OR finance team majority
    daocond.Or(
        daocond.RoleCount(1, "CTO", store.HasRole),
        daocond.RoleThreshold(0.5, "finance", store.HasRole, store.RoleCount),
    ),
)
```

### Integration with daokit

```go
import (
    "gno.land/p/samcrew/daocond"
    "gno.land/p/samcrew/daokit"
)

// Define conditions for different types of proposals
treasuryCondition := daocond.And(
    daocond.RoleCount(1, "treasurer", store.HasRole),
    daocond.MembersThreshold(0.6, store.IsMember, store.MembersCount),
)

// Use in resource registration
resource := daokit.Resource{
    Handler:     treasuryHandler,
    Condition:   treasuryCondition,
    DisplayName: "Treasury Management",
    Description: "Proposals for treasury operations",
}
```

## Integration

`daocond` is designed to work seamlessly with:
- **[daokit](../daokit/)**: Core DAO framework
- **[basedao](../basedao/)**: Member and role management
- Custom DAO implementations built on the daokit framework

For complete examples and interactive demos, see the [/r/samcrew/daodemo/custom_condition](/r/samcrew/daodemo/custom_condition) realms.

---

*Part of the daokit framework for building decentralized autonomous organizations in gnolang.*