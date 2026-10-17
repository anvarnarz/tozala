import SwiftUI

struct ContentView: View {
    @Environment(Model.self) private var model
    var showAbout: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(showAbout: showAbout).frame(width: 248)
            Rectangle().fill(Theme.divider).frame(width: 1)
            DetailView(category: model.current)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandBackground())
        .foregroundStyle(Theme.text)
        .tint(Theme.accent)
    }
}

/// Large line icon in a softly lit tile, used at the top of each state.
private struct Badge: View {
    let symbol: String
    var color: Color = Theme.accentInk
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 26, weight: .regular))
            .foregroundStyle(color)
            .frame(width: 64, height: 64)
            .card(radius: 16)
            .background(Circle().fill(color.opacity(0.25)).blur(radius: 24))
    }
}

private struct Heading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(Theme.font(22, .semibold)).tracking(-0.2)
            Text(subtitle).font(Theme.font(14)).foregroundStyle(Theme.text2).multilineTextAlignment(.center).lineLimit(2)
        }
    }
}

/// Green checkbox in the design system's accent, black tick on bright green.
private struct Checkbox: View {
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isOn ? Theme.accent : Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(isOn ? Theme.accent : Theme.border, lineWidth: 1.5))
                .overlay { if isOn { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.onAccent) } }
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isOn)
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    @Environment(Model.self) private var model
    let showAbout: () -> Void
    @AppStorage(Theme.darkModeKey) private var dark = false
    @State private var logoHover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Text("Tozala").overline()
                Spacer()
                Button { dark.toggle(); Theme.applyAppearance(dark: dark) } label: {
                    Image(systemName: dark ? "sun.max" : "moon").font(.system(size: 14)).foregroundStyle(Theme.text3)
                }
                .buttonStyle(.plain).help(dark ? "Light mode" : "Dark mode")
                Button(action: showAbout) { Image(systemName: "info.circle").font(.system(size: 14)).foregroundStyle(Theme.text3) }
                    .buttonStyle(.plain).help("About Tozala")
            }
            .padding(.horizontal, 10)

            VStack(spacing: 4) {
                ForEach(Category.allCases) { c in SidebarRow(category: c) }
            }

            Spacer(minLength: 0)

            Button("Scan all") { model.scanAll() }
                .buttonStyle(PrimaryButton()).frame(maxWidth: .infinity)
                .disabled(model.isScanningAny)

            Link(destination: AboutView.telegram) {
                Group {
                    if let logo = AboutView.logoURL.flatMap(NSImage.init(contentsOf:)) {
                        Image(nsImage: logo).renderingMode(.template).resizable().aspectRatio(contentMode: .fit).frame(height: 14)
                    } else {
                        Text("Ertaga kech").font(Theme.mono(11))
                    }
                }
                .foregroundStyle(logoHover ? Theme.text : Theme.text3)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .onHover { logoHover = $0 }
            .animation(.easeOut(duration: 0.12), value: logoHover)
            .help("Open Ertaga kech on Telegram")
        }
        .padding(.horizontal, 14).padding(.top, 36).padding(.bottom, 18)
    }
}

private struct SidebarRow: View {
    @Environment(Model.self) private var model
    let category: Category
    @State private var hover = false

