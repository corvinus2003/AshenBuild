import SwiftUI

/// Grid of weapon cards. Each melee card shows the attack rating this build would get with
/// that weapon (uninfused, at the slot's upgrade level); catalysts show their spell buff;
/// shields and ranged weapons show their base attack.
struct WeaponGridPicker: View {
    enum Sort: String, CaseIterable, Identifiable {
        case attack = "Attack Rating", name = "Name", weight = "Weight"
        var id: Self { self }
    }

    let title: String
    let spec: BuildSpec
    let setup: WeaponSetup
    /// Called with the chosen weapon and the upgrade level its card showed.
    let onSelect: (String?, Int) -> Void

    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category: String?
    @AppStorage("weaponSort") private var sort: Sort = .attack

    struct Entry: Identifiable {
        let weapon: Weapon
        let value: Double
        let valueLabel: String
        let upgrade: Int
        let missing: Set<StatType>
        var id: String { weapon.id }
    }

    private var entries: [Entry] {
        let report = BuildCalculator.report(for: spec, data: dataStore)
        let stats = report.effectiveStats
        // Compare at the same upgrade progress as this slot, or as the held weapon for an empty slot.
        let reference = setup.weaponID != nil ? setup : spec.mainHand
        let currentMax = dataStore.weapon(reference.weaponID)?.maxUpgrade ?? 10
        let progress = reference.weaponID == nil ? 0 : Double(reference.upgrade) / Double(max(1, currentMax))
        let all = dataStore.weapons.map { weapon -> Entry in
            let upgrade = Int((progress * Double(weapon.maxUpgrade)).rounded())
            let req = weapon.requirements(.none)
            var missing = Set<StatType>()
            let str = setup.twoHanded && weapon.canTwoHand ? Int((Double(stats[.strength]) * 1.5).rounded(.down)) : stats[.strength]
            if str < req.strength { missing.insert(.strength) }
            if stats[.dexterity] < req.dexterity { missing.insert(.dexterity) }
            if stats[.intelligence] < req.intelligence { missing.insert(.intelligence) }
            if stats[.faith] < req.faith { missing.insert(.faith) }
            if weapon.kind == .catalyst {
                let sb = Double(Formulas.spellBuff(of: weapon, upgrade: upgrade, stats: stats))
                return Entry(weapon: weapon, value: sb, valueLabel: "SB", upgrade: upgrade, missing: missing)
            }
            let result = Formulas.attackRating(
                for: .init(weapon: weapon, upgradeLevel: upgrade, infusion: .none, twoHanded: setup.twoHanded),
                stats: stats)
            return Entry(weapon: weapon, value: result.total, valueLabel: weapon.hasAttackTables ? "AR" : "ATK", upgrade: upgrade, missing: missing)
        }
        let filtered = all.filter { entry in
            (category == nil || entry.weapon.category == category) &&
            (query.isEmpty || entry.weapon.name.localizedCaseInsensitiveContains(query))
        }
        switch sort {
        case .attack:   // usable weapons first, then by value
            return filtered.sorted { ($0.missing.isEmpty ? 1 : 0, $0.value) > ($1.missing.isEmpty ? 1 : 0, $1.value) }
        case .name: return filtered.sorted { $0.weapon.name < $1.weapon.name }
        case .weight: return filtered.sorted { $0.weapon.weight < $1.weapon.weight }
        }
    }

    var body: some View {
        let entries = self.entries
        ScrollView {
            categoryChips
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 12) {
                ForEach(entries) { entry in
                    Button {
                        onSelect(entry.weapon.id, entry.upgrade)
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
            if entries.isEmpty { ContentUnavailableView.search(text: query) }
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
                        Button("Empty This Slot", systemImage: "xmark.circle", role: .destructive) {
                            onSelect(nil, 0)
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
                ForEach(dataStore.weaponCategories, id: \.self) { c in
                    chip(c, selected: category == c) { category = c }
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
                    WeaponBadge(weapon: weapon)
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
                    Text(weapon.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(entry.value.whole)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(entry.missing.isEmpty ? Color.primary : Color.secondary)
                    Text(entry.valueLabel)
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
            let req = entry.weapon.requirements(.none)
            let reqs = Optimizer.damageStats.compactMap { stat -> (StatType, Int)? in
                let value = req.requirement(for: stat)
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

/// Category abbreviation in a tinted rounded rectangle.
struct WeaponBadge: View {
    let weapon: Weapon
    var compact = false

    var body: some View {
        Text(weapon.abbreviation)
            .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: compact ? 36 : 40, height: compact ? 26 : 28)
            .background(weapon.tint.gradient, in: .rect(cornerRadius: compact ? 6 : 7, style: .continuous))
            .accessibilityHidden(true)
    }
}
