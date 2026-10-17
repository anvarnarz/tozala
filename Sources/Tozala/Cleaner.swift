import AppKit
import CoreServices
import Foundation

enum Category: String, CaseIterable, Identifiable { case caches, bin, apps, large, login; var id: String { rawValue } }

struct Item: Identifiable, Hashable {
    let id: URL            // file/app/plist URL
    let name: String
    let detail: String     // e.g. path, "Last used 4 months ago", program path
    let size: Int64        // bytes; 0 for login items
    var enabled = true     // login items only
    var app: URL? = nil    // login items only: the app the agent belongs to, for its icon
}

struct ScanResult { var items: [Item]; var needsFullDiskAccess = false }

/// Scans are read-only. Removal always goes to the Trash; only `emptyBin` is permanent.
enum Cleaner {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let binURL = home.appendingPathComponent(".Trash")
    static let largeThreshold: Int64 = 500_000_000
    static let unusedDays = 90
    static let ownBundleID = "dev.mohir.tozala"
    static let protectedPrefixes = ["/System", "/usr", "/bin", "/sbin", "/private/var/db"]

    enum Failure: LocalizedError {
        case launchctl(String)
        var errorDescription: String? { switch self { case .launchctl(let msg): msg } }
    }

    // MARK: - Public API

    static func scan(_ c: Category) async -> ScanResult {
        await Task.detached(priority: .userInitiated) { scanSync(c) }.value
    }

    /// Moves each item to the Trash. `freed` counts the sizes of the items that moved; `failed` lists names that didn't.
    static func trash(_ items: [Item]) async -> (freed: Int64, failed: [String]) {
        await Task.detached(priority: .userInitiated) {
            var freed: Int64 = 0, failed: [String] = []
            for item in items {
                if isProtected(item.id) { failed.append(item.name); continue }
                do { try FileManager.default.trashItem(at: item.id, resultingItemURL: nil); freed += item.size }
                catch { failed.append(item.name) }
            }
            return (freed, failed)
        }.value
    }

    /// Permanently deletes the contents of ~/.Trash (the folder itself stays). The UI confirms first.
    static func emptyBin() async throws -> Int64 {
        try await Task.detached(priority: .userInitiated) { try emptyDirectory(binURL) }.value
    }

    static func setLoginItem(_ item: Item, enabled: Bool) async throws {
        try await Task.detached {
            guard let data = try? Data(contentsOf: item.id), let label = parseAgent(data)?.label,
                  !label.hasPrefix("com.apple.") else { throw Failure.launchctl("Not a user login item.") }
            let target = "gui/\(getuid())/\(label)"
            let r = try launchctl([enabled ? "enable" : "disable", target])
            if r.status != 0 { throw Failure.launchctl(r.output.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if !enabled { _ = try? launchctl(["bootout", target]) } // stops it now; fails harmlessly if not loaded
        }.value
    }

    // MARK: - Scans (synchronous; `scan` runs them off the main thread)

    static func scanSync(_ c: Category) -> ScanResult {
        switch c {
        case .caches:
            let fm = FileManager.default
            return ScanResult(items: scanCaches(dirs: [home.appendingPathComponent("Library/Caches"),
                                                       home.appendingPathComponent("Library/Logs"), fm.temporaryDirectory]))
        case .bin: return scanBin(binURL)
        case .apps: return ScanResult(items: scanApps(dirs: [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]))
        case .large: return ScanResult(items: scanLarge(root: home, skip: [home.appendingPathComponent("Library")]))
        case .login:
            let out = (try? launchctl(["print-disabled", "gui/\(getuid())"]).output) ?? ""
            return ScanResult(items: scanLogin(dirs: [home.appendingPathComponent("Library/LaunchAgents"), URL(fileURLWithPath: "/Library/LaunchAgents")],
                                               disabled: parseDisabled(out)))
        }
    }

    /// One item per top-level child, recursive size.
    static func scanCaches(dirs: [URL]) -> [Item] {
        var items: [Item] = []
        for dir in dirs {
            for url in children(dir) where url.lastPathComponent != ".DS_Store" && !url.lastPathComponent.contains(ownBundleID) {
                let size = size(of: url)
                if size > 0 { items.append(Item(id: url, name: url.lastPathComponent, detail: tilde(url), size: size)) }
            }
        }
        return items.sorted { $0.size > $1.size }
    }

    /// Total size + top-level item count. A permission error on the folder means Full Disk Access is missing.
    static func scanBin(_ bin: URL) -> ScanResult {
        guard let kids = try? FileManager.default.contentsOfDirectory(at: bin, includingPropertiesForKeys: nil) else {
            return ScanResult(items: [], needsFullDiskAccess: true)
        }
        let visible = kids.filter { $0.lastPathComponent != ".DS_Store" }
        guard !visible.isEmpty else { return ScanResult(items: []) }
        let total = visible.reduce(Int64(0)) { $0 + size(of: $1) }
        return ScanResult(items: [Item(id: bin, name: "Bin", detail: "\(visible.count) item\(visible.count == 1 ? "" : "s")", size: total)])
    }

    /// `.app` bundles last used more than `unusedDays` ago (or never, per Spotlight). Apple apps and Tozala are skipped.
    static func scanApps(dirs: [URL], now: Date = Date()) -> [Item] {
        let cutoff = now.addingTimeInterval(-Double(unusedDays) * 86_400)
        let rel = RelativeDateTimeFormatter()
        var items: [Item] = []
        for dir in dirs {
            for url in children(dir) where url.pathExtension == "app" {
                let bundleID = Bundle(url: url)?.bundleIdentifier ?? ""
                if bundleID.hasPrefix("com.apple.") || bundleID == ownBundleID { continue }
                let used = lastUsed(url)
                if let used, used >= cutoff { continue }
                let detail = used.map { "Last used " + rel.localizedString(for: $0, relativeTo: now) } ?? "Never opened"
                items.append(Item(id: url, name: url.deletingPathExtension().lastPathComponent, detail: detail, size: size(of: url)))
            }
        }
        return items.sorted { $0.size > $1.size }
    }

    /// Regular files of at least `minBytes` (logical size) under `root`. Hidden entries, packages and `skip` dirs are not entered.
    static func scanLarge(root: URL, minBytes: Int64 = largeThreshold, skip: [URL] = []) -> [Item] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let skipPaths = Set(skip.map { $0.standardizedFileURL.path })
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                     options: [.skipsHiddenFiles, .skipsPackageDescendants],
                                                     errorHandler: { _, _ in true }) else { return [] }
        var items: [Item] = []
        for case let url as URL in e {
            if skipPaths.contains(url.standardizedFileURL.path) { e.skipDescendants(); continue }
            guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true,
                  let bytes = v.fileSize.map(Int64.init), bytes >= minBytes else { continue }
            items.append(Item(id: url, name: url.lastPathComponent, detail: tilde(url), size: bytes))
        }
        return items.sorted { $0.size > $1.size }
    }

