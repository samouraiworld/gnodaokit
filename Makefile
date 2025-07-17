CAT := $(if $(filter $(OS),Windows_NT),type,cat)

.PHONY: clone-testing-gno
clone-testing-gno:
	rm -fr gnobuild
	mkdir -p gnobuild
	cd gnobuild && git clone https://github.com/gnolang/gno.git && cd gno && git checkout $(shell $(CAT) .gnoversion)
	cp -r ./gno/p ./gnobuild/gno/examples/gno.land/p/zenao
	cp -r ./gno/r ./gnobuild/gno/examples/gno.land/r/zenao

.PHONY: clone-gno
clone-gno:
	rm -fr gnobuild
	mkdir -p gnobuild
	cd gnobuild && git clone https://github.com/gnolang/gno.git && cd gno && git checkout $(shell $(CAT) .gnoversion)

.PHONY: install-gno
install-gno:
	cd gnobuild/gno && make install

.PHONY: build-gno
build-gno:
	cd gnobuild/gno/gnovm && make build

.PHONY: lint-gno
lint-gno:
	./gnobuild/gno/gnovm/build/gno tool lint ./gno/. -v

.PHONY: test-gno
test-gno:
	./gnobuild/gno/gnovm/build/gno test ./gno/... -v

.PHONY: gno-mod-tidy
gno-mod-tidy:
	export gno=$$(pwd)/gnobuild/gno/gnovm/build/gno; \
	find gno -name gno.mod -type f | xargs -I'{}' sh -c 'cd $$(dirname {}); $$gno mod tidy' \;

.PHONY: clean-gno
clean-gno:
	rm -rf gnobuild