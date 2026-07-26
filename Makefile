APP_NAME     = Downloader
SCHEME       = Downloader
PROJECT      = $(APP_NAME).xcodeproj
ARCHIVE_PATH = build/$(APP_NAME).xcarchive
EXPORT_PATH  = build/export
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
XCODEBUILD   = DEVELOPER_DIR=$(DEVELOPER_DIR) xcodebuild

.PHONY: gen build test archive export-direct export-appstore clean

gen:
	xcodegen generate

build: gen
	$(XCODEBUILD) -project $(PROJECT) \
	           -scheme $(SCHEME) \
	           -configuration Debug \
	           -destination 'platform=macOS' \
	           build

test: gen
	$(XCODEBUILD) -project $(PROJECT) \
	           -scheme $(SCHEME) \
	           -configuration Debug \
	           -destination 'platform=macOS' \
	           test

# Requiere DEVELOPMENT_TEAM y CODE_SIGN_IDENTITY reales en project.yml.
archive: gen
	$(XCODEBUILD) -project $(PROJECT) \
	           -scheme $(SCHEME) \
	           -configuration Release \
	           -destination 'generic/platform=macOS' \
	           -archivePath $(ARCHIVE_PATH) \
	           archive

export-direct: archive
	$(XCODEBUILD) -exportArchive \
	           -archivePath $(ARCHIVE_PATH) \
	           -exportPath $(EXPORT_PATH) \
	           -exportOptionsPlist ExportOptions/Direct.plist

export-appstore: archive
	$(XCODEBUILD) -exportArchive \
	           -archivePath $(ARCHIVE_PATH) \
	           -exportPath $(EXPORT_PATH) \
	           -exportOptionsPlist ExportOptions/AppStore.plist

clean:
	rm -rf build/ $(PROJECT)
