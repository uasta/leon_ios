import SwiftUI

/// App 设置中心：承接语言等通用偏好，并为后续提醒 / 数据能力预留入口。
struct SettingsView: View {
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        List {
            Section {
                Picker(selection: $languageStore.language) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                } label: {
                    Label(L10n.Settings.language, systemImage: "globe")
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text(L10n.Settings.general)
            } footer: {
                Text(L10n.Settings.languageFooter)
            }

            Section {
                LabeledContent(L10n.Settings.reminderLead, value: L10n.text(L10n.Settings.reminderLeadValue))
                LabeledContent(L10n.Settings.reminderTime, value: L10n.text(L10n.Settings.reminderTimeValue))
            } header: {
                Text(L10n.Settings.reminders)
            }

            Section {
                Button(L10n.Settings.exportBackup) {}
                    .disabled(true)
                Button(L10n.Settings.importData) {}
                    .disabled(true)
            } header: {
                Text(L10n.Settings.data)
            }

            Section {
                LabeledContent(L10n.Settings.version, value: appVersionDisplay)
            } header: {
                Text(L10n.Settings.about)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.Settings.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        default:
            return L10n.text(L10n.Common.notConfigured)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(LanguageStore.shared)
}
