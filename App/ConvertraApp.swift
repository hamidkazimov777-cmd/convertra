import SwiftUI

@main
struct ConvertraApp: App {
    @StateObject private var appState = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Audio Files…") {
                    appState.presentImporter()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
