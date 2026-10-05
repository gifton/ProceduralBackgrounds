import SwiftUI

@main
struct BackgroundHarnessApp: App {
    var body: some Scene {
        WindowGroup("Background Harness") {
            HarnessView()
                #if os(macOS)
                .frame(minWidth: 360, minHeight: 400)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 960, height: 640)
        #endif
    }
}
