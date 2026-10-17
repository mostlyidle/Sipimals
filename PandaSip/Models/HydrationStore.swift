import Foundation
import Observation

@MainActor @Observable
final class HydrationStore {
    private(set) var data = HydrationData()
    private(set) var canWrite = false
    private(set) var errorMessage: String?
    private(set) var qualifyingStreak = 0
    private(set) var unlockedAnimals: Set<AnimalKind> = []
    private let fileURL: URL
    private let preferences: UserDefaults

    init(fileURL: URL? = nil, preferences: UserDefaults = .standard) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory
            .appending(path: "PandaSip/hydration.json")
        self.preferences = preferences
        reload()
    }

    func reload() {
        restoreEarnedAnimals()
        do {
            let loaded: HydrationData
            if FileManager.default.fileExists(atPath: fileURL.path) {
                loaded = try JSONDecoder().decode(HydrationData.self, from: Data(contentsOf: fileURL))
                guard loaded.isValid else { throw CocoaError(.fileReadCorruptFile) }
            } else {
                loaded = HydrationData()
            }
            data = loaded
            refreshUnlocks()
            canWrite = true
            errorMessage = nil
        } catch {
            canWrite = false
            errorMessage = "Your saved sips couldn’t be opened. The original file has been kept. Try again to reload it."
        }
    }

    func refreshCalendarProgress() {
        refreshUnlocks()
    }

    @discardableResult
    func log(_ drink: DrinkKind, volumeML: Int, at date: Date = .now) -> Bool {
        guard (1...5_000).contains(volumeML), date.timeIntervalSinceReferenceDate.isFinite else {
            errorMessage = "Enter a whole amount from 1 to 5,000 mL."
            return false
        }
        var updated = data
        updated.entries.append(DrinkEntry(date: date, drink: drink, volumeML: volumeML))
        return save(updated)
    }

    @discardableResult
    func remove(_ entry: DrinkEntry) -> Bool {
        var updated = data
        updated.entries.removeAll { $0.id == entry.id }
        return save(updated)
    }

    @discardableResult
    func setGoal(_ goalML: Int) -> Bool {
        guard (100...10_000).contains(goalML) else {
            errorMessage = "Enter a daily goal from 100 to 10,000 mL."
            return false
        }
        var updated = data
        updated.goalML = goalML
        return save(updated)
    }

    private func save(_ updated: HydrationData) -> Bool {
        guard canWrite else { return false }
        do {
            let encoded = try JSONEncoder().encode(updated)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoded.write(to: fileURL, options: .atomic)
            data = updated
            refreshUnlocks()
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Your change couldn’t be saved. Your previous sips are safe. Please try again."
            return false
        }
    }

    private func refreshUnlocks() {
        let streak = data.qualifyingDayStreak()
        qualifyingStreak = streak.current
        var earnedIDs = Set(preferences.stringArray(forKey: "earnedAnimals") ?? [])
        for animal in AnimalKind.allCases where animal.unlockDays.map({ streak.best >= $0 }) == true {
            earnedIDs.insert(animal.rawValue)
        }
        preferences.set(earnedIDs.sorted(), forKey: "earnedAnimals")
        unlockedAnimals = Set(earnedIDs.compactMap(AnimalKind.init(rawValue:)))
    }

    private func restoreEarnedAnimals() {
        unlockedAnimals = Set((preferences.stringArray(forKey: "earnedAnimals") ?? [])
            .compactMap(AnimalKind.init(rawValue:)))
    }
}
