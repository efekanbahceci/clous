import SwiftUI
import AppKit

@main
struct SierraPortDesktopApp: App {
    @StateObject private var vm = SierraPortViewModel()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("SierraPort") {
            ContentView(vm: vm)
                .frame(minWidth: 960, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1180, height: 760)

        MenuBarExtra("SierraPort", systemImage: "network") {
            MenuBarView(vm: vm)
        }
        .menuBarExtraStyle(.window)
    }
}
