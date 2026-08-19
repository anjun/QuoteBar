REPO ?= anjun/QuoteBar
PREFIX ?= /Applications
VERSION := $(shell tr -d '[:space:]' < VERSION)
APP = QuoteBar.app

.DEFAULT_GOAL := help

.PHONY: help start stop package dmg release test clean

help:
	@echo "QuoteBar $(VERSION)"
	@echo
	@echo "  make help                 显示可用命令"
	@echo "  make start                打包安装到 $(PREFIX) 并启动"
	@echo "  make stop                 退出 QuoteBar"
	@echo "  make test                 运行测试"
	@echo "  make package              打通用 .app"
	@echo "  make dmg                  打 QuoteBar-$(VERSION).dmg"
	@echo "  make release              仅所有者：升补丁号、push、发 GitHub Release"
	@echo "  make release part=minor   仅所有者：升次版本号后发版"
	@echo "  make release part=major   仅所有者：升主版本号后发版"
	@echo "  make clean                清理 .build 和 dist"

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
