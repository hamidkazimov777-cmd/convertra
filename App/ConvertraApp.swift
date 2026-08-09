import SwiftUI

@main
struct ConvertraApp: App {
    @StateObject private var appState = AppViewModel()
    @StateObject private var conversionQueue = ConversionQueueViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(conversionQueue)
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
