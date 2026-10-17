import Foundation

@main
struct CoreChecks {
    @MainActor
    static func main() throws {
        precondition(AnimalKind.allCases.map(\.rawValue) == ["panda", "fox", "rabbit", "capybara", "giraffe", "monkey", "pig"])
        precondition(AnimalKind(rawValue: "unknown") ?? .panda == .panda)
        precondition(AnimalKind.allCases.allSatisfy { !$0.artworkName.isEmpty })

        let folder = FileManager.default.temporaryDirectory.appending(path: "panda-sip-checks-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let preferencesName = "panda-sip-checks-\(UUID())"
        let preferences = UserDefaults(suiteName: preferencesName)!
        defer { preferences.removePersistentDomain(forName: preferencesName) }
        let file = folder.appending(path: "hydration.json")
        let store = HydrationStore(fileURL: file, preferences: preferences)
        precondition(store.canWrite && store.data.goalML == 2_000)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let beforeMidnight = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 23, minute: 59))!
        let afterMidnight = calendar.date(byAdding: .minute, value: 2, to: beforeMidnight)!
        precondition(store.log(.water, volumeML: 500, at: beforeMidnight))
        precondition(store.log(.coffee, volumeML: 250, at: beforeMidnight))
        precondition(store.log(.juice, volumeML: 500, at: afterMidnight))
        precondition(store.log(.alcohol, volumeML: 250, at: afterMidnight))
        let firstDay = store.data.entries(on: beforeMidnight, calendar: calendar)
        let nextDay = store.data.entries(on: afterMidnight, calendar: calendar)
        precondition(firstDay.count == 2 && nextDay.count == 2)
        precondition(abs(firstDay.reduce(0) { $0 + $1.creditedML } - 747.5) < 0.001)
        precondition(abs(nextDay.reduce(0) { $0 + $1.creditedML } - 445) < 0.001)
        precondition(nextDay.reduce(0) { $0 + $1.volumeML } == 750)
        precondition(nextDay.contains { $0.drink == .alcohol && $0.volumeML == 250 && $0.creditedML == 0 })
        precondition(store.data.entries(on: calendar.date(byAdding: .day, value: -1, to: beforeMidnight)!, calendar: calendar).isEmpty)

        let unsorted = HydrationData(entries: [
            DrinkEntry(date: beforeMidnight.addingTimeInterval(-60), drink: .tea, volumeML: 250),
            DrinkEntry(date: beforeMidnight, drink: .alcohol, volumeML: 150)
        ])
        precondition(unsorted.entries(on: beforeMidnight, calendar: calendar).map(\.drink) == [.alcohol, .tea])

        let nearGoal = HydrationData(entries: [
            DrinkEntry(date: beforeMidnight, drink: .water, volumeML: 1_969),
            DrinkEntry(date: beforeMidnight, drink: .coffee, volumeML: 31)
        ])
        precondition(nearGoal.goalCreditML(on: beforeMidnight, calendar: calendar) == 2_000)

        let beforeInvalid = store.data
        precondition(!store.log(.water, volumeML: 0))
        precondition(!store.log(.water, volumeML: 5_001))
        precondition(!store.setGoal(0))
        precondition(store.data == beforeInvalid)
        precondition(store.setGoal(2_500))
        precondition(store.data.entries == beforeInvalid.entries)
        let restored = HydrationStore(fileURL: file, preferences: preferences)
        precondition(restored.data == store.data)
        precondition(restored.remove(restored.data.entries[0]))
        precondition(HydrationStore(fileURL: file, preferences: preferences).data.entries.count == 3)

        // A DST day still includes both occurrences of the repeated hour.
        let dstStart = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let dstDay = calendar.dateInterval(of: .day, for: dstStart)!
        precondition(dstDay.duration == 25 * 60 * 60)
        let dstData = HydrationData(entries: [
            DrinkEntry(date: dstStart.addingTimeInterval(90 * 60), drink: .water, volumeML: 250),
            DrinkEntry(date: dstStart.addingTimeInterval(150 * 60), drink: .water, volumeML: 250),
            DrinkEntry(date: dstDay.end, drink: .water, volumeML: 250)
        ])
        precondition(dstData.entries(on: dstStart, calendar: calendar).count == 2)
        let dstStreak = HydrationData(entries: [
            DrinkEntry(date: calendar.date(byAdding: .day, value: -1, to: dstStart)!, drink: .water, volumeML: 1),
            DrinkEntry(date: dstStart, drink: .water, volumeML: 1),
            DrinkEntry(date: dstDay.end, drink: .water, volumeML: 1)
        ])
        precondition(dstStreak.qualifyingDayStreak(calendar: calendar, through: dstDay.end).best == 3)

        let streakStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let twentyNineDays = HydrationData(entries: (0..<29).map {
            DrinkEntry(date: calendar.date(byAdding: .day, value: $0, to: streakStart)!, drink: .water, volumeML: 1)
        })
        let day29 = calendar.date(byAdding: .day, value: 28, to: streakStart)!
        precondition(twentyNineDays.qualifyingDayStreak(calendar: calendar, through: day29).best == 29)

