enum AnimalKind: String, CaseIterable, Codable, Identifiable {
    case panda
    case fox
    case rabbit
    case capybara
    case giraffe
    case monkey
    case pig

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .panda: "Panda"
        case .fox: "Fox"
        case .rabbit: "Rabbit"
        case .capybara: "Capybara"
        case .giraffe: "Giraffe"
        case .monkey: "Monkey"
        case .pig: "Pig"
        }
    }

    var artworkName: String {
        switch self {
        case .panda: "PandaCup"
        case .fox: "FoxCup"
        case .rabbit: "RabbitCup"
        case .capybara: "CapybaraCup"
        case .giraffe: "GiraffeCup"
        case .monkey: "MonkeyCup"
        case .pig: "PigCup"
        }
    }

    var unlockDays: Int? {
        switch self {
        case .panda, .fox, .rabbit, .capybara: nil
        case .giraffe: 30
        case .monkey: 60
        case .pig: 90
        }
    }

    var accessibilityName: String {
        "Hydration \(displayName.lowercased())"
    }
}
