import Foundation

/// The record types in the app's CloudKit zone: one per kind of fact the user
/// authors, never a whole store in one payload. The raw value is the CloudKit
/// record type name; the prefix builds the record name (`<prefix>-<key>`, or
/// the bare prefix for a singleton), so a record is addressable from its name
/// alone on every device.
///
/// A deployed record type can never be renamed or removed in CloudKit, so a
/// case here is permanent once it has shipped. Adding one is the checklist in
/// `spec/capabilities/CloudSync/README.md`.
public enum SyncRecordType: String, CaseIterable, Codable, Sendable {
    case item = "Item"

    public var namePrefix: String {
        switch self {
        case .item: "item"
        }
    }

    /// `item-<uuid>`.
    public func recordName(key: String) -> String { namePrefix + "-" + key }

    /// The type and key a record name was built from. Nil for a name this
    /// build does not know (a type added by a newer build).
    public static func parse(recordName: String) -> (type: SyncRecordType, key: String?)? {
        for type in allCases {
            if recordName == type.namePrefix { return (type, nil) }
            let prefix = type.namePrefix + "-"
            if recordName.hasPrefix(prefix) { return (type, String(recordName.dropFirst(prefix.count))) }
        }
        return nil
    }
}