    var body: some View {
        let active = model.current == category
        Button { model.current = category } label: {
            HStack(spacing: 10) {
                Image(systemName: category.symbol).font(.system(size: 14))
                    .foregroundStyle(active ? Theme.accentInk : Theme.text2).frame(width: 20)
                Text(category.title).font(Theme.font(14, .medium)).lineLimit(1)
                Spacer(minLength: 4)
                if model[category].phase == .scanning {
                    ProgressView().controlSize(.mini)
                } else if let s = model.summary(category) {
                    Text(s).font(Theme.mono(11)).foregroundStyle(Theme.text3)
                }
            }
            .padding(.horizontal, 10).frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(active ? Theme.accentSoft : hover ? Theme.surface : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

// MARK: - Detail

private struct DetailView: View {
    @Environment(Model.self) private var model
    let category: Category

    var body: some View {
        let st = model[category]
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title).font(Theme.font(22, .semibold)).tracking(-0.2)
                    Text(category.blurb).font(Theme.font(13)).foregroundStyle(Theme.text2).lineLimit(1)
                }
                Spacer()
                if st.phase == .ready, !st.needsFullDiskAccess, !st.items.isEmpty {
                    Text(category == .login ? "\(st.items.count) items" : bytes(st.total))
                        .font(Theme.mono(14)).foregroundStyle(Theme.text2)
                }
            }

            if let m = st.message { Banner(message: m) }

            switch st.phase {
            case .idle:
                Placeholder(symbol: category.symbol, title: "Ready to scan", subtitle: "Scanning only looks. Nothing is removed until you choose.") {
                    Button("Scan \(category.title.lowercased())") { model.scan(category) }.buttonStyle(PrimaryButton())
                }
            case .scanning:
                Placeholder(symbol: category.symbol, title: "Scanning…", subtitle: "This can take a moment") { ProgressView().controlSize(.small) }
            case .cleaning:
                Placeholder(symbol: category.symbol, title: "Cleaning…", subtitle: "Please keep Tozala open") { ProgressView().controlSize(.small) }
            case .ready:
                if st.needsFullDiskAccess {
                    Placeholder(symbol: "lock", title: "Full Disk Access needed", subtitle: "macOS keeps the Bin private. Allow Tozala in Privacy & Security, then scan again.") {
                        HStack {
                            Button("Scan again") { model.scan(category) }.buttonStyle(SecondaryButton())
                            Button("Open Settings") { model.openFullDiskAccess() }.buttonStyle(PrimaryButton())
                        }
                    }
                } else if st.items.isEmpty {
                    Placeholder(symbol: "checkmark", color: Theme.success, title: "Nothing to clean", subtitle: "All tidy here") {
                        Button("Scan again") { model.scan(category) }.buttonStyle(SecondaryButton())
                    }
                } else {
                    ResultsView(category: category)
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 36).padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeOut(duration: 0.25), value: st.phase)
    }
}

private struct Placeholder<Actions: View>: View {
    let symbol: String
    var color: Color = Theme.accentInk
    let title: String
    let subtitle: String
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 18) {
            Badge(symbol: symbol, color: color)
            Heading(title: title, subtitle: subtitle)
            actions
        }
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Result line after an action: freed bytes, or what went wrong.
private struct Banner: View {
    let message: Model.Message
    var body: some View {
        let color = message.isError ? Theme.danger : Theme.success
        HStack(spacing: 8) {
            Image(systemName: message.isError ? "exclamationmark.triangle" : "checkmark.circle").foregroundStyle(color)
            Text(message.text).font(Theme.font(13, .medium)).lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(color.opacity(0.35)))
        .transition(.opacity)
    }
}

// MARK: - Results

private struct ResultsView: View {
    @Environment(Model.self) private var model
    let category: Category
    @State private var confirmEmpty = false

