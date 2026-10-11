CC = clang
SWIFTC = swiftc

APP_NAME = TS-PC Control.app
CLI_NAME = tspc-cli

all: $(CLI_NAME) $(APP_NAME)

$(CLI_NAME): src/TSPCBridge.m src/cli/main.c src/TSPCBridge.h
	$(CC) -O2 -framework IOKit -framework CoreFoundation -framework Foundation \
		src/TSPCBridge.m src/cli/main.c -o $(CLI_NAME)

$(APP_NAME): src/TSPCBridge.h src/TSPCBridge.m src/TSPCManager.swift src/Views/*.swift src/App.swift
	mkdir -p "$(APP_NAME)/Contents/MacOS" "$(APP_NAME)/Contents/Resources"
	$(SWIFTC) -O -parse-as-library -import-objc-header src/TSPCBridge.h \
		src/TSPCBridge.m \
		src/TSPCManager.swift \
		src/Views/WheelVisualView.swift \
		src/Views/PedalsVisualView.swift \
		src/Views/ButtonsVisualView.swift \
		src/Views/SettingsView.swift \
		src/Views/GFNForzaView.swift \
		src/Views/GamesHelpView.swift \
		src/Views/DashboardView.swift \
		src/App.swift \
		-framework IOKit -framework SwiftUI -framework AppKit -framework Foundation -framework GameController \
		-o "$(APP_NAME)/Contents/MacOS/TS-PC Control"
	echo "APPL????" > "$(APP_NAME)/Contents/PkgInfo"

clean:
	rm -rf $(CLI_NAME) $(APP_NAME) tspc-gui-app test_* /tmp/hid-tmff2 /tmp/hid-tminit

install: $(APP_NAME)
	cp -R "$(APP_NAME)" /Applications/

.PHONY: all clean install
