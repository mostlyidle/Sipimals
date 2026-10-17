import SwiftUI

@main
struct PandaSipApp: App {
    @State private var store = HydrationStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView(store: store)
                    .tabItem { Label("Today", systemImage: "drop.fill") }
                HistoryView(store: store)
                    .tabItem { Label("History", systemImage: "clock.fill") }
            }
                .tint(SipTheme.green)
                .fontDesign(.rounded)
        }
    }
}
