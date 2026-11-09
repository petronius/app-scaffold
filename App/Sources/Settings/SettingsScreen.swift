import SwiftUI
import AppText

/// Settings: iCloud sync, and what build this is.
struct SettingsScreen: View {
    @Environment(StoreModel.self) private var store

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(Copy.sync.toggle, isOn: Binding(
                        get: { store.syncEnabled },
                        set: { store.setSyncEnabled($0) }))
                        .disabled(!store.syncAllowed)
                    LabeledContent(Copy.sync.status.label) {
                        HStack(spacing: 0) {
                            Text(store.syncStatus.text)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                            InfoButton(article: .iCloudSync)
                                .padding(.trailing, -10)
                        }
                    }
                    if store.syncEnabled {
                        Button(Copy.action.syncNow) { Task { await store.syncNow() } }
                    }
                } header: {
                    Text(Copy.sync.header)
                } footer: {
                    Text(Copy.sync.footer)
                }

                Section(Copy.about.header) {
                    LabeledContent(Copy.tab.items) {
                        Text(Format.grouped(Double(store.items.count)))
                            .monospacedDigit()
                    }
                    LabeledContent(Copy.about.version, value: BuildInfo.version)
                    LabeledContent(Copy.about.build, value: BuildInfo.build)
                }

                if let error = store.storeError {
                    Section {
                        Text(error).foregroundStyle(Palette.attention)
                    }
                }
            }
            .navigationTitle(Copy.tab.settings)
        }
    }
}

/// The version and build the bundle carries (`project.yml`;
/// `Scripts/testflight.sh` stamps the build number).
enum BuildInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? Copy.figure.noValue
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? Copy.figure.noValue
    }
}
