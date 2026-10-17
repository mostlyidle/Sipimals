import SwiftUI
import UIKit

struct ContentView: View {
    let store: HydrationStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedAnimal") private var selectedAnimalID = AnimalKind.panda.rawValue
    @State private var today = Date.now
    @State private var activeSheet: Sheet?
    @State private var latestHydratingLog: DrinkEntry?
    @State private var latestLogOverflows = false

    private enum Sheet: String, Identifiable {
        case log, settings
        var id: String { rawValue }
    }

    private var entries: [DrinkEntry] { store.data.entries(on: today) }
    private var creditedML: Double { Double(store.data.goalCreditML(on: today)) }
    private var consumedML: Int { entries.reduce(0) { $0 + $1.volumeML } }
    private var progress: Double { creditedML / Double(store.data.goalML) }
    private var percentage: Int { Int(creditedML) * 100 / store.data.goalML }
    private var goalReached: Bool { progress >= 1 }
    private var selectedAnimal: AnimalKind {
        guard let animal = AnimalKind(rawValue: selectedAnimalID), animal.unlockDays == nil || store.unlockedAnimals.contains(animal) else { return .panda }
        return animal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                intro
                progressSection
                companionSection
                if let error = store.errorMessage { storageMessage(error) }
                todaysSips
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background(SipTheme.background)
        .foregroundStyle(SipTheme.ink)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { activeSheet = .log } label: {
                Label("Log a drink", systemImage: "plus")
            }
            .buttonStyle(SipPrimaryButton())
            .disabled(!store.canWrite)
            .opacity(store.canWrite ? 1 : 0.5)
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(SipTheme.background.opacity(0.97))
        }
        .sheet(item: $activeSheet) { sheet in
            Group {
                switch sheet {
                case .log:
                    DrinkLogSheet(store: store) { entry in
                        guard entry.creditedML > 0 else { return }
                        latestHydratingLog = entry
                        latestLogOverflows = store.data.goalCreditML(on: today) > store.data.goalML
                    }
                case .settings: SettingsView(store: store)
                }
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                today = .now
                store.refreshCalendarProgress()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            today = .now
            store.refreshCalendarProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            today = .now
            store.refreshCalendarProgress()
        }
        .sensoryFeedback(.success, trigger: goalReached) { old, new in new && !old }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .font(.title3)
                .foregroundStyle(SipTheme.green)
                .frame(width: 42, height: 42)
                .background(SipTheme.mint, in: RoundedRectangle(cornerRadius: 15))
                .accessibilityHidden(true)
            Text("panda sip")
                .font(.system(.title3, design: .rounded, weight: .heavy))
            Spacer(minLength: 8)
            Button { activeSheet = .settings } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.weight(.medium))
                    .frame(width: 48, height: 48)
                    .background(SipTheme.surface, in: Circle())
            }
            .foregroundStyle(SipTheme.ink)
            .accessibilityLabel("Settings, daily goal, and animal companion")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(today.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(SipTheme.muted)
            Text(goalReached
                 ? "Happy \(selectedAnimal.displayName.lowercased()).\nHappy you."
                 : "Small sips.\nHappy \(selectedAnimal.displayName.lowercased()).")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    amountText
                    goalText
                }
                VStack(alignment: .leading, spacing: 4) {
                    amountText
                    goalText
                }
            }
            HStack(alignment: .center) {
                Text("Estimated hydration")
                    .font(.subheadline)
                    .foregroundStyle(SipTheme.muted)
                Spacer(minLength: 4)
                Button { activeSheet = .settings } label: {
                    Label("Edit goal", systemImage: "pencil")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(SipTheme.mint, in: Capsule())
                }
                .foregroundStyle(SipTheme.green)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var amountText: some View {
        Text("\(SipTheme.volume(creditedML)) mL")
            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
            .contentTransition(.numericText())
            .accessibilityLabel("\(SipTheme.volume(creditedML)) milliliters of estimated hydration")
    }

    private var goalText: some View {
        Text("/ \(store.data.goalML.formatted()) mL")
            .font(.system(.title3, design: .rounded, weight: .medium))
            .foregroundStyle(SipTheme.muted)
            .accessibilityLabel("of your \(store.data.goalML) milliliter goal")
    }

    private var companionSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(SipTheme.mint.opacity(0.65))
                    .frame(width: 250, height: 250)
                    .blur(radius: 2)
                PandaView(
                    animal: selectedAnimal,
                    progress: min(progress, 1),
                    celebrating: goalReached,
                    loggedDrink: latestHydratingLog,
                    loggedDrinkOverflows: latestLogOverflows
                )
                    .frame(width: 270, height: 270)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(selectedAnimal.displayName)'s cup is \(min(percentage, 100)) percent full")

            VStack(spacing: 8) {
                Label(goalReached ? "Daily goal complete" : "\(percentage)% of your daily goal",
                      systemImage: goalReached ? "checkmark.seal.fill" : "drop.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(SipTheme.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(SipTheme.mint, in: Capsule())
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(SipTheme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: goalReached)
    }

    private var status: String {
        if goalReached { return "You made waves today. Enjoy your happy \(selectedAnimal.displayName.lowercased())." }
        if creditedML > 0 { return "\(SipTheme.volume(max(0, Double(store.data.goalML) - creditedML))) mL to go. One sip at a time." }
        return "Every little sip is a fresh start."
    }

    private var todaysSips: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TODAY’S SIPS")
                    .font(.caption.weight(.bold))
                    .tracking(1.3)
                Spacer()
                Text("\(entries.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SipTheme.mint, in: Capsule())
            }
            if entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer")
                        .font(.largeTitle)
                        .foregroundStyle(SipTheme.green)
                        .accessibilityHidden(true)
                    Text("Your first sip starts here")
                        .font(.headline)
                    Text("Water, coffee, juice — log what you love.")
                        .font(.subheadline)
                        .foregroundStyle(SipTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Text("\(consumedML.formatted()) mL consumed · \(SipTheme.volume(creditedML)) mL goal credit")
                    .font(.caption)
                    .foregroundStyle(SipTheme.muted)
                ForEach(entries) { entry in
                    DrinkEntryRow(entry: entry, store: store)
                    if entry.id != entries.last?.id { Divider().overlay(SipTheme.mint) }
                }
            }
        }
        .padding(20)
        .background(SipTheme.surface, in: RoundedRectangle(cornerRadius: 28))
    }

    private func storageMessage(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.subheadline)
            if !store.canWrite {
                Button("Try loading again") { store.reload() }
                    .font(.headline)
                    .frame(minHeight: 44)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SipTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}