    /// LaunchAgent plists (`com.apple.*` skipped); enabled unless launchctl lists the label as disabled.
    static func scanLogin(dirs: [URL], disabled: Set<String>) -> [Item] {
        var items: [Item] = []
        for dir in dirs {
            for url in children(dir) where url.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: url), let agent = parseAgent(data), !agent.label.hasPrefix("com.apple.") else { continue }
                let app = owningApp(agent.program)
                let name = app.map { (FileManager.default.displayName(atPath: $0.path) as NSString).deletingPathExtension }
                    ?? (agent.program.isEmpty ? agent.label : (agent.program as NSString).lastPathComponent)
                items.append(Item(id: url, name: name, detail: agent.label, size: 0, enabled: !disabled.contains(agent.label), app: app))
            }
        }
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Outermost `.app` in a program path: `/Applications/OneDrive.app/Contents/SyncReporter.app/…` → OneDrive.app.
    static func owningApp(_ program: String) -> URL? {
        guard let r = program.range(of: ".app/") ?? (program.hasSuffix(".app") ? program.range(of: ".app", options: .backwards) : nil) else { return nil }
        return URL(fileURLWithPath: String(program[..<r.upperBound]).replacingOccurrences(of: ".app/", with: ".app"))
    }

    // MARK: - Parsing

    /// Label plus `Program` or `ProgramArguments[0]` ("" if neither) from a LaunchAgent plist.
    static func parseAgent(_ data: Data) -> (label: String, program: String)? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let label = plist["Label"] as? String, !label.isEmpty else { return nil }
        let program = plist["Program"] as? String ?? (plist["ProgramArguments"] as? [String])?.first ?? ""
        return (label, program)
    }

    /// Labels marked disabled in `launchctl print-disabled` output (lines like `"com.foo" => disabled`).
    static func parseDisabled(_ output: String) -> Set<String> {
        var labels = Set<String>()
        for line in output.split(separator: "\n") {
            let parts = line.components(separatedBy: "=>")
            guard parts.count == 2 else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if value == "disabled" || value == "true" { labels.insert(parts[0].trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"")))) }
        }
        return labels
    }

    // MARK: - Helpers

    /// Allocated bytes of a file, or of everything inside a directory. Symlinks are never followed (and count as 0).
    static func size(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey]
        func own(_ u: URL) -> Int64 {
            guard let v = try? u.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { return 0 }
            return Int64(v.totalFileAllocatedSize ?? 0)
        }
        let top = own(url)
        if top > 0 { return top }
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) else { return 0 }
        var total: Int64 = 0
        for case let u as URL in e { total += own(u) }
        return total
    }

    /// Removes everything inside `dir`, keeping `dir`. Returns bytes freed; throws if it can't be listed.
    static func emptyDirectory(_ dir: URL) throws -> Int64 {
        let fm = FileManager.default
        var freed: Int64 = 0
        for url in try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            let bytes = size(of: url)
            if (try? fm.removeItem(at: url)) != nil { freed += bytes }
        }
        return freed
    }

    /// True for system locations, Tozala itself, and Apple apps. Symlinks are resolved first.
    static func isProtected(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        if protectedPrefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { return true }
        if path == Bundle.main.bundleURL.resolvingSymlinksInPath().path { return true }
        let id = url.pathExtension == "app" ? Bundle(url: url)?.bundleIdentifier ?? "" : ""
        return id.hasPrefix("com.apple.") || id == ownBundleID
    }

    static func launchctl(_ args: [String]) throws -> (status: Int32, output: String) {
        let p = Process(), pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = pipe; p.standardError = pipe
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile() // drain before waiting so a full pipe can't stall the child
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    private static func children(_ dir: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    }

    /// Spotlight's last-used date, or the executable's access time: Spotlight often has no usage data at all.
    private static func lastUsed(_ url: URL) -> Date? {
        let spotlight = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL).flatMap { MDItemCopyAttribute($0, kMDItemLastUsedDate) as? Date }
        let accessed = Bundle(url: url)?.executableURL.flatMap { try? $0.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate }
        return [spotlight, accessed].compactMap { $0 }.max()
    }

    private static func tilde(_ url: URL) -> String { (url.path as NSString).abbreviatingWithTildeInPath }
}
