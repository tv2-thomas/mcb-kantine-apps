# MCB Kantine apps

A macOS menubar app and a Raycast extension for the [MCB kantine menu](https://cozy-shortbread-2866c8.netlify.app/).
Both read the `/api` endpoint of that site.

## Kantine Bar (menubar app)

### Install

```sh
curl -fsSL https://raw.githubusercontent.com/tv2-thomas/mcb-kantine-apps/main/install.sh | sh
```

Needs an Apple Silicon Mac with macOS 15 or newer.
The script installs the latest release into `~/Applications` and starts it.
Run it again to update.

### Use

Click the fork and knife in the menubar, or press `⇧⌘K` anywhere.
Pick a day, and click a dish to see its image, allergens and nutrition.
While the popup is open, `←` and `→` switch day, and `1`-`9` open the numbered dish, and `⌫` or `Esc` go back to the list.
The `⋯` menu changes or removes the hotkey, turns on launch at login, and quits the app.

`kantinebar://show` opens the popup, and `kantinebar://show?day=24-09-2026` opens it on a given day.

To uninstall, quit it from the `⋯` menu and delete `~/Applications/KantineBar.app`.

### Build

Needs the Swift toolchain (the Command Line Tools are enough).

```sh
cd app
make run       # build build/KantineBar.app and launch it
make install   # copy to ~/Applications and launch
make zip       # build build/KantineBar.zip for a release
```

### Release

Every push to `main` that touches `app/` builds `KantineBar.zip` and publishes it as a GitHub release (`.github/workflows/release.yml`).
The install script always downloads the latest release.
The build number is the workflow run number, and the version comes from `CFBundleShortVersionString` in `app/Resources/Info.plist`.

## Raycast extension (`raycast/`)

Standalone, it does not need the menubar app.

```sh
cd raycast
npm install
```

Then run **Import Extension** in Raycast and pick the `raycast/` folder.

**Kantine Menu** lists dishes with a day dropdown, and `↵` opens the dish details.
