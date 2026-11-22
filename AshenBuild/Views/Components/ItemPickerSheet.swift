import SwiftUI

/// A titled group of choices in an `ItemPicker`.
struct PickerGroup<Item: Identifiable>: Identifiable {
    let title: String?
    let items: [Item]
    var id: String { title ?? "_all" }
}

/// Settings-style "choose one, or None" screen, pushed onto the navigation stack.
/// Reused for weapons, armor pieces and rings. Selecting a row pops back.
struct ItemPicker<Item: Identifiable, RowContent: View>: View where Item.ID == String {
    let title: String
    let groups: [PickerGroup<Item>]
    let selectedID: String?
    let searchKey: (Item) -> String
    @ViewBuilder let rowContent: (Item) -> RowContent
    let onSelect: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredGroups: [PickerGroup<Item>] {
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            let matches = group.items.filter { searchKey($0).localizedCaseInsensitiveContains(query) }
            return matches.isEmpty ? nil : PickerGroup(title: group.title, items: matches)
        }
    }

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    choiceRow(id: nil) {
                        Text("None")
                    }
                }
            }
            ForEach(filteredGroups) { group in
                Section {
                    ForEach(group.items) { item in
                        choiceRow(id: item.id) { rowContent(item) }
                    }
                } header: {
                    if let title = group.title { Text(title) }
                }
            }
        }
        .overlay {
            if !query.isEmpty && filteredGroups.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func choiceRow<Label: View>(id: String?, @ViewBuilder label: () -> Label) -> some View {
        Button {
            onSelect(id)
            dismiss()
        } label: {
            HStack {
                label()
                Spacer(minLength: 8)
                if selectedID == id {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .tint(.primary)
        .accessibilityAddTraits(selectedID == id ? .isSelected : [])
    }
}

/// Small secondary line under a picker row's title ("12.0 wt · STR 16 · DEX 9").
struct DetailLine: View {
    let parts: [String]

    init(_ parts: [String]) { self.parts = parts.filter { !$0.isEmpty } }

    var body: some View {
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
