import SwiftUI

/// Preferences screen. Deliberately thin — it surfaces the handful of options
/// the app can actually act on today: language, the in-memory cache, and the
/// three conversion parameters the engine honours (format / MP3 bitrate /
/// metadata). Every control is bound to a persisted `AppSettings` /
/// `Localization` value, so choices survive relaunch.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization

    @State private var cacheCleared = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(loc["Настройки"])
                    .font(.inter(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider().background(Theme.Colors.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    generalSection
                    librarySection
                    appearanceSection
                    conversionSection

                    Text(loc["Настройки сохраняются автоматически и применяются к новым конвертациям."])
                        .font(.inter(size: 11))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.top, 4)
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Theme.Colors.bgPrimary)
    }

    // MARK: - General

    private var generalSection: some View {
        settingsCard(title: loc["Основные"]) {
            settingRow(
                title: loc["Язык"],
                subtitle: loc["Язык интерфейса приложения."]
            ) {
                LanguageSwitcher().frame(width: 150)
            }

            Divider().background(Theme.Colors.borderSubtle)

            settingRow(
                title: loc["Кеш обложек"],
                subtitle: loc["Освобождает память, занятую миниатюрами обложек. Файлы не удаляются."]
            ) {
                Button {
                    RowContentCache.clear()
                    withAnimation(.easeOut(duration: 0.15)) { cacheCleared = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation(.easeOut(duration: 0.2)) { cacheCleared = false }
                    }
                } label: {
                    Label(cacheCleared ? loc["Кеш очищен"] : loc["Очистить кеш"],
                          systemImage: cacheCleared ? "checkmark" : "trash")
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        settingsCard(title: loc["Библиотека"]) {
            settingRow(
                title: loc["Автоимпорт из папки"],
                subtitle: loc["Новые аудиофайлы из выбранной папки добавляются в библиотеку автоматически."]
            ) {
                Toggle("", isOn: Binding(
                    get: { appState.autoImportEnabled },
                    set: { appState.setAutoImport(enabled: $0) }
                ))
                .toggleStyle(.switch)
                .tint(Theme.Colors.accentPrimary)
                .labelsHidden()
            }

            if let folder = appState.autoImportFolderURL {
                Divider().background(Theme.Colors.borderSubtle)

                settingRow(
                    title: loc["Папка"],
                    subtitle: folder.path
                ) {
                    Button {
                        appState.chooseAutoImportFolder()
                    } label: {
                        Label(loc["Изменить…"], systemImage: "folder")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        settingsCard(title: loc["Оформление"]) {
            settingRow(
                title: loc["Тема"],
                subtitle: loc["Светлое или тёмное оформление, либо как в системе."]
            ) {
                Picker("", selection: $settings.appearance) {
                    Text(loc["Система"]).tag(AppearanceMode.system)
                    Text(loc["Светлая"]).tag(AppearanceMode.light)
                    Text(loc["Тёмная"]).tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }
        }
    }

    // MARK: - Conversion

    private var conversionSection: some View {
        settingsCard(title: loc["Конвертация"]) {
            settingRow(
                title: loc["Формат по умолчанию"],
                subtitle: loc["Формат, предвыбранный в панели конвертации."]
            ) {
                Picker("", selection: Binding(
                    get: { settings.defaultOutputFormat },
                    set: { newValue in
                        settings.defaultOutputFormat = newValue
                        // Reflect the new default in the toolbar immediately.
                        conversionQueue.selectedTargetFormat = newValue
                    }
                )) {
                    ForEach(ConversionSettings.OutputFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }

            Divider().background(Theme.Colors.borderSubtle)

            settingRow(
                title: loc["Битрейт MP3"],
                subtitle: loc["Постоянный битрейт для MP3. Не влияет на WAV/FLAC/AIFF."]
            ) {
                Picker("", selection: $settings.mp3BitrateKbps) {
                    ForEach(AppSettings.bitrateOptions, id: \.self) { kbps in
                        Text("\(kbps) kbps").tag(kbps)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                .disabled(settings.defaultOutputFormat != .mp3)
                .opacity(settings.defaultOutputFormat != .mp3 ? 0.5 : 1)
            }

            Divider().background(Theme.Colors.borderSubtle)

            settingRow(
                title: loc["Сохранять метаданные"],
                subtitle: loc["Переносить теги исходного файла в конвертированный."]
            ) {
                Toggle("", isOn: $settings.preserveMetadata)
                    .toggleStyle(.switch)
                    .tint(Theme.Colors.accentPrimary)
                    .labelsHidden()
            }

            Divider().background(Theme.Colors.borderSubtle)

            settingRow(
                title: loc["Сохранять обложку"],
                subtitle: loc["Оставлять встроенную обложку. Выкл — обложка удаляется из результата."]
            ) {
                Toggle("", isOn: $settings.preserveArtwork)
                    .toggleStyle(.switch)
                    .tint(Theme.Colors.accentPrimary)
                    .labelsHidden()
            }

            Divider().background(Theme.Colors.borderSubtle)

            settingRow(
                title: loc["Сохранять структуру папок"],
                subtitle: loc["Воссоздавать дерево исходных папок в папке назначения вместо плоского списка."]
            ) {
                Toggle("", isOn: $settings.preserveFolderStructure)
                    .toggleStyle(.switch)
                    .tint(Theme.Colors.accentPrimary)
                    .labelsHidden()
            }

            Divider().background(Theme.Colors.borderSubtle)

            settingRow(
                title: loc["Частота"],
                subtitle: loc["Частота дискретизации выходного файла."]
            ) {
                Picker("", selection: $settings.defaultSampleRate) {
                    ForEach(ConversionSettings.SampleRate.allCases) { rate in
                        Text(sampleRateLabel(rate)).tag(rate)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }

            Divider().background(Theme.Colors.borderSubtle)

            settingRow(
                title: loc["Каналы"],
                subtitle: loc["Число каналов выходного файла."]
            ) {
                Picker("", selection: $settings.defaultChannels) {
                    ForEach(ConversionSettings.ChannelLayout.allCases) { layout in
                        Text(channelLabel(layout)).tag(layout)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }

            Divider().background(Theme.Colors.borderSubtle)

            settingRow(
                title: loc["Одновременных конвертаций"],
                subtitle: loc["Сколько файлов конвертируется параллельно. Меньше — стабильнее, больше — быстрее."]
            ) {
                Picker("", selection: $settings.maxParallelConversions) {
                    ForEach(AppSettings.parallelismOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }
        }
    }

    private func sampleRateLabel(_ rate: ConversionSettings.SampleRate) -> String {
        guard let hertz = rate.hertz else { return loc["Оригинал"] }
        let khz = Double(hertz) / 1000
        return khz == khz.rounded() ? "\(Int(khz)) kHz" : String(format: "%.1f kHz", khz)
    }

    private func channelLabel(_ layout: ConversionSettings.ChannelLayout) -> String {
        switch layout {
        case .original: return loc["Оригинал"]
        case .stereo: return loc["Стерео"]
        case .mono: return loc["Моно"]
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: title)
                .padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .djPanel()
        }
    }

    @ViewBuilder
    private func settingRow<Trailing: View>(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.inter(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(.inter(size: 11.5))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            trailing()
        }
    }
}
