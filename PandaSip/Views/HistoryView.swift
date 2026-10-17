import SwiftUI
import UIKit

struct HistoryView: View {
    let store: HydrationStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Date.now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var followingToday = true

    private var calendar: Calendar { .autoupdatingCurrent }
    private var entries: [DrinkEntry] { store.data.entries(on: selectedDay, calendar: calendar) }
    private var consumedML: Int { entries.reduce(0) { $0 + $1.volumeML } }
    private var creditedML: Double { entries.reduce(0) { $0 + $1.creditedML }.rounded() }
    private var isToday: Bool { calendar.isDate(selectedDay, inSameDayAs: today) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dayPicker
                    if let error = store.errorMessage { storageMessage(error) }
                    daySummary
                    entriesCard
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            .background(SipTheme.background)
            .foregroundStyle(SipTheme.ink)
            .navigationTitle("Drink history")
            .navigationBarTitleDisplayMode(.large)
        }
        .fontDesign(.rounded)
        .tint(SipTheme.green)
        .onAppear { refreshCurrentDay() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshCurrentDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshCurrentDay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            refreshCurrentDay()
        }
    }

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a day")
                .font(.headline)
                .accessibilityHidden(true)
            DatePicker(
                "Choose a day",
                selection: Binding(
                    get: { selectedDay },
                    set: { newValue in
                        selectedDay = newValue
                        followingToday = calendar.isDate(newValue, inSameDayAs: today)
                    }
                ),
                in: ...today,
                displayedComponents: .date
            )
            .labelsHidden()

            HStack(spacing: 12) {
                Button { moveDay(by: -1) } label: {
                    Label("Previous day", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .background(SipTheme.surface, in: Circle())
                }
                .accessibilityLabel("Previous day")

                Text(selectedDay.formatted(date: .complete, time: .omitted))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                Button { moveDay(by: 1) } label: {
                    Label("Next day", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .background(SipTheme.surface, in: Circle())
                }
                .disabled(isToday)
                .accessibilityLabel("Next day")
            }

            if !isToday {
                Button("Jump to today") {
                    selectedDay = today
                    followingToday = true
                }
                .font(.subheadline.weight(.bold))
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var daySummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                summaryValue("\(entries.count)", label: entries.count == 1 ? "drink" : "drinks")
                Divider()
                summaryValue("\(consumedML.formatted()) mL", label: "consumed")
                Divider()
                summaryValue("\(SipTheme.volume(creditedML)) mL", label: "goal credit")
            }
            VStack(alignment: .leading, spacing: 12) {
                summaryValue("\(entries.count)", label: entries.count == 1 ? "drink" : "drinks")
                summaryValue("\(consumedML.formatted()) mL", label: "consumed")
                summaryValue("\(SipTheme.volume(creditedML)) mL", label: "goal credit")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SipTheme.mint, in: RoundedRectangle(cornerRadius: 24))
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SIPS")
                .font(.caption.weight(.bold))
                .tracking(1.3)

            if entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer")
                        .font(.largeTitle)
                        .foregroundStyle(SipTheme.green)
                        .accessibilityHidden(true)
                    Text("No drinks logged")
                        .font(.headline)
                    Text(isToday ? "Your first sip starts here." : "There are no saved sips for this day.")
                        .font(.subheadline)
                        .foregroundStyle(SipTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(entries) { entry in
                    DrinkEntryRow(entry: entry, store: store)
                    if entry.id != entries.last?.id { Divider().overlay(SipTheme.mint) }
                }
            }
        }
        .padding(20)
        .background(SipTheme.surface, in: RoundedRectangle(cornerRadius: 28))
    }

    private func summaryValue(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(SipTheme.muted)
        }
    }

    private func moveDay(by value: Int) {
        guard let moved = calendar.date(byAdding: .day, value: value, to: selectedDay) else { return }
        if calendar.compare(moved, to: today, toGranularity: .day) == .orderedDescending {
            selectedDay = today
            followingToday = true
        } else {
            selectedDay = moved
            followingToday = calendar.isDate(moved, inSameDayAs: today)
        }
    }

    private func refreshCurrentDay() {
        today = .now
        if followingToday || calendar.compare(selectedDay, to: today, toGranularity: .day) == .orderedDescending {
            selectedDay = today
            followingToday = true
        }
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
