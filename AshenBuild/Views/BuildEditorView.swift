import SwiftUI

enum EditorSection: String, CaseIterable, Identifiable {
    case character = "Stats"
    case weapons = "Weapons"
    case armor = "Armor"
    case magic = "Magic"
    case summary = "Summary"
    case optimize = "Optimize"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .character: return "person.fill"
        case .weapons: return "shield.lefthalf.filled"
        case .armor: return "tshirt.fill"
        case .magic: return "sparkles"
        case .summary: return "list.bullet.rectangle"
        case .optimize: return "gauge.with.dots.needle.67percent"
        }
    }
}

/// Edits one build. A segmented control under the navigation bar switches between the
/// six sections (a tab bar belongs at the app's top level, not on a pushed screen).
/// All edits write straight into the SwiftData `SavedBuild`, which SwiftData autosaves.
struct BuildEditorView: View {
    @Bindable var build: SavedBuild
    @SceneStorage("BuildEditor.section") private var section: EditorSection = .character

    var body: some View {
        Group {
            switch section {
            case .character: ClassLevelTab(build: build)
            case .weapons: WeaponsTab(build: build)
            case .armor: ArmorTab(build: build)
            case .magic: MagicTab(build: build)
            case .summary: SummaryTab(build: build)
            case .optimize: OptimizeTab(build: build)
            }
        }
        .topAccessoryBar {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EditorSection.allCases) { item in
                            Button {
                                withAnimation(.snappy) { section = item }
                            } label: {
                                Label(item.rawValue, systemImage: item.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(section == item ? Color.white : Color.primary)
                                    .background(section == item ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.tertiarySystemFill)),
                                                in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .id(item)
                            .accessibilityAddTraits(section == item ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .onChange(of: section) { withAnimation { proxy.scrollTo(section, anchor: .center) } }
                .onAppear { proxy.scrollTo(section, anchor: .center) }
            }
        }
        .navigationTitle($build.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            RenameButton()
        }
        .onChange(of: build.name) { build.updatedAt = .now }
        .sensoryFeedback(.selection, trigger: section)
    }
}

extension View {
    /// Pins content under the navigation bar. On iOS 26+ it gets the system scroll-edge
    /// effect; earlier systems get a bar material background.
    @ViewBuilder
    func topAccessoryBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .top) { content() }
        } else {
            safeAreaInset(edge: .top, spacing: 0) {
                content().background(.bar)
            }
        }
    }
}
