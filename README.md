# AutoHotkey App Launcher

AutoHotkey v2 scripts for launching apps and shortcuts from category menus.

## Requirements

- Windows
- AutoHotkey v2

## Setup

1. Put your own `.lnk`, `.exe`, `.url`, `.bat`, or `.ahk` shortcuts in `ドキュメント\AHK_Launcher`, organized in folders such as `AI`, `ゲーム`, `ブラウザ`, `開発`, and `作業効率化`.
2. Run `ahk_launcher.ahk` for a folder-based menu, or run a category script from `AppMenu` for the larger category menu.
3. `AppMenu\ピン留め用ショートカット作成.ahk` can generate taskbar shortcut files for the category menus.

The personal shortcut folder is intentionally not included in this repository. `ahk_launcher.ahk` accepts a folder path as its first argument; otherwise it uses `OneDrive\ドキュメント\AHK_Launcher` (falling back to the same folder under the user profile).

## Layout

- `ahk_launcher.ahk`: compact folder menu
- `AppMenu\AppMenu_Core.ahk`: shared category menu implementation
- `AppMenu\*.ahk`: category entry points
- `AppMenu\icons\`: category icons
