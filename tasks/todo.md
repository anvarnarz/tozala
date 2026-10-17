# Tozala v0.1.0 — spec

Native macOS cleaner (SwiftUI, Apple silicon, macOS 15+), same stack and build style as `../siqaman`:
no Xcode project, `swiftc` via `build.sh`, Ertaga kech design system (`Sources/Tozala/Theme.swift`, copied verbatim).
"Tozala" = "clean it" in Uzbek. Bundle id `dev.mohir.tozala`.

## Safety rules (non-negotiable)
- Everything removed goes to the **Trash** (`FileManager.trashItem`) — recoverable. Only "Empty Bin" is permanent, behind a confirm dialog.
- Nothing is removed without the user ticking it and pressing the action button. Scans are read-only.
- Never touch `/System`, `/usr`, `/bin`, `/sbin`, `/private/var/db`, Apple apps, or Tozala itself.
- Never follow symlinks while scanning.

## Categories
1. **Temp & caches**: top-level children of `~/Library/Caches`, `~/Library/Logs`, and `FileManager.temporaryDirectory`. One item per child, recursive size.
2. **Bin**: `~/.Trash` total size + item count. Action: empty (permanent, confirm). Reading `~/.Trash` needs Full Disk Access → on permission error, return a `needsFullDiskAccess` flag; UI shows a button opening `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`.
3. **Unused apps**: `/Applications/*.app` and `~/Applications/*.app` whose last-used date (`kMDItemLastUsedDate` via `MDItemCreateWithURL`) is older than 90 days or nil. Skip bundle ids `com.apple.*` and `dev.mohir.tozala`. Show the name, icon (`NSWorkspace.shared.icon(forFile:)`), size and last-used date. Action: move the app to the Trash.
4. **Large files**: regular files ≥ 500 MB under `~` (skip `~/Library`, `~/.Trash`, hidden dirs, and package contents). Action: move to the Trash. "Reveal in Finder" per row.
5. **Login items**: plists in `~/Library/LaunchAgents` and `/Library/LaunchAgents` (label from `Label` key, program from `Program`/`ProgramArguments[0]`). Enabled state from `launchctl print-disabled gui/<uid>`. Toggle: `launchctl disable|enable gui/<uid>/<label>` and, when disabling, `launchctl bootout gui/<uid>/<label>` (ignore failure). Persistent and reversible, no root needed. Skip `com.apple.*`.
   ponytail: SMAppService / legacy System Events login items aren't listed; add when users ask (needs Automation permission).

## Engine API (Sources/Tozala/Cleaner.swift) — contract between engine and UI
```swift
enum Category: String, CaseIterable, Identifiable { case caches, bin, apps, large, login; var id: String { rawValue } }

struct Item: Identifiable, Hashable {
    let id: URL            // file/app/plist URL
    let name: String
    let detail: String     // e.g. path, "Last used 4 months ago", program path
    let size: Int64        // bytes; 0 for login items
    var enabled = true     // login items only
}

struct ScanResult { var items: [Item]; var needsFullDiskAccess = false }

enum Cleaner {
    static func scan(_ c: Category) async -> ScanResult              // read-only, runs off the main thread
    static func trash(_ items: [Item]) async -> (freed: Int64, failed: [String])   // caches, apps, large
    static func emptyBin() async throws -> Int64                    // returns bytes freed
    static func setLoginItem(_ item: Item, enabled: Bool) async throws
}
```

## UI (single window, ~760×520, like Siqaman's windowing)
- Sidebar: 5 categories (SF Symbol + name + size found, overline header "TOZALA"), plus a "Scan all" primary button; Ertaga kech logo at the bottom linking to https://t.me/ertagakech.
- Detail: header (category title in Bricolage 22 semibold, total size in Geist Mono), list of `Item` rows in a `.card()` with checkboxes (green accent), select all, and a primary action button ("Move to Bin — 1.2 GB", "Empty Bin", Login items use per-row toggles instead).
- States: idle (prompt to scan), scanning (progress), results, empty ("Nothing to clean"), done toast with bytes freed.
- `BrandBackground`, `PrimaryButton`, `SecondaryButton`, `card()`, `overline()` from Theme.swift. Light/dark toggle like Siqaman's. About window like Siqaman's.
- Sizes via `ByteCountFormatter`.

## Tasks
- [x] Scaffold: git, Theme, fonts, logo, LICENSE, .gitignore, VERSION
- [x] Engine `Cleaner.swift` + `scripts/selftest.swift` (builder-agent, sonnet)
- [x] UI `TozalaApp.swift`, `Model.swift`, `ContentView.swift`, `scripts/icon.swift`, `Resources/Info.plist`, `build.sh` (builder-agent, sonnet)
- [x] Integrate, build, self-test, screenshot (orchestrator)
- [x] README, CHANGELOG, TODOS, public GitHub repo, push (orchestrator)

## Security checklist
- .env in .gitignore: yes (no env used). No API keys: none. Rate limiting: n/a (no network endpoints or forms).

## Review
- Engine + UI built in parallel by two Sonnet builder agents against the API contract above; integrated with no API changes.
- Found during real-data check: Spotlight returned no `kMDItemLastUsedDate` for any app → everything showed "Never opened". Fixed with an executable-atime fallback.
- Fixed: truncated sidebar labels (wider sidebar, "Temp files"), "Zero KB" → "0 KB", brand tint on switches.
- Verified: `build.sh --no-install` clean, self-test ALL OK, real read-only scans of all 5 categories rendered in light and dark.
- Not verified by hand: the destructive actions on real data (trash, empty Bin, launchctl disable) — covered by the self-test on temp data only.
