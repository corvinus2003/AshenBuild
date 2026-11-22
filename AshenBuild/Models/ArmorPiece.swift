import Foundation

enum ArmorSlot: String, Codable, CaseIterable, Identifiable {
    case head, chest, hands, legs
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct PhysicalDefense: Codable, Hashable {
    var standard: Double = 0
    var strike: Double = 0
    var slash: Double = 0
    var thrust: Double = 0
}

struct ElementalDefense: Codable, Hashable {
    var magic: Double = 0
    var fire: Double = 0
    var lightning: Double = 0
    var dark: Double = 0
}

struct Resistances: Codable, Hashable {
    var bleed: Double = 0
    var poison: Double = 0
    var frost: Double = 0
    var curse: Double = 0
}

struct ArmorPiece: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slot: ArmorSlot
    let weight: Double
    let poise: Double
    let physicalDefense: PhysicalDefense
    let elementalDefense: ElementalDefense
    let resistances: Resistances
}
