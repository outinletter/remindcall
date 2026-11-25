import SwiftData
import SwiftUI

@main
struct RemindCallApp: App {
    private let container = Store.makeContainer()

    init() {
        NotificationManager.shared.setup(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
