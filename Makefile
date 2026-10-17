CC = clang
SWIFTC = swiftc

APP_NAME = TS2GFN.app
CLI_NAME = tspc-cli

DYLIB_NAME = libTSPCG29Bridge.dylib

all: $(CLI_NAME) $(DYLIB_NAME) $(APP_NAME)

$(DYLIB_NAME): src/TSPCG29Bridge.m src/TSPCBridge.m src/TSPCBridge.h
	$(CC) -O2 -dynamiclib src/TSPCG29Bridge.m src/TSPCBridge.m \
		-framework IOKit -framework CoreFoundation -framework Foundation \
		-o $(DYLIB_NAME)
	codesign -s - -f $(DYLIB_NAME)

$(CLI_NAME): src/TSPCBridge.m src/cli/main.c src/TSPCBridge.h
	$(CC) -O2 -framework IOKit -framework CoreFoundation -framework Foundation \
		src/TSPCBridge.m src/cli/main.c -o $(CLI_NAME)

$(APP_NAME): src/TSPCBridge.h src/TSPCBridge.m src/TSPCManager.swift src/Views/*.swift src/App.swift src/Info.plist AppIcon.icns
	mkdir -p "$(APP_NAME)/Contents/MacOS" "$(APP_NAME)/Contents/Resources"
	cp src/Info.plist "$(APP_NAME)/Contents/Info.plist"
	cp AppIcon.icns "$(APP_NAME)/Contents/Resources/AppIcon.icns"
	cp src/logo_transparent.png "$(APP_NAME)/Contents/Resources/logo_transparent.png"
	$(SWIFTC) -O -parse-as-library -import-objc-header src/TSPCBridge.h \
		src/TSPCBridge.m \
		src/TSPCManager.swift \
		src/Views/WheelVisualView.swift \
		src/Views/PedalsVisualView.swift \
		src/Views/ButtonsVisualView.swift \
		src/App.swift \
		-framework IOKit -framework SwiftUI -framework AppKit -framework Foundation -framework GameController \
		-o "$(APP_NAME)/Contents/MacOS/TS2GFN"
	echo "APPL????" > "$(APP_NAME)/Contents/PkgInfo"
	codesign -s - -f "$(APP_NAME)"

clean:
	rm -rf $(CLI_NAME) $(DYLIB_NAME) $(APP_NAME) "TS-PC Control.app" tspc-gui-app test_* /tmp/hid-tmff2 /tmp/hid-tminit AppIcon.iconset

install: $(APP_NAME)
	cp -R "$(APP_NAME)" /Applications/

.PHONY: all clean install
