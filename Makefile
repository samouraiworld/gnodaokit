GNOVERSION=0fbf343a14ca1a015a8969c3c5cbf6c64cd95598
GNO=go run github.com/gnolang/gno/gnovm/cmd/gno@${GNOVERSION}

.PHONY: dev
dev: gnobuild/${GNOVERSION}/gnodev
	gnodev staging $$(find gno -name gnomod.toml -type f -exec dirname {} \;)

.PHONY: lint
lint:
	${GNO} lint ./gno/... -v

.PHONY: fmt
fmt:
	${GNO} fmt ./gno -v -w

.PHONY: test
test:
	${GNO} test ./gno/... -v

.PHONY: gno-mod-tidy
gno-mod-tidy:
	find gno -name gno.mod -type f | xargs -I'{}' sh -c 'cd $$(dirname {}); ${GNO} mod tidy' \;

# we need this since gnodev cannot be `go run`ed
gnobuild/${GNOVERSION}/gnodev:
	rm -fr gnobuild/${GNOVERSION}
	mkdir -p gnobuild/${GNOVERSION}/gno
	git clone https://github.com/gnolang/gno.git gnobuild/${GNOVERSION}/gno
	cd gnobuild/${GNOVERSION}/gno && git checkout ${GNOVERSION}
	cd gnobuild/${GNOVERSION}/gno/contribs/gnodev && make build
	cp gnobuild/${GNOVERSION}/gno/contribs/gnodev/build/gnodev gnobuild/${GNOVERSION}/gnodev
	rm -fr gnobuild/${GNOVERSION}/gno