import SwiftUI

extension WeaponCategory {
    /// Short community abbreviation shown on weapon cards.
    var abbreviation: String {
        switch self {
        case .dagger: return "DGR"
        case .straightSword: return "SS"
        case .greatsword: return "GS"
        case .ultraGreatsword: return "UGS"
        case .curvedSword: return "CS"
        case .katana: return "KAT"
        case .thrustingSword: return "TS"
        case .axe: return "AXE"
        case .greataxe: return "GA"
        case .hammer: return "HAM"
        case .greatHammer: return "GH"
        case .spear: return "SPR"
        case .halberd: return "HAL"
        case .whip: return "WHP"
        case .fist: return "FST"
        case .bow: return "BOW"
        case .greatbow: return "GB"
        case .crossbow: return "XBW"
        case .sorceryStaff: return "STF"
        case .talisman: return "TAL"
        case .chime: return "CHM"
        case .pyromancyFlame: return "PYR"
        case .smallShield: return "SH"
        case .greatshield: return "GSH"
        }
    }

    var tint: Color {
        if isCastingTool { return .purple }
        if isShield { return .gray }
        switch self {
        case .bow, .greatbow, .crossbow: return .teal
        default: return .accentColor
        }
    }
}

/// Grid of weapon cards. Each card shows the attack rating this build would get with
/// that weapon at the current upgrade level, so you can compare at a glance.
struct WeaponGridPicker: View {
    enum Sort: String, CaseIterable, Identifiable {
        case attack = "Attack Rating", name = "Name", weight = "Weight"
        var id: Self { self }
    }

    let title: String
    let spec: BuildSpec
    let setup: WeaponSetup
    let onSelect: (String?) -> Void

    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category: WeaponCategory?
    @AppStorage("weaponSort") private var sort: Sort = .attack

    private struct Entry: Identifiable {
        let weapon: Weapon
        let attack: Double
        let meetsRequirements: Bool
        let missing: Set<StatType>
        var id: String { weapon.id }
    }

    private var entries: [Entry] {
        let report = BuildCalculator.report(for: spec, data: dataStore)
        let currentMax = dataStore.weapon(setup.weaponID)?.maxUpgrade ?? 10
        let progress = Double(setup.upgrade) / Double(max(1, currentMax))
        let all = dataStore.weapons.map { weapon -> Entry in
            let trial = WeaponSetup(weaponID: weapon.id, upgrade: Int((progress * Double(weapon.maxUpgrade)).rounded()),
                                    infusion: .none, twoHanded: setup.twoHanded)
            let result = BuildCalculator.weaponReport(trial, effective: report.effectiveStats,
                                                      rings: report.rings, load: report.load, data: dataStore)
            let missing = Set(Optimizer.damageStats.filter { stat in
                var have = report.effectiveStats[stat]
                if stat == .strength && setup.twoHanded && weapon.canTwoHand { have = Int((Double(have) * 1.5).rounded(.down)) }
                return weapon.requirements.requirement(for: stat) > have
            })
            return Entry(weapon: weapon, attack: result?.total ?? 0, meetsRequirements: missing.isEmpty, missing: missing)
        }
        let filtered = all.filter { entry in
            (category == nil || entry.weapon.category == category) &&
            (query.isEmpty || entry.weapon.name.localizedCaseInsensitiveContains(query))
        }
        switch sort {
        case .attack: return filtered.sorted { $0.attack > $1.attack }
        case .name: return filtered.sorted { $0.weapon.name < $1.weapon.name }
        case .weight: return filtered.sorted { $0.weapon.weight < $1.weapon.weight }
        }
    }

    private var categories: [WeaponCategory] {
        WeaponCategory.allCases.filter { c in dataStore.weapons.contains { $0.category == c } }
    }

    var body: some View {
        let entries = self.entries
        ScrollView {
            categoryChips
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 12) {
                ForEach(entries) { entry in
                    Button {
                        onSelect(entry.weapon.id)
                        dismiss()
                    } label: {
                        WeaponCard(entry: entry, selected: entry.weapon.id == setup.weaponID)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .animation(.snappy, value: category)
            .animation(.snappy, value: sort)
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search weapons")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Options", systemImage: "arrow.up.arrow.down") {
                    Picker("Sort By", selection: $sort) {
                        ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if setup.weaponID != nil {
                        Divider()
                        Button("Unequip", systemImage: "xmark.circle", role: .destructive) {
                            onSelect(nil)
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: category == nil) { category = nil }
                ForEach(categories) { c in
                    chip(c.displayName, selected: category == c) { category = c }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .sensoryFeedback(.selection, trigger: category)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.tertiarySystemFill)), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private struct WeaponCard: View {
        let entry: Entry
        let selected: Bool

        var body: some View {
            let weapon = entry.weapon
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(weapon.category.abbreviation)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 28)
                        .background(weapon.category.tint.gradient, in: .rect(cornerRadius: 7, style: .continuous))
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(weapon.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2, reservesSpace: true)
                    Text(weapon.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(entry.attack.whole)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(entry.meetsRequirements ? Color.primary : Color.secondary)
                    Text("AR")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(weapon.weight.oneDecimal) wt")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                requirements
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
            )
            .contentShape(.rect(cornerRadius: 16))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }

        private var requirements: some View {
            let reqs = Optimizer.damageStats.compactMap { stat -> (StatType, Int)? in
                let value = entry.weapon.requirements.requirement(for: stat)
                return value > 0 ? (stat, value) : nil
            }
            return HStack(spacing: 6) {
                ForEach(reqs, id: \.0) { stat, value in
                    Text("\(stat.shortName) \(value)")
                        .foregroundStyle(entry.missing.contains(stat) ? Color.red : Color.secondary)
                }
                if reqs.isEmpty { Text("No requirements").foregroundStyle(.secondary) }
            }
            .font(.caption2.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }
}
