import SwiftUI

/// Spells and buffs: spell buff per school from the best equipped catalyst, attuned spells
/// against attunement slots, the weapon buff, and which equipped weapons can take it.
struct MagicTab: View {
    @Bindable var build: SavedBuild
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        let spec = build.spec
        let report = BuildCalculator.report(for: spec, data: dataStore)
        let attuned = spec.loadout.spellIDs.compactMap { dataStore.spell($0) }
        let usedSlots = attuned.reduce(0) { $0 + $1.slots }

        Form {
            Section {
                ForEach([SpellSchool.sorcery, .miracle, .pyromancy]) { school in
                    HStack {
                        Label(school.displayName, systemImage: school.symbol)
                        Spacer()
                        if let best = report.spellBuffs[school] {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("\(best.value)").font(.headline.monospacedDigit()).foregroundStyle(.tint)
                                Text(best.catalyst).font(.caption2).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("No catalyst").foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Spell Buff")
            } footer: {
                Text("Spell damage and weapon buffs scale with spell buff. It comes from the strongest catalyst you have equipped in any slot whose requirements you meet, and grows with Intelligence and Faith.")
            }

            Section {
                ForEach(attuned) { spell in
                    SpellRow(spell: spell, stats: report.effectiveStats, hasCatalyst: spell.school == .item || report.spellBuffs[spell.school] != nil)
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) { remove(spell) }
                        }
                }
                NavigationLink {
                    SpellPicker(build: build)
                } label: {
                    Label("Attune a Spell", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("Attuned Spells")
                    Spacer()
                    Text("\(usedSlots) of \(report.attunementSlots) slots")
                        .textCase(nil)
                        .monospacedDigit()
                        .foregroundStyle(usedSlots > report.attunementSlots ? Color.red : Color.secondary)
                }
            } footer: {
                if usedSlots > report.attunementSlots {
                    Text("More spells than slots: raise Attunement or wear an attunement ring.")
                        .foregroundStyle(.red)
                }
            }

            Section {
                BuffPicker(build: build)
                if let buff = dataStore.spell(spec.loadout.buffID), let summary = buff.buffSummary {
                    LabeledContent("Effect") { Text(summary).multilineTextAlignment(.trailing) }
                    if let gain = report.mainHand?.buffGain, report.buffStatus == .applied {
                        LabeledContent("Adds to your held weapon") { Text("+\(gain.whole) AR").monospacedDigit().foregroundStyle(.green) }
                    }
                }
                ForEach(Array(spec.allWeapons.enumerated()), id: \.offset) { _, setup in
                    if let weapon = dataStore.weapon(setup.weaponID), weapon.kind == .melee, let variant = weapon.variant(setup.infusion) {
                        let ok = variant.isBuffable(at: setup.upgrade)
                        LabeledContent {
                            Text(ok ? "Can be buffed" : "Can't be buffed").foregroundStyle(ok ? Color.green : Color.secondary)
                        } label: {
                            Text("\(weapon.name)\(weapon.infusable && setup.infusion != .none ? " (\(setup.infusion.displayName))" : "")")
                        }
                    }
                }
            } header: {
                Text("Weapon Buff")
            } footer: {
                Text("Only weapons without elemental damage can be buffed: a Fire, Lightning, Dark or Crystal infusion, or a weapon with built-in magic, blocks it. Resins and Blessed Weapon are weaker on paired weapons.")
            }
        }
    }

    private func remove(_ spell: Spell) {
        var l = build.loadout
        if let i = l.spellIDs.firstIndex(of: spell.id) { l.spellIDs.remove(at: i) }
        build.loadout = l
    }
}

private struct SpellRow: View {
    let spell: Spell
    let stats: StatBlock
    let hasCatalyst: Bool

    var body: some View {
        let castable = spell.canCast(stats) && hasCatalyst
        HStack(spacing: 12) {
            Image(systemName: spell.school.symbol)
                .foregroundStyle(castable ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(spell.name)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                if !spell.canCast(stats) {
                    Text(requirementText).font(.footnote).foregroundStyle(.red)
                } else if !hasCatalyst {
                    Text("No catalyst for this school equipped").font(.footnote).foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 4)
            if spell.slots > 0 {
                Text("\(spell.slots) slot\(spell.slots == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        var parts = [spell.typeLabel]
        if spell.fp > 0 { parts.append("\(spell.fp) FP") }
        if spell.element != "none" { parts.append(spell.element.capitalized) }
        return parts.joined(separator: " · ")
    }

    private var requirementText: String {
        var parts: [String] = []
        if stats[.intelligence] < spell.int { parts.append("INT \(spell.int)") }
        if stats[.faith] < spell.fth { parts.append("FTH \(spell.fth)") }
        return "Needs " + parts.joined(separator: ", ")
    }
}

/// All spells by school, searchable; tap to attune.
struct SpellPicker: View {
    @Bindable var build: SavedBuild
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let stats = BuildCalculator.report(for: build.spec, data: dataStore).effectiveStats
        let attuned = Set(build.loadout.spellIDs)
        List {
            ForEach([SpellSchool.sorcery, .miracle, .pyromancy]) { school in
                let list = dataStore.spells.filter {
                    $0.school == school && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
                }
                if !list.isEmpty {
                    Section(school.displayName) {
                        ForEach(list) { spell in
                            Button {
                                var l = build.loadout
                                l.spellIDs.append(spell.id)
                                build.loadout = l
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(spell.name)
                                        DetailLine([spell.typeLabel, spell.fp > 0 ? "\(spell.fp) FP" : "",
                                                    spell.int > 0 ? "INT \(spell.int)" : "", spell.fth > 0 ? "FTH \(spell.fth)" : "",
                                                    spell.slots > 1 ? "\(spell.slots) slots" : ""])
                                    }
                                    Spacer()
                                    if attuned.contains(spell.id) {
                                        Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.accentColor)
                                    } else if !spell.canCast(stats) {
                                        Image(systemName: "lock.fill").foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .tint(.primary)
                            .disabled(attuned.contains(spell.id))
                        }
                    }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search spells")
        .navigationTitle("Attune a Spell")
        .navigationBarTitleDisplayMode(.inline)
    }
}
