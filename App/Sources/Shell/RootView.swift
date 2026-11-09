import SwiftUI
import AppText

/// The app's shell: one tab per area. iPhone shows a tab bar; iPad shows the
/// same tabs as a sidebar, and each tab lays out its own columns (the Items
/// tab is a split view). New screens work in both widths.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            Tab(Copy.tab.items, systemImage: "checklist", value: AppTab.items) {
                ItemsScreen()
            }
            Tab(Copy.tab.library, systemImage: "book", value: AppTab.library) {
                LibraryScreen()
            }
            Tab(Copy.tab.settings, systemImage: "gearshape", value: AppTab.settings) {
                SettingsScreen()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .debugArticleSheet(model.launch)
    }
}
