import Foundation
import AppCore

/// DEBUG launch arguments that put the app in a known state for headless
/// screenshots and tests (`Scripts/sim-shot.sh <udid> <app> out.png -DebugTab
/// library`). Release builds ignore them. Each argument is a flag and a value,
/// which is also how UserDefaults reads launch arguments, so every flag
/// carries the `Debug` prefix to keep clear of real settings.
///
/// - `-DebugTab items|library|settings`: the tab to open on.
/// - `-DebugFixture 1`: sample items in a store that lives in memory only, and
///   no sync, so a screenshot never touches real data.
/// - `-DebugScreen <name>`: a screen inside a tab. Each screen documents its
///   own values: `item:<n>` (the n-th sample item, Items tab),
///   `editor` (the new-item sheet), `article:<section>/<article>` (Library).
/// - `-DebugNoSync 1`: no iCloud sync, with the real store.
struct LaunchOptions: Equatable {
    var tab: AppTab?
    var fixture = false
    var screen: String?
    var noSync = false

    static let current: LaunchOptions = {
        #if DEBUG
        return LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
        #else
        return LaunchOptions()
        #endif
    }()

    init() {}

    init(arguments: [String]) {
        func value(_ flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        tab = value("-DebugTab").flatMap(AppTab.init(rawValue:))
        fixture = value("-DebugFixture") == "1"
        screen = value("-DebugScreen")
        noSync = value("-DebugNoSync") == "1"
    }

    /// The sync stays off for a fixture, so sample data never reaches
    /// iCloud, and in the unit-test host, so a test never touches it.
    var syncAllowed: Bool { !fixture && !noSync && !Self.underTest }

    static let underTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}
