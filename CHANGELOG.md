# Changelog

## 2026-10-17 — Readable login items (0.1.2)

### Changed
- Login items show the app name and icon (e.g. *OneDrive*, *Logi Options+*) instead of the raw launchd label, which moves to the subtitle. Plain scripts show their file name.

## 2026-10-17 — DMG installer (0.1.1)

### Added
- `Tozala.dmg` installer: open it and drag Tozala onto Applications. Build it with `./build.sh --dmg`.

## 2026-10-17 — First release (0.1.0)

### Added
- Five cleaning categories: temp files, Bin, unused apps (90+ days), large files (500 MB+), login items.
- Everything is moved to the Bin; Empty Bin is the only permanent action and asks first.
- Login items turn off and on with `launchctl disable/enable`, no admin password needed.
- Unused apps use Spotlight's last-used date, falling back to the executable's access time when Spotlight has none.
- Ertaga kech design system, light and dark mode, app icon drawn in code.
- Engine self-test (`scripts/selftest.swift`).
