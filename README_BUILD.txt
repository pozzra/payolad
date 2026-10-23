Rxa Menu - iOS Debug Overlay (v1.3.1)
=====================================
Contact / Telegram: @kun_amra

WHAT THIS IS
------------
A Theos tweak project named Rxa. It adds a small floating icon button to apps.
Tapping it opens a native two-pane catalog browser:

  LEFT SIDEBAR
    CATALOG      Aimbot & Combat, Cyber ESP & Visuals, Memory & Movement,
                 Settings & Config, Help & Notes (116 feature entries total)
    ALL DATA     Full Catalog (197 entries across all 10 catalog categories)
    TOOLS        Apply All (Demo), Reset All (Demo), Get Code, Full Catalog,
                 Python Engine, Telegram, About

  RIGHT PANE
    Feature rows for the selected category, with UI-only switches for
    toggle/slider/combo/config-key entries and read-only rows for labels/help.

The selected category switch states are saved in NSUserDefaults. Apply All and
Reset All update every actionable catalog switch (72 total). The menu refreshes
when returning from a pushed screen. If index.html is missing or unreadable,
Get Code shows an in-app error with the expected install paths instead of a
blank WebView.

The floating button can be dragged anywhere on screen; its position is saved
and clamped inside the safe area. The button lives in its own 52x52 window, and
the full-screen menu window is hidden while the menu is closed, so game touches
are not blocked outside the button. When the app resigns active (background,
Control Center, incoming call, etc.), the menu is closed, the overlay is hidden,
and the game key window is restored. The button returns when the app becomes
active again.

All switches are UI-only. They save ON/OFF in NSUserDefaults; they do not hook,
read, or write any game process. `ros.dylib` from ROS.deb is not loaded, hooked,
signed, or injected by this project.

Function reference: functions.txt documents the tweak, catalog, and bundled
HTML/JavaScript functions.

SAFETY / SCOPE
--------------
This is a UI-only debug/reference tool. It contains:
  - no game hooks
  - no process memory reads or writes
  - no aimbot, ESP, silent aim, or game offsets
  - no injector and no anti-cheat bypass
  - no ros.dylib injection or re-signing

No local .deb is produced on this Windows machine; it has no Theos, clang, iOS
SDK, ldid, or jailbreak packaging toolchain. Use the included GitHub Actions
workflow or a macOS/Linux Theos install.

WHAT GETS PACKAGED
------------------
layout/Library/Application Support/RAACHEATMenuDebug/
  index.html          self-contained catalog app (Get Code WebView)
  menu_catalog.json   single data store (197 entries, 10 categories)
  menu_catalog.csv    spreadsheet export
  build_info.json     metadata
  menu_image.jpg      original menu icon
  menu_icon.png       192x192 icon used by the floating button
  mod_menu.py         optional Python CLI/config generator

layout/usr/bin/
  rxa-menu            terminal launcher for mod_menu.py

preview/
  catalog_sidebar_preview.html
                      standalone sample of the two-pane sidebar UI
  catalog_sidebar_preview.png
                      rendered preview screenshot

The tweak reads resources from:
  /var/jb/Library/Application Support/RAACHEATMenuDebug/   (rootless)
  /Library/Application Support/RAACHEATMenuDebug/          (rootful)

BUILD OPTIONS
-------------
Option A: macOS or Linux with Theos
  1. Install Theos:
       https://theos.dev/docs/installation
     You also need an iOS SDK in $THEOS/sdks and ldid.
  2. From this folder:
       export THEOS=$HOME/theos
       make clean package FINALPACKAGE=1
  3. The .deb appears in ./packages/. Run ./build_deb.sh instead of make if
     you want it copied to packages/Rxaa.deb automatically.
  4. Install it on a jailbroken device with Filza, Sileo, or:
       dpkg -i packages/Rxaa.deb
       killall -9 SpringBoard

  Rootless jailbreak (iOS 15+, Dopamine/palera1n):
       THEOS_PACKAGE_SCHEME=rootless ./build_deb.sh
  The rootless copy is packages/Rxaa-rootless.deb.

Build fix: The earlier "missing a filter property list" stage error is fixed by
RAACHEATMenuDebug.plist in the project root.

