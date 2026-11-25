import SwiftData
import SwiftUI

@main
struct RemindCallApp: App {
    private let container = Store.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
