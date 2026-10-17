import SwiftUI

struct DrinkEntryRow: View {
    let entry: DrinkEntry
    let store: HydrationStore

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: entry.drink.symbol)
                .font(.title3)
                .foregroundStyle(entry.drink.color)
                .frame(width: 42, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.drink.name)
                    .font(.headline)
                Text("\(entry.date.formatted(date: .omitted, time: .shortened)) · \(entry.volumeML.formatted()) mL")
                    .font(.caption)
                    .foregroundStyle(SipTheme.muted)
                Text("+\(SipTheme.volume(entry.creditedML)) mL goal credit")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(SipTheme.green)
            }

            Spacer(minLength: 0)

            Menu {
                Button("Delete sip", systemImage: "trash", role: .destructive) {
                    store.remove(entry)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(SipTheme.muted)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Options for \(entry.drink.name), \(entry.volumeML) milliliters")
        }
    }
}
