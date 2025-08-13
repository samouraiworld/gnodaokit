CAT := $(if $(filter $(OS),Windows_NT),type,cat)

gnobuild: .gnoversion
	rm -fr gnobuild
	mkdir -p gnobuild
	git clone https://github.com/n0izn0iz/gno.git gnobuild --branch pkgloadlint
	cd gnobuild && git checkout $(shell $(CAT) .gnoversion)

gnobuild/gnovm/build/gno: gnobuild
	cd gnobuild/gnovm && make build

gnobuild/contribs/gnodev/build/gnodev: gnobuild
	cd gnobuild/contribs/gnodev && make build

.PHONY: dev
dev: gnobuild/contribs/gnodev/build/gnodev
	./gnobuild/contribs/gnodev/build/gnodev staging $$(find gno -name gnomod.toml -type f -exec dirname {} \;)

.PHONY: install-gno
install-gno: gnobuild
	cd gnobuild/gno && make install

.PHONY: lint
lint: gnobuild/gnovm/build/gno
	./gnobuild/gnovm/build/gno lint ./gno/... -v

.PHONY: test
test: gnobuild/gnovm/build/gno
	./gnobuild/gnovm/build/gno test ./gno/... -v

.PHONY: gno-mod-tidy
gno-mod-tidy: gnobuild/gnovm/build/gno
	export gno=$$(pwd)/gnobuild/gnovm/build/gno; \
	find gno -name gno.mod -type f | xargs -I'{}' sh -c 'cd $$(dirname {}); $$gno mod tidy' \;

.PHONY: clean-gno
clean-gno:
	rm -rf gnobuild