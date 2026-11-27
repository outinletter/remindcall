import SwiftData
import SwiftUI

@main
struct RemindCallApp: App {
    private let container = Store.makeContainer()
    @State private var language = LanguageManager.shared

    init() {
        NotificationManager.shared.setup(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, language.locale)
                .id(language.code)
                .onChange(of: language.code) {
                    if Demo.isOn { Demo.seed(container.mainContext) }
                }
        }
        .modelContainer(container)
    }
}
