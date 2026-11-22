import SwiftUI

/// Two-column grid of label/value pairs, used for the defense and resistance tables.
struct DefenseGrid: View {
    var percent = false
    let items: [(label: String, value: Double)]

    private let columns = [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items, id: \.label) { item in
                HStack {
                    Text(item.label)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text(percent ? "\(item.value.oneDecimal)%" : "\(item.value.whole)")
                        .monospacedDigit()
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 4)
    }
}
