import SwiftUI

struct MainLayoutView: View {
    @EnvironmentObject private var appState: AppViewModel
    
    var body: some View {
        ZStack {
            Theme.Colors.bgBase.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top area: Sidebar + Content + Inspector
                HStack(spacing: 0) {
                    SidebarView()
                    
                    // Divider
                    Rectangle()
                        .fill(Theme.Colors.border)
                        .frame(width: 1)
                    
                    // Center Content
                    VStack(spacing: 0) {
                        Group {
                            switch appState.selectedSection ?? .library {
                            case .library:
                                LibraryView()
                            case .metadata:
                                MetadataEditorView()
                            case .conversion:
                                ConversionQueueView()
                            default:
                                VStack {
                                    Text("Coming Soon")
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(Theme.Colors.bgPrimary)
                    
                    // Divider
                    Rectangle()
                        .fill(Theme.Colors.border)
                        .frame(width: 1)
                    
                    // Right Inspector
                    VStack {
                        Text("Inspector Placeholder")
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .frame(width: Theme.Layout.inspectorWidth)
                    .background(Theme.Colors.bgBase)
                }
                
                // Divider
                Rectangle()
                    .fill(Theme.Colors.border)
                    .frame(height: 1)
                
                // Bottom Player
                VStack {
                    Text("Bottom Player Placeholder")
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .frame(height: Theme.Layout.playerHeight)
                .frame(maxWidth: .infinity)
                .background(Theme.Colors.bgBase)
            }
        }
    }
}
