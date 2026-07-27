package daokit

// Maps action types to their handlers and conditions.
//
// Example: "transfer" action requires 3 member votes for execution.

import (
	"gno.land/p/nt/avl/v0"
	"gno.land/p/samcrew/daocond"
)

type ResourcesStore struct {
	Tree *avl.Tree // string -> daocond.Condition
}

type Resource struct {
	Handler     ActionHandler     // Executes the action when proposal passes
	Condition   daocond.Condition // Voting rules required for approval
	DisplayName string
	Description string
}

func NewResourcesStore() *ResourcesStore {
	return &ResourcesStore{
		Tree: avl.NewTree(),
	}
}

// Retrieves a resource by its handler type name.
func (r *ResourcesStore) Get(name string) *Resource {
	res, ok := r.Tree.Get(name).(*Resource)
	if !ok {
		// Get returns nil for an absent key, so the assertion also covers a
		// present entry of the wrong type. Only the latter is a bug.
		if r.Tree.Has(name) {
			panic("a value of ResourcesStore.Tree is not a *Resource, should not happen")
		}
		return nil
	}
	return res
}

// Registers a new resource with its handler type as key.
func (r *ResourcesStore) Set(resource *Resource) {
	r.Tree.Set(resource.Handler.Type(), resource)
}
