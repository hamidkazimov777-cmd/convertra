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
                            switch appState.selectedSection {
                            case .library:
                                LibraryView()
                            case .conversion:
                                ConversionQueueView()
                            case .duplicates:
                                DuplicatesView()
                            case .folder(let url):
                                LibraryView(filterFolder: url)
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
                    InspectorView()
                }
                
                // Divider
                Rectangle()
                    .fill(Theme.Colors.border)
                    .frame(height: 1)
                
                // Bottom Player
                BottomPlayerView()
            }
        }
    }
}
