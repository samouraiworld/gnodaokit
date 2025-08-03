package daokit

import (
	"gno.land/p/demo/avl"
)

type ExtensionsStore struct {
	Tree *avl.Tree // string -> *Extension
}

// Extensions are a way to specify how to access objects implementing a well-known interface
// Kind is the interface identifier
// Path TDB (pkgpath or pkgpath.varname for now)
type Extension struct {
	Kind string
	Path string
}

func NewExtensionsStore() *ExtensionsStore {
	return &ExtensionsStore{
		Tree: avl.NewTree(),
	}
}

func (r *ExtensionsStore) Set(extension *Extension) {
	r.Tree.Set(extension.Kind, extension)
}

func (r *ExtensionsStore) Get(name string) *Extension {
	value, ok := r.Tree.Get(name)
	if !ok {
		return nil
	}
	res := value.(*Extension)
	return res
}
