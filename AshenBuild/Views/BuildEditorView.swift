import SwiftUI

enum EditorSection: String, CaseIterable, Identifiable {
    case character = "Stats"
    case weapons = "Weapons"
    case armor = "Armor"
    case summary = "Summary"
    case optimize = "Optimize"

    var id: Self { self }
}

/// Edits one build. A segmented control under the navigation bar switches between the
/// five sections (a tab bar belongs at the app's top level, not on a pushed screen).
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
            case .summary: SummaryTab(build: build)
            case .optimize: OptimizeTab(build: build)
            }
        }
        .topAccessoryBar {
            Picker("Section", selection: $section) {
                ForEach(EditorSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
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
