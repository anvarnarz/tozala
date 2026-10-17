// Engine self-test: swiftc -parse-as-library -swift-version 5 Sources/Tozala/Cleaner.swift scripts/selftest.swift -o build/selftest && build/selftest
// Works on a temp directory only; the one file sent to the real Trash is a throwaway that is removed again.
import Foundation

func check(_ ok: Bool, _ msg: String = "") { if !ok { print("FAIL: \(msg)"); exit(1) } }

@main struct SelfTest {
    static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("tozala-selftest-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        func write(_ path: String, bytes: Int) throws -> URL {
            let url = root.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 7, count: bytes).write(to: url)
            return url
        }

        // size: recursive, symlinks not followed
        _ = try write("tree/a.bin", bytes: 100_000)
        _ = try write("tree/sub/b.bin", bytes: 200_000)
        try fm.createSymbolicLink(at: root.appendingPathComponent("tree/link"), withDestinationURL: root.appendingPathComponent("tree/sub"))
        let size = Cleaner.size(of: root.appendingPathComponent("tree"))
        check(size >= 300_000 && size < 400_000, "size \(size)")
        print("✓ recursive size \(size), symlink ignored")

        // caches: one item per child
        let caches = Cleaner.scanCaches(dirs: [root.appendingPathComponent("tree")])
        check(caches.map(\.name).sorted() == ["a.bin", "sub"], "\(caches.map(\.name))")
        check(caches.first?.name == "sub", "sorted by size")
        print("✓ caches: one item per top-level child")

        // large: sparse files, hidden/skip dirs ignored
        func sparse(_ path: String, _ bytes: Int64) throws {
            let url = root.appendingPathComponent("big/" + path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            check(fm.createFile(atPath: url.path, contents: nil)); let h = try FileHandle(forWritingTo: url)
            try h.truncate(atOffset: UInt64(bytes)); try h.close()
        }
        try sparse("movie.mov", 600_000_000)
        try sparse("small.mov", 400_000_000)
        try sparse(".hidden/secret.mov", 700_000_000)
        try sparse("Library/cache.mov", 700_000_000)
        try sparse("Pkg.app/Contents/huge.bin", 700_000_000)
        let large = Cleaner.scanLarge(root: root.appendingPathComponent("big"), skip: [root.appendingPathComponent("big/Library")])
        check(large.map(\.name) == ["movie.mov"], "\(large.map(\.name))")
        check(large[0].size == 600_000_000, "size \(large[0].size)")
        print("✓ large files: only movie.mov (≥500 MB, not hidden/Library/package)")

        // trash: moves a temp file, reports freed bytes; protected paths refused
        let name = "tozala-trashme-\(UUID().uuidString).bin"
        let victim = try write(name, bytes: 1_000_000)
        let item = Item(id: victim, name: name, detail: "", size: 1_000_000)
        let res = await Cleaner.trash([item, Item(id: URL(fileURLWithPath: "/usr/bin/true"), name: "true", detail: "", size: 1)])
        check(res.freed == 1_000_000 && res.failed == ["true"], "\(res)")
        check(!fm.fileExists(atPath: victim.path), "file still there")
        let inBin = Cleaner.binURL.appendingPathComponent(name)
        check(fm.fileExists(atPath: inBin.path) || (try? fm.contentsOfDirectory(atPath: Cleaner.binURL.path)) == nil, "not in Trash")
        try? fm.removeItem(at: inBin) // leave the real Trash as we found it
        check(Cleaner.isProtected(URL(fileURLWithPath: "/System/Applications/Mail.app")) && !Cleaner.isProtected(victim), "isProtected")
        print("✓ trash: moved \(res.freed) bytes, /usr refused")

        // bin: scan + empty on a fake bin
        let bin = root.appendingPathComponent("fakebin")
        _ = try write("fakebin/x.bin", bytes: 50_000); _ = try write("fakebin/d/y.bin", bytes: 50_000)
        let scanned = Cleaner.scanBin(bin)
        check(scanned.items.count == 1 && scanned.items[0].detail == "2 items" && !scanned.needsFullDiskAccess, "\(scanned)")
        check(Cleaner.scanBin(root.appendingPathComponent("nope")).needsFullDiskAccess, "missing bin should flag access")
        let freed = try Cleaner.emptyDirectory(bin)
        let left = try fm.contentsOfDirectory(atPath: bin.path)
        check(freed == scanned.items[0].size && left.isEmpty, "freed \(freed)")
        print("✓ bin: counted 2 items, emptied \(freed) bytes, folder kept")

        // login items: plist parsing and print-disabled parsing
        let plist: [String: Any] = ["Label": "dev.example.helper", "ProgramArguments": ["/opt/helper/run", "--flag"]]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let agent = Cleaner.parseAgent(data)
        check(agent?.label == "dev.example.helper" && agent?.program == "/opt/helper/run", "\(String(describing: agent))")
        check(Cleaner.parseAgent(Data("junk".utf8)) == nil, "junk plist")
        let sample = """
        disabled services = {
        \t"dev.example.helper" => disabled
        \t"com.other.thing" => enabled
        \t"com.old.style" => true
        }
        """
        let disabled = Cleaner.parseDisabled(sample)
        check(disabled == ["dev.example.helper", "com.old.style"], "\(disabled)")
        let dir = root.appendingPathComponent("agents")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent("dev.example.helper.plist"))
        let login = Cleaner.scanLogin(dirs: [dir], disabled: disabled)
        check(login.count == 1 && !login[0].enabled && login[0].name == "run" && login[0].detail == "dev.example.helper", "\(login)")
        check(Cleaner.owningApp("/Applications/OneDrive.app/Contents/SyncReporter.app/Contents/MacOS/SyncReporter")?.path == "/Applications/OneDrive.app", "outermost app")
        check(Cleaner.owningApp("/opt/homebrew/bin/postgres") == nil, "no app")
        print("✓ login: plist + print-disabled parsing")
        print("ALL OK")
    }
}
