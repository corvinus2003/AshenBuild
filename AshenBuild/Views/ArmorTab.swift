import SwiftUI

struct ArmorTab: View {
    @Bindable var build: SavedBuild
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        let report = BuildCalculator.report(for: build.spec, data: dataStore)
        Form {
            Section {
                ForEach(ArmorSlot.allCases) { slot in
                    ArmorSlotRow(slot: slot, armorID: build.spec.armor[slot]) { build.setArmor($0, for: slot) }
                }
                NavigationLink {
                    ArmorOptimizerView(build: build)
                } label: {
                    Label("Find the Best Armor", systemImage: "wand.and.stars")
                        .foregroundStyle(.tint)
                }
            } header: {
                Text("Armor")
            } footer: {
                Text("\(report.load.oneDecimal) of \(report.capacity.oneDecimal) load · \(report.rollTier.rawValue) · \(report.poise.oneDecimal) poise")
            }

            Section {
                RingSlotRow(index: 1, ringID: $build.ring1ID, otherIDs: [build.ring2ID, build.ring3ID, build.ring4ID])
                RingSlotRow(index: 2, ringID: $build.ring2ID, otherIDs: [build.ring1ID, build.ring3ID, build.ring4ID])
                RingSlotRow(index: 3, ringID: $build.ring3ID, otherIDs: [build.ring1ID, build.ring2ID, build.ring4ID])
                RingSlotRow(index: 4, ringID: $build.ring4ID, otherIDs: [build.ring1ID, build.ring2ID, build.ring3ID])
            } header: {
                Text("Rings")
            } footer: {
                Text("Summary shows exactly what each ring changes for this build.")
            }
        }
    }
}

/// Contacts-style row: small slot label over the equipped item, pushing to a picker.
private struct SlotLabel: View {
    let slot: String
    let name: String?
    let detail: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(slot)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(name ?? "None")
                .foregroundStyle(name == nil ? .secondary : .primary)
            DetailLine(detail)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct ArmorSlotRow: View {
    let slot: ArmorSlot
    let armorID: String?
    let onSelect: (String?) -> Void
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        let piece = dataStore.armorPiece(armorID)
        NavigationLink {
            ArmorPicker(slot: slot, selectedID: armorID, onSelect: onSelect)
        } label: {
            SlotLabel(slot: slot.displayName, name: piece?.name, detail: piece.map {
                ["\($0.weight.oneDecimal) wt", "\($0.physicalDefense.standard.oneDecimal)% phys", "\($0.poise.oneDecimal) poise"]
            } ?? [])
        }
    }
}

/// Pick a ring once, then its strength (+1/+2/+3) with a segmented control below it.
private struct RingSlotRow: View {
    let index: Int
    @Binding var ringID: String?
    /// Rings worn in the other slots; the game doesn't allow two of the same ring.
    let otherIDs: [String?]
    @Environment(DataStore.self) private var dataStore

    private var ring: Ring? { dataStore.ring(ringID) }
    private var family: RingFamily? { dataStore.ringFamily(of: ring) }

    private var available: [RingFamily] {
        let taken = Set(otherIDs.compactMap { dataStore.ring($0)?.family })
        return dataStore.ringFamilies.filter { !taken.contains($0.name) }
    }

    var body: some View {
        NavigationLink {
            ItemPicker(
                title: "Ring \(index)",
                groups: [PickerGroup(title: nil, items: available)],
                selectedID: family?.name,
                searchKey: { "\($0.name) \($0.base.effect)" }
            ) { family in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(family.name)
                        if family.variants.count > 1 {
                            Text("+0–\(family.variants.count - 1)")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color(.tertiarySystemFill), in: .capsule)
                        }
                    }
                    DetailLine([family.base.effect])
                }
            } onSelect: { familyName in
                guard let familyName else { ringID = nil; return }
                guard familyName != family?.name,
                      let chosen = dataStore.ringFamilies.first(where: { $0.name == familyName }) else { return }
                ringID = chosen.base.id   // then pick +1/+2/+3 below
            }
        } label: {
            SlotLabel(slot: "Ring \(index)", name: family?.name, detail: ring.map { [$0.effect] } ?? [])
        }

        if let family, family.variants.count > 1 {
            Picker("\(family.name) Level", selection: Binding(get: { ringID ?? "" }, set: { ringID = $0 })) {
                ForEach(family.variants) { variant in
                    Text(variant.level == 0 ? "Base" : "+\(variant.level)").tag(variant.id)
                }
            }
            .pickerStyle(.segmented)
            .sensoryFeedback(.selection, trigger: ringID)
        }
    }
}