    var body: some View {
        let st = model[category]
        let all = st.selected.count == st.items.count
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                if category.isSelectable {
                    HStack(spacing: 12) {
                        Checkbox(isOn: all) { model.selectAll(category, !all) }
                        Text("Select all").font(Theme.font(13, .medium))
                        Spacer()
                        Text("\(st.selected.count) of \(st.items.count) selected").font(Theme.mono(11)).foregroundStyle(Theme.text3)
                    }
                    .padding(.horizontal, 14).frame(height: 38)
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(st.items) { item in
                            ItemRow(category: category, item: item)
                            if item.id != st.items.last?.id { Rectangle().fill(Theme.divider).frame(height: 1).padding(.leading, 14) }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .card()

            HStack {
                Button("Rescan") { model.scan(category) }.buttonStyle(SecondaryButton())
                Spacer()
                switch category {
                case .caches, .apps, .large:
                    Button("Move to Bin — \(bytes(st.selectedSize))") { model.trashSelected(category) }
                        .buttonStyle(PrimaryButton()).disabled(st.selected.isEmpty)
                case .bin:
                    Button("Empty Bin") { confirmEmpty = true }.buttonStyle(PrimaryButton())
                case .login:
                    Text("Changes apply immediately").font(Theme.mono(11)).foregroundStyle(Theme.text3)
                }
            }
        }
        .alert("Empty the Bin?", isPresented: $confirmEmpty) {
            Button("Empty Bin", role: .destructive) { model.emptyBin() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(bytes(st.total)) will be deleted permanently. This can’t be undone.")
        }
    }
}

private struct ItemRow: View {
    @Environment(Model.self) private var model
    let category: Category
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            if category.isSelectable {
                Checkbox(isOn: model[category].selected.contains(item.id)) { model.toggle(category, item.id) }
            }
            icon.frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(Theme.font(14, .medium)).lineLimit(1).truncationMode(.middle)
                Text(item.detail).font(Theme.mono(11)).foregroundStyle(Theme.text3).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            switch category {
            case .login:
                Toggle(item.name, isOn: Binding(get: { item.enabled }, set: { model.setLogin(item, enabled: $0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Theme.accent)
            default:
                Text(bytes(item.size)).font(Theme.mono(12)).foregroundStyle(Theme.text2)
            }
            if category == .large {
                Button { model.reveal(item.id) } label: { Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.text3) }
                    .buttonStyle(.plain).help("Reveal in Finder")
            }
        }
        .padding(.horizontal, 14).frame(height: 50)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var icon: some View {
        switch category {
        case .caches, .apps, .large:
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.id.path)).resizable()
        case .bin:
            Image(systemName: "trash").font(.system(size: 16)).foregroundStyle(Theme.accentInk)
        case .login:
            Image(systemName: "power").font(.system(size: 16)).foregroundStyle(Theme.accentInk)
        }
    }
}

// MARK: - About

struct AboutView: View {
    static let telegram = URL(string: "https://t.me/ertagakech")!
    static var logoURL = Bundle.main.url(forResource: "ertagakech-logo", withExtension: "svg")
    @State private var hover = false

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 112, height: 112)
                .shadow(color: Theme.accent.opacity(0.35), radius: 24)
            Text("Tozala").font(Theme.font(26, .bold)).tracking(-0.4).padding(.top, 14)
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .font(Theme.mono(11)).foregroundStyle(Theme.text3).padding(.top, 4)
            Text("A tidy-up for your Mac")
                .font(Theme.font(13)).foregroundStyle(Theme.text2).padding(.top, 10)

            Rectangle().fill(Theme.divider).frame(height: 1).padding(.vertical, 22)

            Text("Created by").overline()
            Text("Anvar Narzullaev").font(Theme.font(17, .semibold)).padding(.top, 6)

            Link(destination: Self.telegram) {
                VStack(spacing: 10) {
                    if let logo = Self.logoURL.flatMap(NSImage.init(contentsOf:)) {
                        // the wordmark ships white; render it as a template so it follows the text color
                        Image(nsImage: logo).renderingMode(.template).resizable().aspectRatio(contentMode: .fit).frame(height: 22)
                            .foregroundStyle(Theme.text)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane")
                        Text("t.me/ertagakech")
                    }
                    .font(Theme.mono(12))
                    .foregroundStyle(hover ? Theme.text : Theme.text2)
                }
                .padding(.horizontal, 22).padding(.vertical, 16)
                .card()
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.accent.opacity(hover ? 0.5 : 0)))
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
            .padding(.top, 16)
            .help("Open Ertaga kech on Telegram")
        }
        .padding(32)
        .frame(width: 360)
        .background(BrandBackground())
        .foregroundStyle(Theme.text)
    }
}
