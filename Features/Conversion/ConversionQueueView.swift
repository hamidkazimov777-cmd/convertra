import SwiftUI

struct ConversionQueueView: View {
    @EnvironmentObject private var conversionViewModel: ConversionQueueViewModel
    
    var body: some View {
        VStack {
            if conversionViewModel.jobs.isEmpty {
                FeaturePlaceholderView(
                    title: "Conversion Queue",
                    message: "Lossless-to-MP3 conversion jobs will appear here. Select tracks in the library and use the Convert button.",
                    image: "arrow.triangle.2.circlepath"
                )
            } else {
                List(conversionViewModel.jobs) { job in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(job.sourceURL.lastPathComponent)
                                .font(.headline)
                            Text("To: \(job.settings.outputFormat.rawValue.uppercased())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if job.status == .converting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(job.status.rawValue.capitalized)
                                .foregroundStyle(color(for: job.status))
                                .font(.subheadline)
                        }
                        
                        if job.status == .failed {
                            Button(action: { conversionViewModel.remove(job: job) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(job.errorDescription ?? "Unknown error")
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                HStack {
                    Button("Clear Completed") {
                        conversionViewModel.clearCompleted()
                    }
                    .disabled(!conversionViewModel.jobs.contains { $0.status == .completed })
                    .accessibilityLabel("Clear Completed Jobs")
                    
                    Spacer()
                    
                    Button("Start All") {
                        conversionViewModel.startAll()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!conversionViewModel.jobs.contains { $0.status == .queued || $0.status == .failed })
                    .accessibilityLabel("Start All Jobs")
                }
                .padding()
            }
        }
        .navigationTitle("Conversion Queue")
    }
    
    private func color(for status: ConversionJob.Status) -> Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        case .queued, .preparing: return .secondary
        default: return .primary
        }
    }
}