Option B: GitHub Actions (no Mac required)
  Push this folder to a GitHub repository. The included workflow uses a macOS
  runner, installs Theos, builds both a rootful and a rootless .deb, and uploads
  two artifacts. The rootful artifact contains Rxaa.deb; the rootless artifact
  contains Rxaa-rootless.deb. See .github/workflows/build-deb.yml.

INSTALL NOTES
-------------
- Requires a jailbroken iOS 14+ device with MobileSubstrate/ElleKit.
- The tweak filter is RAACHEATMenuDebug.plist. It matches apps linked against
  com.apple.UIKit.
- The overlay waits for an active UIWindowScene, then adds the floating button.
  It retries indefinitely with exponential backoff and also retries when the app becomes active.
- Fallback opening gesture: triple-tap with four fingers anywhere in the app.
  This opens Rxaa even if the floating button is covered or off-screen.
- Drag the floating button to move it. Tap it without dragging to open the menu.
  The position is remembered per app and is clamped to the screen safe area.
- While the menu is open, it is full screen and intentionally captures game
  touches. Tap Close to dismiss it; the full-screen window is hidden again and
  the game receives touches outside the floating button.
- The sidebar is scrollable on small screens. "CATALOG" lists the five feature
  categories from the native menu. "ALL DATA > Full Catalog" opens a grouped
  browser for all 10 categories and 197 entries, including UI strings,
  identifiers, runtime diagnostics, paths, and format strings.
- The first five categories contain 116 feature entries: 70 actionable rows
  have UI-only switches, and 46 label/help rows are read-only. Full Catalog
  includes 72 actionable rows overall; Apply All / Reset All updates all of
  them plus the three legacy demo keys. If menu_catalog.json is missing, the
  embedded 116-row fallback is used and empty all-data categories are omitted.
- Get Code loads the bundled index.html from the installed Application Support
  directory. If the file is missing, the screen displays the expected rootless
  and rootful paths instead of a blank page.
- The menu is forced to UIModalPresentationFullScreen. If the device rotates or
  the scene resizes, the overlay window, root view, and floating button bounds
  are refreshed.
- The overlay listens for app activation, scene activation, key/visible window
  changes, and app resignation. If the game creates a new match window, the
  52x52 button window is kept at UIWindowLevelAlert + 1001 while the full-screen
  overlay remains hidden unless the menu is open. If the app resigns active
  while the menu is open, the menu is dismissed and both Rxaa windows are
  hidden; the button is restored on the next activation.
- Install the artifact that matches the jailbreak:
    * rootful jailbreak -> Rxaa.deb
    * rootless jailbreak (Dopamine/palera1n) -> Rxaa-rootless.deb
- If the Rxaa icon does not appear:
    * make sure the correct rootful/rootless package was installed
    * respring/reboot userspace, then force-quit and reopen the app
    * check that the package is installed
    * check the catalog files exist at one of the two paths above
    * check the tweak is enabled in your jailbreak's tweak injector
    * check Console/log output for messages beginning with [Rxaa]
- If the menu disappears after joining a match, this build re-shows the button
  when the game swaps key/visible windows. If it still disappears, the game may
  be using a separate process or scene; send the target bundle ID and [Rxaa]
  logs for diagnosis.
- If game controls stop responding, tap the menu's Close button. The full-screen
  menu intentionally captures touches while open; closing it hides that window
  and leaves only the 52x52 button window, so the game is clickable again.
- If the app does not link UIKit, add that app's bundle identifier to the
  Bundles array in RAACHEATMenuDebug.plist. Do not use com.apple.Security unless
  you really need every process, because it injects much more broadly.
- The floating button uses a small button-only window. The full-screen overlay
  window is hidden while the menu is closed, so the game is clickable everywhere
  except the 52x52 button. The Rxaa list itself opens as a full-screen modal
  with its own Close button.

PREVIEW
-------
Open preview/catalog_sidebar_preview.html in a browser for a static, interactive
sample of the new layout. It uses sample rows only; it does not read
menu_catalog.json and does not connect to a game. The PNG in the same folder is
a rendered screenshot for quick review.

SAFETY
------
This project is a static code browser, not a game cheat. Do not use the original
cracked APK on a personal device. Game cheating violates the game's rules and
can get the account banned.
