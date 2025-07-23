CAT := $(if $(filter $(OS),Windows_NT),type,cat)

.PHONY: clone-testing-gno
clone-testing-gno:
	rm -fr gnobuild
	mkdir -p gnobuild
	cd gnobuild && git clone https://github.com/n0izn0iz/gno.git gno && cd gno && git checkout 7d23f1d9b8113572f4dcc1d0af01c8b1ab27ec9f

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

# temporary copy waiting for package-loader to handle gno lint, delete it later
.PHONY: lint-gno
lint-gno:
	cp -r ./gno/p ./gnobuild/gno/examples/gno.land/p/samourai
	cp -r ./gno/r ./gnobuild/gno/examples/gno.land/r/samourai
	./gnobuild/gno/gnovm/build/gno lint ./gno/. -v

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