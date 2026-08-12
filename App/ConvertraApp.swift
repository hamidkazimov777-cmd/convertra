import SwiftUI

@main
struct ConvertraApp: App {
    @StateObject private var appState = AppViewModel()
    @StateObject private var conversionQueue = ConversionQueueViewModel()
    @StateObject private var loc = Localization.shared
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(conversionQueue)
                .environmentObject(loc)
                .environmentObject(settings)
                .frame(minWidth: 980, minHeight: 620)
                .preferredColorScheme(.dark)
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
