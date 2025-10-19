package daokit

// Allows DAOs to add custom features dynamically.

import "gno.land/p/nt/avl"

type Extension interface {
	Info() ExtensionInfo
}

type ExtensionInfo struct {
	Path      string // Unique extension identifier
	Version   string // Implementation version. Must implement the interface specified by Path
	QueryPath string
	Private   bool // If true, the extension is only accessible from the current realm scope
}

type ExtensionsList interface {
	Len() int
	Get(index int) *ExtensionInfo
	Slice(startIndex, endIndex int) []ExtensionInfo
	ForEach(fn func(index int, value ExtensionInfo) bool)
}

type ExtensionsStore struct {
	Tree avl.Tree
}

// Registers a new extension using extension info as key.
func (es *ExtensionsStore) Set(ext Extension) bool {
	info := ext.Info()
	return es.Tree.Set(info.Path, ext)
}

func (es *ExtensionsStore) Get(path string) (Extension, bool) {
	iface, ok := es.Tree.Get(path)
	if !ok {
		return nil, false
	}
	return iface.(Extension), true
}

func (es *ExtensionsStore) Remove(path string) (Extension, bool) {
	iface, ok := es.Tree.Remove(path)
	if !ok {
		return nil, false
	}
	return iface.(Extension), true
}

// Returns an iterable list of extensions.
func (es *ExtensionsStore) List() ExtensionsList {
	return &extensionsList{es: es}
}

type extensionsList struct {
	es *ExtensionsStore
}

func (e *extensionsList) ForEach(fn func(index int, value ExtensionInfo) bool) {
	if e.es.Tree.Size() == 0 {
		return
	}

	index := 0
	e.es.Tree.IterateByOffset(0, e.es.Tree.Size(), func(_ string, value any) bool {
		result := fn(index, value.(Extension).Info())
		index++
		return result

	})
}

func (e *extensionsList) Get(index int) *ExtensionInfo {
	if index < 0 || index >= e.es.Tree.Size() {
		return nil
	}

	_, value := e.es.Tree.GetByIndex(index)
	info := value.(Extension).Info()
	return &info
}

func (e *extensionsList) Len() int {
	return e.es.Tree.Size()
}

func (e *extensionsList) Slice(startIndex int, endIndex int) []ExtensionInfo {
	size := e.es.Tree.Size()

	// Normalize bounds

	if startIndex < 0 {
		startIndex = 0
	}

	if endIndex > size {
		endIndex = size
	}

	if startIndex >= endIndex {
		return nil
	}

	count := endIndex - startIndex

	result := make([]ExtensionInfo, count)

	i := 0
	e.es.Tree.IterateByOffset(startIndex, count, func(_ string, value any) bool {
		result[i] = value.(Extension).Info()
		i++
		return false

	})

	return result
}
