import SwiftUI

/// One attribute row: name and what it governs, a value you can tap and type, and a
/// system stepper (hold to repeat). `minimum` is the starting class's base value:
/// typing a number below it, or above 99, is refused and explained.
struct StatStepper: View {
    let stat: StatType
    @Binding var value: Int
    let minimum: Int
    let className: String
    var focus: FocusState<StatType?>.Binding

    @State private var draft = ""
    @State private var error: String?

    private var added: Int { value - minimum }
    private var isEditing: Bool { focus.wrappedValue == stat }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.displayName)
                Group {
                    if let error {
                        Text("\(Image(systemName: "exclamationmark.circle.fill")) \(error)")
                            .foregroundStyle(.red)
                    } else {
                        Text(added > 0 ? "\(stat.blurb) · +\(added)" : stat.blurb)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)

            TextField(stat.displayName, text: $draft, prompt: Text("\(value)"))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title3.weight(.semibold).monospacedDigit())
                .focused(focus, equals: stat)
                .frame(width: 52, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isEditing ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(error != nil ? Color.red : (isEditing ? Color.accentColor : .clear), lineWidth: 1.5)
                )
                .onChange(of: draft) {
                    // Digits only, at most two.
                    let digits = String(draft.filter(\.isNumber).prefix(2))
                    if digits != draft { draft = digits }
                }
                .onSubmit(commit)

            Stepper(stat.displayName, value: $value, in: minimum...99)
                .labelsHidden()
                .fixedSize()
        }
        .onAppear { draft = "\(value)" }
        .onChange(of: value) {
            if !isEditing { draft = "\(value)" }
            error = nil
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                // Start empty so typing replaces the value; the old value shows as the prompt.
                error = nil
                draft = ""
            } else {
                commit()
            }
        }
        .sensoryFeedback(.selection, trigger: value)
        .sensoryFeedback(.error, trigger: error) { _, new in new != nil }
        .accessibilityElement(children: .contain)
        .accessibilityValue(added > 0 ? "\(value), \(added) above class base" : "\(value)")
    }

    private func commit() {
        guard let typed = Int(draft) else {
            draft = "\(value)"   // nothing typed: keep the value
            return
        }
        if typed < minimum {
            error = "\(className) minimum: \(minimum)"
            draft = "\(value)"
            clearErrorLater()
        } else if typed > 99 {
            error = "Maximum: 99"
            draft = "\(value)"
            clearErrorLater()
        } else {
            value = typed
            draft = "\(typed)"
        }
    }

    private func clearErrorLater() {
        let shown = error
        Task {
            try? await Task.sleep(for: .seconds(3))
            if error == shown { withAnimation { error = nil } }
        }
    }
}

/// A number you can tap and type, or step, kept within `range`. Out-of-range input is
/// refused with a short message. Used for weapon upgrade levels.
struct NumberFieldStepper: View {
    let title: String
    var prefix: String = ""
    @Binding var value: Int
    let range: ClosedRange<Int>
    var focus: FocusState<Bool>.Binding

    @State private var draft = ""
    @State private var error: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let error {
                    Text("\(Image(systemName: "exclamationmark.circle.fill")) \(error)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else {
                    Text("\(prefix)\(range.lowerBound) to \(prefix)\(range.upperBound)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 0) {
                if !prefix.isEmpty {
                    Text(prefix).font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                }
                TextField(title, text: $draft, prompt: Text("\(value)"))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .focused(focus)
                    .frame(width: 40)
            }
            .frame(height: 36)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(focus.wrappedValue ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(error != nil ? Color.red : (focus.wrappedValue ? Color.accentColor : .clear), lineWidth: 1.5)
            )
            .onChange(of: draft) {
                let digits = String(draft.filter(\.isNumber).prefix(2))
                if digits != draft { draft = digits }
            }

            Stepper(title, value: $value, in: range)
                .labelsHidden()
                .fixedSize()
        }
        .onAppear { draft = "\(value)" }
        .onChange(of: value) { if !focus.wrappedValue { draft = "\(value)" }; error = nil }
        .onChange(of: focus.wrappedValue) { _, editing in
            if editing { error = nil; draft = "" } else { commit() }
        }
        .sensoryFeedback(.selection, trigger: value)
    }

    private func commit() {
        guard let typed = Int(draft) else { draft = "\(value)"; return }
        if range.contains(typed) {
            value = typed
            draft = "\(typed)"
        } else {
            error = "Choose \(range.lowerBound) to \(range.upperBound)"
            draft = "\(value)"
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation { error = nil }
            }
        }
    }
}
