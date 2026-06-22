# Budgetapp — developer convenience wrapper around xcodebuild.
# Requires Xcode 16+ on macOS. Nothing here runs automatically; these are
# just shortcuts. Override any variable, e.g.:
#   make run SIMULATOR="iPhone 16 Pro"

PROJECT      ?= Budgetapp.xcodeproj
SCHEME       ?= Budgetapp
SIMULATOR    ?= iPhone 16
DESTINATION  ?= platform=iOS Simulator,name=$(SIMULATOR)
DERIVED_DATA ?= build
BUNDLE_ID    ?= com.tanay.Budgetapp
APP_PATH      = $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/$(SCHEME).app

.DEFAULT_GOAL := help
.PHONY: help build test run boot screenshot open clean

help:
	@echo "Budgetapp — make targets (Xcode 16+, macOS):"
	@echo "  make build       Build for the iOS Simulator"
	@echo "  make test        Build and run the unit + integration tests"
	@echo "  make run         Build, boot the simulator, install and launch"
	@echo "  make screenshot  Save a PNG of the booted simulator under build/"
	@echo "  make open        Open the project in Xcode"
	@echo "  make clean       Remove build output"
	@echo ""
	@echo "Override the device: make run SIMULATOR='iPhone 16 Pro'"

build:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA)

test:
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA)

boot:
	@xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	@open -a Simulator

run: build boot
	xcrun simctl install booted "$(APP_PATH)"
	xcrun simctl launch booted $(BUNDLE_ID)

screenshot:
	@mkdir -p $(DERIVED_DATA)
	xcrun simctl io booted screenshot $(DERIVED_DATA)/screenshot.png
	@echo "Saved $(DERIVED_DATA)/screenshot.png"

open:
	open $(PROJECT)

clean:
	-xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)
	rm -rf $(DERIVED_DATA)