        let resetStreak = HydrationData(entries: [
            DrinkEntry(date: streakStart, drink: .water, volumeML: 1),
            DrinkEntry(date: calendar.date(byAdding: .day, value: 1, to: streakStart)!, drink: .alcohol, volumeML: 250),
            DrinkEntry(date: calendar.date(byAdding: .day, value: 2, to: streakStart)!, drink: .water, volumeML: 1)
        ])
        let resetProgress = resetStreak.qualifyingDayStreak(calendar: calendar, through: calendar.date(byAdding: .day, value: 2, to: streakStart)!)
        precondition(resetProgress.current == 1 && resetProgress.best == 1)

        let gapStreak = HydrationData(entries: [
            DrinkEntry(date: streakStart, drink: .water, volumeML: 1),
            DrinkEntry(date: calendar.date(byAdding: .day, value: 1, to: streakStart)!, drink: .tea, volumeML: 1),
            DrinkEntry(date: calendar.date(byAdding: .day, value: 3, to: streakStart)!, drink: .water, volumeML: 1)
        ])
        let gapProgress = gapStreak.qualifyingDayStreak(calendar: calendar, through: calendar.date(byAdding: .day, value: 3, to: streakStart)!)
        precondition(gapProgress.current == 1 && gapProgress.best == 2)

        let graceDay = calendar.date(byAdding: .day, value: 29, to: streakStart)!
        let thirtyDays = HydrationData(entries: (0..<30).map {
            DrinkEntry(date: calendar.date(byAdding: .day, value: $0, to: streakStart)!, drink: .water, volumeML: 1)
        })
        precondition(thirtyDays.qualifyingDayStreak(calendar: calendar, through: graceDay).current == 30)
        precondition(thirtyDays.qualifyingDayStreak(calendar: calendar, through: calendar.date(byAdding: .day, value: 2, to: graceDay)!).current == 0)

        let unlockFile = folder.appending(path: "unlock-hydration.json")
        try JSONEncoder().encode(twentyNineDays).write(to: unlockFile)
        let unlockStore = HydrationStore(fileURL: unlockFile, preferences: preferences)
        precondition(!unlockStore.unlockedAnimals.contains(.giraffe))
        let day30 = calendar.date(byAdding: .day, value: 29, to: streakStart)!
        precondition(unlockStore.log(.water, volumeML: 1, at: day30))
        precondition(unlockStore.unlockedAnimals.contains(.giraffe))
        precondition(unlockStore.remove(unlockStore.data.entries.last!))
        precondition(HydrationStore(fileURL: unlockFile, preferences: preferences).unlockedAnimals.contains(.giraffe))

        let ninetyDays = HydrationData(entries: (0..<90).map {
            DrinkEntry(date: calendar.date(byAdding: .day, value: $0, to: streakStart)!, drink: .water, volumeML: 1)
        })
        let sixtyDays = HydrationData(entries: (0..<60).map {
            DrinkEntry(date: calendar.date(byAdding: .day, value: $0, to: streakStart)!, drink: .water, volumeML: 1)
        })
        let sixtyFile = folder.appending(path: "sixty-days.json")
        try JSONEncoder().encode(sixtyDays).write(to: sixtyFile)
        let sixtyPreferencesName = "panda-sip-sixty-\(UUID())"
        let sixtyPreferences = UserDefaults(suiteName: sixtyPreferencesName)!
        defer { sixtyPreferences.removePersistentDomain(forName: sixtyPreferencesName) }
        let sixtyRewards = HydrationStore(fileURL: sixtyFile, preferences: sixtyPreferences)
        precondition(sixtyRewards.unlockedAnimals.isSuperset(of: [.giraffe, .monkey]))
        precondition(!sixtyRewards.unlockedAnimals.contains(.pig))

        let allRewardsFile = folder.appending(path: "all-rewards.json")
        try JSONEncoder().encode(ninetyDays).write(to: allRewardsFile)
        let rewardsPreferencesName = "panda-sip-rewards-\(UUID())"
        let rewardsPreferences = UserDefaults(suiteName: rewardsPreferencesName)!
        defer { rewardsPreferences.removePersistentDomain(forName: rewardsPreferencesName) }
        let allRewards = HydrationStore(fileURL: allRewardsFile, preferences: rewardsPreferences)
        precondition(allRewards.unlockedAnimals.isSuperset(of: [.giraffe, .monkey, .pig]))

        let corrupt = folder.appending(path: "corrupt.json")
        let original = Data("not-json".utf8)
        try original.write(to: corrupt)
        let blocked = HydrationStore(fileURL: corrupt, preferences: preferences)
        precondition(blocked.unlockedAnimals.contains(.giraffe))
        precondition(!blocked.canWrite && blocked.errorMessage != nil)
        precondition(!blocked.log(.water, volumeML: 250))
        let preserved = try Data(contentsOf: corrupt)
        precondition(preserved == original)

        // Force a write failure without relying on filesystem permission behavior.
        let unwritable = folder.appending(path: "occupied")
        let failed = HydrationStore(fileURL: unwritable, preferences: preferences)
        try FileManager.default.createDirectory(at: unwritable, withIntermediateDirectories: true)
        precondition(!failed.log(.water, volumeML: 250))
        precondition(failed.data.entries.isEmpty && failed.errorMessage != nil)
        precondition(!failed.setGoal(2_500) && failed.data.goalML == 2_000)
        print("PASS: animal catalog/fallback, streak reset/grace and 30/60/90-day unlocks, permanent rewards, history dates/order/alcohol, persistence, goal validation, DST, corrupt-file preservation, failed-save rollback")
    }
}
