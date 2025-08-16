package daokit

import (
	"gno.land/p/demo/avl"
)

// TODO: add actions to change extensions

type ObjExtensionsStore struct {
	Tree *avl.Tree // string -> *Extension
}

// ObjExtensions are a way to expose extra logic to gno code
// Kind is the interface identifier
// This is meant to be cast to the underlying type specified by Kind()
type ObjExtension interface {
	Kind() string
}

func NewObjExtensionsStore() *ObjExtensionsStore {
	return &ObjExtensionsStore{
		Tree: avl.NewTree(),
	}
}

func (r *ObjExtensionsStore) All() []ObjExtension {
	res := make([]ObjExtension, 0, r.Tree.Size())
	r.Tree.Iterate("", "", func(key string, value any) bool {
		res = append(res, value.(ObjExtension))
		return false
	})
	return res
}

func (r *ObjExtensionsStore) Set(extension ObjExtension) {
	r.Tree.Set(extension.Kind(), extension)
}

func (r *ObjExtensionsStore) Remove(kind string) (ObjExtension, bool) {
	val, rmd := r.Tree.Remove(kind)
	if rmd {
		return val.(ObjExtension), true
	}
	return nil, false
}

func (r *ObjExtensionsStore) Get(name string) ObjExtension {
	value, ok := r.Tree.Get(name)
	if !ok {
		return nil
	}
	res := value.(ObjExtension)
	return res
}
