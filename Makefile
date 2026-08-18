REPO ?= anjun/QuoteBar
PREFIX ?= /Applications
VERSION := $(shell tr -d '[:space:]' < VERSION)
APP = QuoteBar.app

.PHONY: start stop package dmg release test clean

start: stop
	NATIVE=1 ./scripts/package-app.sh "$(VERSION)"
	rm -rf "$(PREFIX)/$(APP)"
	cp -R "dist/$(APP)" "$(PREFIX)/$(APP)"
	xattr -dr com.apple.quarantine "$(PREFIX)/$(APP)" || true
	open "$(PREFIX)/$(APP)"

stop:
	-osascript -e 'tell application "QuoteBar" to quit' >/dev/null 2>&1
	-pkill -x QuoteBar >/dev/null 2>&1
	@sleep 0.3
	@echo "QuoteBar stopped"

package:
	./scripts/package-app.sh "$(VERSION)"

dmg: package
	./scripts/make-dmg.sh "$(VERSION)"

release:
	GITHUB_REPOSITORY="$(REPO)" ./scripts/release.sh $(part)

test:
	swift test

clean:
	rm -rf .build dist
	swift package clean
