import SwiftUI

struct ConversionQueueView: View {
    @EnvironmentObject private var conversionViewModel: ConversionQueueViewModel
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc["Очередь конвертации"])
                        .font(.inter(size: 20, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(loc["Задания конвертации lossless → MP3 и другие."])
                        .font(.inter(size: 13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()

                if conversionViewModel.hasActiveJobs {
                    Button {
                        conversionViewModel.cancelAll()
                    } label: { Label(loc["Отменить всё"], systemImage: "stop.circle") }
                    .buttonStyle(DestructiveGhostButtonStyle())
                }

                if !conversionViewModel.jobs.isEmpty {
                    Button {
                        conversionViewModel.clearCompleted()
                    } label: { Label(loc["Очистить завершённые"], systemImage: "checkmark.circle") }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(!conversionViewModel.jobs.contains { $0.status == .completed })
                    .opacity(conversionViewModel.jobs.contains { $0.status == .completed } ? 1.0 : 0.5)
                }
            }
            .padding(20)
            .background(Theme.Colors.bgPrimary)

            Divider()
                .background(Theme.Colors.border)

            if conversionViewModel.jobs.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    ZStack {
                        Circle().fill(Theme.Colors.accentPrimary.opacity(0.12)).frame(width: 76, height: 76)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(Theme.Colors.accentBright)
                    }
                    Text(loc["Очередь пуста"])
                        .font(.inter(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(loc["Выберите треки в библиотеке и нажмите «Конвертировать»."])
                        .font(.inter(size: 13))
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
    @EnvironmentObject private var loc: Localization
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.sourceURL.lastPathComponent)
                    .font(.inter(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label("\(loc["В формат:"]) \(job.settings.outputFormat.rawValue.uppercased())", systemImage: "music.note")
                    if let error = job.errorDescription {
                        Text("• \(error)")
                            .foregroundStyle(Theme.Colors.destructive)
                    }
                }
                .font(.inter(size: 11))
                .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            if job.status == .converting {
                ProgressView()
                    .controlSize(.small)
                    .tint(Theme.Colors.accentPrimary)
            } else {
                Text(statusText(job.status))
                    .font(.inter(size: 11, weight: .semibold))
                    .foregroundStyle(color(for: job.status))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(color(for: job.status).opacity(0.12)))
            }

            if job.status == .queued || job.status == .preparing || job.status == .converting {
                Button(action: { conversionViewModel.cancel(job: job) }) {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(8)
                        .background(isHovered ? Theme.Colors.bgHover : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(loc["Отменить задание"])
            } else if job.status == .failed || job.status == .cancelled {
                Button(action: { conversionViewModel.remove(job: job) }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(8)
                        .background(isHovered ? Theme.Colors.bgHover : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(loc["Удалить задание"])
            } else if job.status == .completed {
                Button(action: { NSWorkspace.shared.activateFileViewerSelecting([job.destinationURL]) }) {
                    Image(systemName: "folder")
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(8)
                        .background(isHovered ? Theme.Colors.bgHover : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(loc["Показать в Finder"])
            } else {
                Color.clear.frame(width: 28, height: 28)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(isHovered ? Theme.Colors.bgHover.opacity(0.5) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func statusText(_ status: ConversionJob.Status) -> String {
        switch status {
        case .completed: return loc["Готово"]
        case .failed: return loc["Ошибка"]
        case .queued: return loc["В очереди"]
        case .preparing: return loc["Подготовка"]
        case .converting: return loc["Конвертирование"]
        case .cancelled: return loc["Отменено"]
        }
    }

    private func color(for status: ConversionJob.Status) -> Color {
        switch status {
        case .completed: return Theme.Colors.accentBright
        case .failed: return Theme.Colors.destructive
        case .queued, .preparing: return Theme.Colors.textSecondary
        default: return Theme.Colors.textPrimary
        }
    }
}
