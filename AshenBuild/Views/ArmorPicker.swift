import SwiftUI

/// How the armor picker orders pieces: by name, by weight, or by any defense metric.
enum ArmorSort: Hashable, Identifiable {
    case name, weight, metric(ArmorGoal)

    static var all: [ArmorSort] { [.name, .weight] + ArmorGoal.allCases.map { .metric($0) } }

    var id: String { storageKey }
    var title: String {
        switch self {
        case .name: return "Name"
        case .weight: return "Lightest"
        case .metric(let goal): return "Highest \(goal.rawValue)"
        }
    }
    var storageKey: String {
        switch self {
        case .name: return "name"
        case .weight: return "weight"
        case .metric(let goal): return goal.rawValue
        }
    }
    init(storageKey: String) {
        switch storageKey {
        case "weight": self = .weight
        case "name": self = .name
        default: self = ArmorGoal(rawValue: storageKey).map { .metric($0) } ?? .name
        }
    }
}

/// Pushed list of armor for one slot, sortable by any stat, with the sorted value shown.
struct ArmorPicker: View {
    let slot: ArmorSlot
    let selectedID: String?
    let onSelect: (String?) -> Void

    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("armorSort") private var sortKey = "name"
    @State private var query = ""

    private var sort: ArmorSort { ArmorSort(storageKey: sortKey) }

    private var pieces: [ArmorPiece] {
        let all = dataStore.armor(in: slot).filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
        switch sort {
        case .name: return all.sorted { $0.name < $1.name }
        case .weight: return all.sorted { ($0.weight, $0.name) < ($1.weight, $1.name) }
        case .metric(let goal): return all.sorted { (goal.value($0), -$0.weight) > (goal.value($1), -$1.weight) }
        }
    }

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    row(id: nil) { Text("None") }
                }
            }
            Section {
                ForEach(pieces) { piece in
                    row(id: piece.id) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(piece.name)
                                DetailLine(["\(piece.weight.oneDecimal) wt", "\(piece.physicalDefense.standard.oneDecimal)% phys",
                                            "\(piece.poise.oneDecimal) poise"])
                            }
                            Spacer(minLength: 8)
                            sortedValue(piece)
                        }
                    }
                }
            } header: {
                Text("Sorted by \(sort.title.lowercased())")
            }
        }
        .overlay {
            if pieces.isEmpty && !query.isEmpty { ContentUnavailableView.search(text: query) }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(slot.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Sort", systemImage: "arrow.up.arrow.down") {
                    Picker("Sort By", selection: $sortKey) {
                        ForEach(ArmorSort.all) { Text($0.title).tag($0.storageKey) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sortedValue(_ piece: ArmorPiece) -> some View {
        switch sort {
        case .name: EmptyView()
        case .weight:
            Text(piece.weight.oneDecimal).font(.headline.monospacedDigit())
        case .metric(let goal):
            Text(goal.isAbsorption ? "\(goal.value(piece).oneDecimal)%" : goal.value(piece).oneDecimal)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.tint)
        }
    }

    private func row<Label: View>(id: String?, @ViewBuilder label: () -> Label) -> some View {
        Button {
            onSelect(id)
            dismiss()
        } label: {
            HStack {
                label()
                if selectedID == id {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
        .accessibilityAddTraits(selectedID == id ? .isSelected : [])
    }
}

/// Min-maxing: finds the armor sets that maximize one stat while keeping a chosen roll
/// (and optionally a poise floor), given the weapons and rings already equipped.
struct ArmorOptimizerView: View {
    @Bindable var build: SavedBuild
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss

    @State private var goal: ArmorGoal = .physical
    @State private var roll: Formulas.RollTier = .medium
    @State private var minPoise: Double = 0
    @State private var didSetRoll = false

    var body: some View {
        let spec = build.spec
        let results = Optimizer.bestArmor(spec, goal: goal, roll: roll, minPoise: minPoise, data: dataStore)
        Form {
                Section {
                    Picker("Maximize", selection: $goal) {
                        ForEach(ArmorGoal.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Roll", selection: $roll) {
                        Text("Fast").tag(Formulas.RollTier.fast)
                        Text("Mid").tag(Formulas.RollTier.medium)
                        Text("Fat").tag(Formulas.RollTier.fat)
                    }
                    .pickerStyle(.segmented)
                    Stepper(value: $minPoise, in: 0...100, step: 1) {
                        LabeledContent("Minimum Poise") {
                            Text(minPoise == 0 ? "Any" : "\(Int(minPoise))").monospacedDigit()
                        }
                    }
                } footer: {
                    Text("Counts the weight of your weapons and rings. Every combination of the four slots is checked.")
                }

                if results.isEmpty {
                    Section {
                        ContentUnavailableView("No Armor Fits",
                                               systemImage: "scalemass",
                                               description: Text("Lower the poise floor, pick a heavier roll or raise Vitality."))
                    }
                } else {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, set in
                        Section {
                            ForEach(ArmorSlot.allCases) { slot in
                                LabeledContent(slot.displayName) {
                                    Text(set.pieces[slot]?.name ?? "None")
                                        .foregroundStyle(set.pieces[slot] == nil ? .secondary : .primary)
                                }
                            }
                            HStack {
                                stat(goal.rawValue, goal.isAbsorption ? "\(set.value.oneDecimal)%" : set.value.oneDecimal, highlight: true)
                                stat("Poise", set.poise.oneDecimal)
                                stat("Weight", set.weight.oneDecimal)
                                stat("Load", "\(Int((set.loadFraction * 100).rounded()))%")
                            }
                            Button("Equip This Set", systemImage: "checkmark.circle") {
                                for slot in ArmorSlot.allCases { build.setArmor(set.pieces[slot]?.id, for: slot) }
                                dismiss()
                            }
                        } header: {
                            Text(index == 0 ? "Best" : "Option \(index + 1)")
                        }
                    }
                }
            }
            .navigationTitle("Best Armor")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !didSetRoll else { return }
                didSetRoll = true
                let current = BuildCalculator.report(for: spec, data: dataStore).rollTier
                roll = current == .overburdened ? .fat : current
            }
    }

    private func stat(_ title: String, _ value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(highlight ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
