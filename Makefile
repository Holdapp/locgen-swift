prefix ?= /usr/local
bindir = $(prefix)/bin

build: 
	swift build -c release --disable-sandbox

install: build
	install -d "$(bindir)"
	install ".build/release/locgen-swift" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/locgen-swift"

clean:
	rm -rf .build

.PHONY: build install uninstall clean