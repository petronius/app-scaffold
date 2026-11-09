import Foundation
import AppSync
import AppText

extension CloudSync.Status {
    /// The status as the Settings row shows it.
    var text: String {
        switch self {
        case .off: Copy.sync.status.off
        case .noAccount: Copy.sync.status.noAccount
        case .waiting: Copy.sync.status.waiting
        case .syncing: Copy.sync.status.syncing
        case .synced(let date): Copy.sync.status.synced(time: Format.time(date))
        case .failed(let reason): Copy.sync.status.failed(reason: reason)
        case .deletedInICloud: Copy.sync.status.deletedInICloud
        }
    }
}
