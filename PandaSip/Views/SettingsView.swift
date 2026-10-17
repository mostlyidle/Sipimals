import SwiftUI
import UIKit

struct SettingsView: View {
    let store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("selectedAnimal") private var selectedAnimalID = AnimalKind.panda.rawValue
    @State private var goal = ""
    @State private var draftAnimal = AnimalKind.panda
    @State private var validationError: String?
    @FocusState private var goalFocused: Bool

    private var parsedGoal: Int? { Int(goal.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var animalColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 120), spacing: 12)]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Daily goal") {
                        HStack {
                            TextField("2,000", text: $goal)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .focused($goalFocused)
                                .accessibilityLabel("Daily goal in milliliters")
                            Text("mL").foregroundStyle(SipTheme.muted)
                        }
                    }
                    if let validationError {
                        Label(validationError, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(SipTheme.ink)
                    }
                } header: {
                    Text("Make it your own")
                } footer: {
                    Text("2,000 mL is a starting setting, not a personalized recommendation. Choose a goal that fits your needs.")
                }

                Section {
                    LazyVGrid(columns: animalColumns, spacing: 12) {
                        ForEach(AnimalKind.allCases) { animal in
                            animalCard(animal)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Animal companion")
                } footer: {
                    Text("Your companion shares your cup progress and drink history. Earn new friends with a daily streak of drinks that count toward your goal; alcohol-only days don’t count. Current streak: \(store.qualifyingStreak) days. Earned companions stay unlocked.")
                }

                Section {
                    ForEach(DrinkKind.allCases) { drink in
                        LabeledContent {
                            Text("\(drink.factorPercent)%").monospacedDigit()
                        } label: {
                            Label(drink.name, systemImage: drink.symbol)
                        }
                    }
                } header: {
                    Text("How your drinks count")
                } footer: {
                    Text("Goal credit = drink volume × factor. Factors approximate water content, not absorption or your body's hydration level. Juice uses orange juice, soft drinks use regular cola, and milk uses whole milk as references. Alcohol is logged at 0% by app policy.")
                }

                Section("Behind the numbers") {
                    Link(destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/26702122/")!) {
                        Label("Beverage study · Maughan et al.", systemImage: "arrow.up.right.square")
                    }
                    Link(destination: URL(string: "https://citrusbr.com/wp-content/uploads/2021/03/2016-Maughan-OJ-vs-other-beverages-hydration-potential.pdf")!) {
                        Label("Water-content table · page 3", systemImage: "doc.text")
                    }
                    Text("Water-content estimates do not use the study’s beverage hydration index as a multiplier.")
                        .font(.caption)
                        .foregroundStyle(SipTheme.muted)
                }

                Section("Privacy") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                Section {
                    Label("Your sips are saved locally", systemImage: "iphone")
                    Text("Panda Sip saves locally. Today starts fresh at midnight; the History tab keeps your previous days available.")
                        .font(.subheadline)
                        .foregroundStyle(SipTheme.muted)
                }
                if let error = store.errorMessage {
                    Section {
                        Text(error)
                        if !store.canWrite {
                            Button("Try loading again") { store.reload() }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SipTheme.background)
            .foregroundStyle(SipTheme.ink)
            .navigationTitle("Your daily rhythm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { saveAndDismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Hide keyboard") { goalFocused = false }
                }
            }
        }
        .onAppear {
            goal = String(store.data.goalML)
            let selected = AnimalKind(rawValue: selectedAnimalID) ?? .panda
            draftAnimal = selected.unlockDays == nil || store.unlockedAnimals.contains(selected) ? selected : .panda
        }
        .onChange(of: goal) { _, _ in validationError = nil }
        .onChange(of: validationError) { _, message in
            if let message { UIAccessibility.post(notification: .announcement, argument: message) }
        }
        .tint(SipTheme.green)
        .fontDesign(.rounded)
    }

    private func saveAndDismiss() {
        goalFocused = false
        guard let parsedGoal, (100...10_000).contains(parsedGoal) else {
            validationError = "Enter a whole amount from 100 to 10,000 mL."
            goalFocused = true
            return
        }
        guard parsedGoal == store.data.goalML || store.setGoal(parsedGoal) else {
            validationError = store.errorMessage ?? "Your daily goal couldn’t be saved. Please try again."
            return
        }
        selectedAnimalID = draftAnimal.rawValue
        dismiss()
    }

    private func animalCard(_ animal: AnimalKind) -> some View {
        let isUnlocked = animal.unlockDays == nil || store.unlockedAnimals.contains(animal)
        let subtitle = animal.unlockDays.map { isUnlocked ? "Unlocked" : "\(min(store.qualifyingStreak, $0)) / \($0) day streak" }
        return Button {
            draftAnimal = animal
        } label: {
            VStack(spacing: 8) {
                Image(animal.artworkName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 76)
                    .opacity(isUnlocked ? 1 : 0.56)
                    .overlay(alignment: .topTrailing) {
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(SipTheme.ink)
                                .padding(7)
                                .background(SipTheme.surface, in: Circle())
                        }
                    }
                    .accessibilityHidden(true)
                VStack(spacing: 3) {
                    HStack(spacing: 6) {
                        Text(animal.displayName)
                            .font(.subheadline.weight(.semibold))
                        if draftAnimal == animal {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(SipTheme.green)
                                .accessibilityHidden(true)
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(SipTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 136)
            .padding(10)
            .background(draftAnimal == animal ? SipTheme.mint : SipTheme.surface,
                        in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(draftAnimal == animal ? SipTheme.green : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .accessibilityLabel(accessibilityLabel(for: animal, unlocked: isUnlocked))
        .accessibilityAddTraits(draftAnimal == animal ? .isSelected : [])
    }

    private func accessibilityLabel(for animal: AnimalKind, unlocked: Bool) -> String {
        guard let days = animal.unlockDays else { return animal.displayName }
        return unlocked ? "\(animal.displayName), unlocked" : "\(animal.displayName), locked, \(store.qualifyingStreak) of \(days) consecutive logging days"
    }
}
