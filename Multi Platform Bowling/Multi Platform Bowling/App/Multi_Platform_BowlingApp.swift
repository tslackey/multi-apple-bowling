import SwiftUI

@main
struct Multi_Platform_BowlingApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 720)
        #endif
    }
}
