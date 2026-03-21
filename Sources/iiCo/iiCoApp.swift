import SwiftUI

@main
struct iiCoApp: App {
    init() {
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
