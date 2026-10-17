import AppKit
import SwiftUI

@main
struct TozalaApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    // The window is AppKit-owned (see AppDelegate.showWindow), same as Siqaman, so reopening from the Dock is predictable.
    var body: some Scene {
        Settings { EmptyView() }
            .commands { CommandGroup(replacing: .appInfo) { Button("About Tozala") { delegate.showAbout() } } }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Model()
    private var window: NSWindow?
    private var aboutWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Theme.registerFonts()
        Theme.applyAppearance()
        showWindow()
    }

    func showAbout() {
        if aboutWindow == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.backgroundColor = Theme.windowBackground
            w.contentView = NSHostingView(rootView: AboutView())
            w.center()
            aboutWindow = w
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { showWindow(); return true }

    func showWindow() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 540),
                             styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.title = "Tozala"
            w.backgroundColor = Theme.windowBackground
            w.contentView = NSHostingView(rootView: ContentView(showAbout: { [weak self] in self?.showAbout() })
                .environment(model).frame(width: 800, height: 540))
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
