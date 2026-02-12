import SwiftUI

@main
struct ScalewayGUIApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
