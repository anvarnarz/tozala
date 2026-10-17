# Changelog

## 2026-10-17 — 0.1.0 First release

### Added
- Five cleaning categories: temp files, Bin, unused apps (90+ days), large files (500 MB+), login items.
- Everything is moved to the Bin; Empty Bin is the only permanent action and asks first.
- Login items turn off and on with `launchctl disable/enable`, no admin password needed.
- Unused apps use Spotlight's last-used date, falling back to the executable's access time when Spotlight has none.
- Ertaga kech design system, light and dark mode, app icon drawn in code.
- Engine self-test (`scripts/selftest.swift`).
