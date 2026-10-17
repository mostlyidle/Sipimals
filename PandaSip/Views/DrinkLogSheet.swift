import SwiftUI

struct DrinkLogSheet: View {
    let store: HydrationStore
    let onLog: (DrinkEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var drink = DrinkKind.water
    @State private var amount = 250
    @State private var custom = ""
    @State private var usesCustom = false
    @FocusState private var customFocused: Bool

    private var volumeML: Int? {
        usesCustom ? Int(custom.trimmingCharacters(in: .whitespacesAndNewlines)) : amount
    }
    private var validAmount: Bool { volumeML.map { (1...5_000).contains($0) } ?? false }
    private var credit: Double { Double(volumeML ?? 0) * Double(drink.factorPercent) / 100 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A sip of something good.")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text("Pick your drink. Your panda will take it from here.")
                            .font(.subheadline)
                            .foregroundStyle(SipTheme.muted)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 145 : 92), spacing: 12)], spacing: 12) {
                        ForEach(DrinkKind.allCases) { kind in
                            drinkButton(kind)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("How much?")
                            .font(.title3.bold())
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) { amountOptions }
                            VStack(spacing: 10) { amountOptions }
                        }
                        if usesCustom {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom amount (mL)").font(.subheadline.weight(.semibold))
                                TextField("e.g. 350", text: $custom)
                                    .keyboardType(.numberPad)
                                    .focused($customFocused)
                                    .font(.title2.bold())
                                    .padding(16)
                                    .background(SipTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                                    .accessibilityLabel("Custom amount in milliliters")
                                Text("Enter a whole amount from 1 to 5,000 mL.")
                                    .font(.caption)
                                    .foregroundStyle(SipTheme.muted)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Goal credit").font(.headline)
                            Spacer()
                            Text("+\(SipTheme.volume(validAmount ? credit : 0)) mL")
                                .font(.title3.bold())
                                .foregroundStyle(SipTheme.green)
                        }
                        Text(drink == .alcohol
                             ? "Alcohol is saved in your log, with no credit toward your daily hydration goal."
                             : "\(drink.factorPercent)% water-content estimate. Actual drinks and individual hydration needs vary.")
                            .font(.caption)
                            .foregroundStyle(SipTheme.muted)
                    }
                    .padding(18)
                    .background(SipTheme.mint.opacity(0.7), in: RoundedRectangle(cornerRadius: 22))

                    if let error = store.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(SipTheme.ink)
                    }
                }
                .frame(maxWidth: 520)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(SipTheme.background)
            .foregroundStyle(SipTheme.ink)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    guard let volumeML, validAmount else { return }
                    if store.log(drink, volumeML: volumeML), let entry = store.data.entries.last {
                        onLog(entry)
                        dismiss()
                    }
                } label: {
                    Label(validAmount ? "Add \((volumeML ?? 0).formatted()) mL" : "Enter an amount", systemImage: "plus")
                }
                .buttonStyle(SipPrimaryButton())
                .disabled(!validAmount || !store.canWrite)
                .accessibilityLabel(validAmount ? "Add \(volumeML ?? 0) milliliters of \(drink.name.lowercased())" : "Enter an amount")
                .opacity(validAmount && store.canWrite ? 1 : 0.45)
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(SipTheme.background)
            }
            .navigationTitle("Log a drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Close drink log")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { customFocused = false }
                }
            }
        }
        .tint(SipTheme.green)
        .fontDesign(.rounded)
    }

    private func drinkButton(_ kind: DrinkKind) -> some View {
        Button {
            drink = kind
        } label: {
            VStack(spacing: 9) {
                Image(systemName: kind.symbol)
                    .font(.title2)
                    .foregroundStyle(kind.color)
                    .accessibilityHidden(true)
                Text(kind.name)
                    .font(.subheadline.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("\(kind.factorPercent)%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(SipTheme.muted)
            }
            .foregroundStyle(SipTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 98)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(drink == kind ? SipTheme.mint : SipTheme.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(drink == kind ? SipTheme.green : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(SipChoiceButton())
        .accessibilityLabel("\(kind.name), \(kind.factorPercent) percent goal credit")
        .accessibilityAddTraits(drink == kind ? .isSelected : [])
    }

    @ViewBuilder private var amountOptions: some View {
        ForEach([250, 500], id: \.self) { preset in
            amountButton("\(preset) mL", selected: !usesCustom && amount == preset) {
                usesCustom = false
                customFocused = false
                amount = preset
            }
        }
        amountButton("Custom", selected: usesCustom) {
            usesCustom = true
            customFocused = true
        }
    }

    private func amountButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fixedSize()
                .frame(maxWidth: .infinity, minHeight: 54)
                .padding(.horizontal, 10)
                .foregroundStyle(selected ? SipTheme.green : SipTheme.ink)
                .background(selected ? SipTheme.mint : SipTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(selected ? SipTheme.green : .clear, lineWidth: 2)
                }
        }
        .buttonStyle(SipChoiceButton())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
