package daokit

import (
	"gno.land/p/demo/avl"
)

// TODO: add actions to change extensions

type QueryExtensionsStore struct {
	Tree *avl.Tree // string -> *Extension
}

// QueryExtensions are a way to specify how to query objects implementing a well-known interface
// Kind is the interface identifier
// Path TDB (pkgpath or pkgpath.varname for now), this is meant to be prependend to queries
type QueryExtension struct {
	Kind string
	Path string
}

func NewQueryExtensionsStore() *QueryExtensionsStore {
	return &QueryExtensionsStore{
		Tree: avl.NewTree(),
	}
}

func (r *QueryExtensionsStore) All() []*QueryExtension {
	res := make([]*QueryExtension, 0, r.Tree.Size())
	r.Tree.Iterate("", "", func(key string, value any) bool {
		res = append(res, value.(*QueryExtension))
		return false
	})
	return res
}

func (r *QueryExtensionsStore) Set(extension *QueryExtension) {
	r.Tree.Set(extension.Kind, extension)
}

func (r *QueryExtensionsStore) Remove(kind string) (*QueryExtension, bool) {
	val, rmd := r.Tree.Remove(kind)
	if rmd {
		return val.(*QueryExtension), true
	}
	return nil, false
}

func (r *QueryExtensionsStore) Get(name string) *QueryExtension {
	value, ok := r.Tree.Get(name)
	if !ok {
		return nil
	}
	res := value.(*QueryExtension)
	return res
}
