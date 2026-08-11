import SwiftUI

struct ConversionQueueView: View {
    @EnvironmentObject private var conversionViewModel: ConversionQueueViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversion Queue")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Lossless-to-MP3 and other conversion jobs.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                
                if !conversionViewModel.jobs.isEmpty {
                    Button(action: {
                        conversionViewModel.clearCompleted()
                    }) {
                        Text("Clear Completed")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.bgHover)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(!conversionViewModel.jobs.contains { $0.status == .completed })
                    .opacity(conversionViewModel.jobs.contains { $0.status == .completed } ? 1.0 : 0.5)
                }
            }
            .padding(20)
            .background(Theme.Colors.bgPrimary)
            
            Divider()
                .background(Theme.Colors.border)
            
            if conversionViewModel.jobs.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("Queue is Empty")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Select tracks in the library and use the Convert button.")
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.bgBase)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(conversionViewModel.jobs) { job in
                            ConversionJobRow(job: job)
                            Divider()
                                .background(Theme.Colors.border)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Theme.Colors.bgBase)
            }
        }
    }
}

struct ConversionJobRow: View {
    let job: ConversionJob
    @EnvironmentObject private var conversionViewModel: ConversionQueueViewModel
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.sourceURL.lastPathComponent)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                HStack(spacing: 8) {
                    Label("To: \(job.settings.outputFormat.rawValue.uppercased())", systemImage: "music.note")
                    if let error = job.errorDescription {
                        Text("• \(error)")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            }
            
            Spacer()
            
            if job.status == .converting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(job.status.rawValue.capitalized)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(color(for: job.status))
            }
            
            if job.status == .failed {
                Button(action: { conversionViewModel.remove(job: job) }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(8)
                        .background(isHovered ? Theme.Colors.bgHover : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Remove Failed Job")
            } else if job.status == .completed {
                Button(action: { NSWorkspace.shared.activateFileViewerSelecting([job.destinationURL]) }) {
                    Image(systemName: "folder")
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(8)
                        .background(isHovered ? Theme.Colors.bgHover : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
            } else {
                Color.clear.frame(width: 28, height: 28)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(isHovered ? Theme.Colors.bgHover.opacity(0.5) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func color(for status: ConversionJob.Status) -> Color {
        switch status {
        case .completed: return Theme.Colors.accentPrimary
        case .failed: return .red
        case .queued, .preparing: return Theme.Colors.textSecondary
        default: return Theme.Colors.textPrimary
        }
    }
}
