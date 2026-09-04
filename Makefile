# Multi Platform Bowling
#
# Mac is the everyday host. Apple TV is a separate living-room host.
# `make run` and `make build` never also launch/build the other host.

PYTHON ?= python3
XCODE  := $(PYTHON) Scripts/xcode_make.py

.PHONY: help test \
	build build-macos build-ios build-tvos build-all \
	run run-macos run-ios run-tvos run-ios-sim run-tvos-sim \
	release release-macos release-ios release-tvos release-all \
	archive-macos archive-ios archive-tvos \
	assets clean

help:
	@echo "Development (default host is macOS, not Apple TV)"
	@echo "  make test              Package unit tests (BowlingGameCore)"
	@echo "  make build             Debug build for macOS host"
	@echo "  make build-ios         Debug build for iOS controller"
	@echo "  make build-tvos        Debug build for Apple TV host"
	@echo "  make build-all         macOS, then iOS, then tvOS (sequential)"
	@echo "  make run               Build and launch the macOS host"
	@echo "  make run-ios           iPhone on the LAN if paired, else Simulator"
	@echo "  make run-tvos          Apple TV on the LAN if paired, else Simulator"
	@echo "  make run-ios-sim       iOS Simulator only"
	@echo "  make run-tvos-sim      tvOS Simulator only"
	@echo ""
	@echo "Release (one platform per invocation; does not run the app)"
	@echo "  make release-macos     Archive Mac and upload if ASC_* env is set"
	@echo "  make release-ios       Archive iPhone app for App Store Connect"
	@echo "  make release-tvos      Archive Apple TV app for App Store Connect"
	@echo "  make release-all       All three archives, sequentially"
	@echo ""
	@echo "Assets"
	@echo "  make assets            Convert League Night GLB → USDZ for RealityKit"
	@echo ""
	@echo "App Store Connect upload needs:"
	@echo "  ASC_KEY_ID  ASC_ISSUER_ID  ASC_KEY_PATH"

test:
	$(XCODE) test

build: build-macos

build-macos:
	$(XCODE) build macos

build-ios:
	$(XCODE) build ios

build-tvos:
	$(XCODE) build tvos

build-all: build-macos build-ios build-tvos

run: run-macos

run-macos:
	$(XCODE) run macos

run-ios:
	$(XCODE) run ios

run-tvos:
	$(XCODE) run tvos

run-ios-sim:
	$(XCODE) run ios --simulator

run-tvos-sim:
	$(XCODE) run tvos --simulator

archive-macos:
	$(XCODE) archive macos

archive-ios:
	$(XCODE) archive ios

archive-tvos:
	$(XCODE) archive tvos

release: release-macos

release-macos:
	$(XCODE) release macos

release-ios:
	$(XCODE) release ios

release-tvos:
	$(XCODE) release tvos

release-all: release-macos release-ios release-tvos

assets:
	$(PYTHON) Assets/tools/convert_leaguenight.py

clean:
	rm -rf .build Assets/Generated
	$(PYTHON) -c "print('Cleaned .build and Assets/Generated')"
