APP := build/KantineBar.app
ZIP := build/KantineBar.zip
INSTALL_DIR ?= $(HOME)/Applications

.PHONY: app zip run install uninstall clean

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/KantineBar $(APP)/Contents/MacOS/KantineBar
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)

zip: app
	rm -f $(ZIP)
	ditto -c -k --norsrc --noextattr --keepParent $(APP) $(ZIP)

run: app
	-pkill -x KantineBar
	open $(APP)

install: app
	-pkill -x KantineBar
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/KantineBar.app
	cp -R $(APP) $(INSTALL_DIR)/
	open $(INSTALL_DIR)/KantineBar.app

uninstall:
	-pkill -x KantineBar
	rm -rf $(INSTALL_DIR)/KantineBar.app

clean:
	rm -rf .build build
