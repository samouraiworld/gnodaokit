CAT := $(if $(filter $(OS),Windows_NT),type,cat)

gnobuild:
	rm -fr gnobuild
	mkdir -p gnobuild
	git clone https://github.com/n0izn0iz/gno.git gnobuild --branch pkgloadlint
	cd gnobuild && git checkout 60adea95805153ccacb794a7d887241fd516a4b9

gnobuild/gno/gnovm/build/gno: gnobuild
	cd gnobuild/gnovm && make build

.PHONY: install-gno
install-gno: gnobuild
	cd gnobuild/gno && make install

.PHONY: lint-gno
lint-gno: gnobuild/gno/gnovm/build/gno
	./gnobuild/gnovm/build/gno lint ./gno/... -v

.PHONY: test-gno
test-gno: gnobuild/gno/gnovm/build/gno
	./gnobuild/gnovm/build/gno test ./gno/... -v

.PHONY: gno-mod-tidy
gno-mod-tidy: gnobuild/gnovm/build/gno
	export gno=$$(pwd)/gnobuild/gnovm/build/gno; \
	find gno -name gno.mod -type f | xargs -I'{}' sh -c 'cd $$(dirname {}); $$gno mod tidy' \;

.PHONY: clean-gno
clean-gno:
	rm -rf gnobuild