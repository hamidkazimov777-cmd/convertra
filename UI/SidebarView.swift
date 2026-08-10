import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            HStack {
                if let logo = NSImage(named: "Logo") {
                    Image(nsImage: logo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 170, height: 32)
                        .clipped()
                } else {
                    Text("CONVERTRA")
                        .font(.inter(size: 20, weight: .bold))
                        .foregroundStyle(Theme.Colors.accentPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
            
            // Navigation
            VStack(alignment: .leading, spacing: 4) {
                SidebarItem(title: "Library", icon: "music.note.list", isSelected: appState.selectedSection == .library) {
                    appState.selectedSection = .library
                }
                SidebarItem(title: "Conversion", icon: "arrow.triangle.2.circlepath", isSelected: appState.selectedSection == .conversion) {
                    appState.selectedSection = .conversion
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .frame(width: Theme.Layout.sidebarWidth)
        .background(Theme.Colors.bgBase)
    }
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .font(.inter(size: 14, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? Theme.Colors.accentPrimary : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.Colors.bgSelected : (isHovered ? Theme.Colors.bgHover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct SidebarCollectionItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.inter(size: 12))
                }
            }
            .font(.inter(size: 13, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? Theme.Colors.accentPrimary : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.Colors.bgSelected : (isHovered ? Theme.Colors.bgHover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
