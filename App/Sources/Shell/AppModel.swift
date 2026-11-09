import SwiftUI
import Observation

/// The tabs. On iPhone a tab bar; on iPad (regular width) the same tabs
/// become a sidebar through `.sidebarAdaptable`.
enum AppTab: String, CaseIterable, Hashable {
    case items, library, settings
}

/// The app's own state above the store: navigation and the launch options.
/// What the user's data is lives in `StoreModel`.
@MainActor @Observable
final class AppModel {
    let launch: LaunchOptions
    let store: StoreModel
    var tab: AppTab

    init(launch: LaunchOptions) {
        self.launch = launch
        self.store = StoreModel(fixture: launch.fixture, syncAllowed: launch.syncAllowed)
        self.tab = launch.tab ?? .items
    }
}
