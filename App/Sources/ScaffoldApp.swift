import SwiftUI
import UIKit

@main
struct ScaffoldApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel(launch: .current)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.store)
                .task { model.store.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.store.sceneBecameActive()
            case .background: model.store.sceneWentToBackground()
            default: break
            }
        }
    }
}

/// Registers for the silent pushes behind the sync's subscription: another
/// device's save wakes this one to fetch. CKSyncEngine handles the push
/// itself once the app is registered.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if LaunchOptions.current.syncAllowed { application.registerForRemoteNotifications() }
        return true
    }
}
