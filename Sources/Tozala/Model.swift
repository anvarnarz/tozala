import AppKit
import Observation

/// "1.2 GB", Finder-style (decimal units).
func bytes(_ n: Int64) -> String { n == 0 ? "0 KB" : ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }

extension Category {
    var title: String {
        switch self {
        case .caches: "Temp files"
        case .bin: "Bin"
        case .apps: "Unused apps"
        case .large: "Large files"
        case .login: "Login items"
        }
    }

    var symbol: String {
        switch self {
        case .caches: "wind"
        case .bin: "trash"
        case .apps: "square.grid.2x2"
        case .large: "doc.text.magnifyingglass"
        case .login: "power"
        }
    }

    var blurb: String {
        switch self {
        case .caches: "Caches, logs and temporary files"
        case .bin: "Everything waiting in the Bin"
        case .apps: "Not opened in the last 90 days"
        case .large: "Files of 500 MB or more in your home folder"
        case .login: "Background agents that start with your Mac"
        }
    }

    /// Caches, apps and large files are ticked one by one; the Bin is emptied whole; login items have their own switches.
    var isSelectable: Bool { self == .caches || self == .apps || self == .large }
}

@MainActor @Observable
final class Model {
    enum Phase: Equatable { case idle, scanning, ready, cleaning }

    struct Message: Equatable {
        let text: String
        var isError = false
    }

    struct State {
        var phase = Phase.idle
        var items: [Item] = []
        var selected: Set<URL> = []
        var needsFullDiskAccess = false
        var message: Message?

        var total: Int64 { items.reduce(0) { $0 + $1.size } }
        var selectedSize: Int64 { items.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.size } }
    }

    var current = Category.caches
    private(set) var states = Dictionary(uniqueKeysWithValues: Category.allCases.map { ($0, State()) })

    subscript(_ c: Category) -> State { states[c] ?? State() }

    /// Short label for the sidebar: size found, or item count for login items. Nil until scanned.
    func summary(_ c: Category) -> String? {
        let s = self[c]
        guard s.phase == .ready || s.phase == .cleaning else { return nil }
        if s.needsFullDiskAccess { return "—" }
        return c == .login ? "\(s.items.count)" : bytes(s.total)
    }

    // MARK: Scanning (read-only)

    func scan(_ c: Category, keeping message: Message? = nil) {
        guard self[c].phase != .scanning, self[c].phase != .cleaning else { return }
        states[c]?.phase = .scanning
        states[c]?.message = message
        Task {
            let result = await Cleaner.scan(c)
            states[c]?.items = result.items
            states[c]?.needsFullDiskAccess = result.needsFullDiskAccess
            states[c]?.selected = []
            states[c]?.phase = .ready
        }
    }

    func scanAll() { Category.allCases.forEach { scan($0) } }

    var isScanningAny: Bool { Category.allCases.contains { self[$0].phase == .scanning } }

    // MARK: Selection

    func toggle(_ c: Category, _ id: URL) {
        if states[c]?.selected.remove(id) == nil { states[c]?.selected.insert(id) }
    }

    func selectAll(_ c: Category, _ on: Bool) {
        states[c]?.selected = on ? Set(self[c].items.map(\.id)) : []
    }

    // MARK: Actions (only ever on ticked items)

    func trashSelected(_ c: Category) {
        let picked = self[c].items.filter { self[c].selected.contains($0.id) }
        guard c.isSelectable, !picked.isEmpty, self[c].phase == .ready else { return }
        states[c]?.phase = .cleaning
        states[c]?.message = nil
        Task {
            let (freed, failed) = await Cleaner.trash(picked)
            // rescan so the list reflects what is really left on disk
            states[c]?.phase = .idle
            let note = failed.isEmpty ? "Moved to Bin · \(bytes(freed)) freed"
                : "\(bytes(freed)) freed · \(failed.count) couldn’t be moved"
            scan(c, keeping: Message(text: note, isError: !failed.isEmpty))
        }
    }

    func emptyBin() {
        guard self[.bin].phase == .ready else { return }
        states[.bin]?.phase = .cleaning
        states[.bin]?.message = nil
        Task {
            do {
                let freed = try await Cleaner.emptyBin()
                states[.bin]?.phase = .idle
                scan(.bin, keeping: Message(text: "Bin emptied · \(bytes(freed)) freed"))
            } catch {
                states[.bin]?.phase = .ready
                states[.bin]?.message = Message(text: error.localizedDescription, isError: true)
            }
        }
    }

    func setLogin(_ item: Item, enabled: Bool) {
        Task {
            do {
                try await Cleaner.setLoginItem(item, enabled: enabled)
                if let i = self[.login].items.firstIndex(where: { $0.id == item.id }) { states[.login]?.items[i].enabled = enabled }
                states[.login]?.message = nil
            } catch {
                states[.login]?.message = Message(text: error.localizedDescription, isError: true)
            }
        }
    }

    func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }

    func openFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") { NSWorkspace.shared.open(url) }
    }
}
