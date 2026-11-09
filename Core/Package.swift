// swift-tools-version:6.0
import PackageDescription

// Everything the app, the watch app and the widgets share, testable with
// `swift test` and no simulator.
//
//   AppCore   domain models and the sync rules: pure functions, no I/O, no
//             clock, no CloudKit. A feature's logic lives here.
//   AppText   the one set of formatting functions and the generated copy
//             table (Copy/copy.tsv, Scripts/gen-copy.sh).
//   AppData   the local store: GRDB over SQLite in the App Group container,
//             shared with the widgets. The source of truth on each device.
//   AppSync   iCloud sync of the store through CKSyncEngine and the user's
//             private CloudKit database. No server of our own.
let package = Package(
    name: "AppCore",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "AppText", targets: ["AppText"]),
        .library(name: "AppData", targets: ["AppData"]),
        .library(name: "AppSync", targets: ["AppSync"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(name: "AppCore"),
        .target(name: "AppText", dependencies: ["AppCore"]),
        .target(name: "AppData", dependencies: ["AppCore", .product(name: "GRDB", package: "GRDB.swift")]),
        .target(name: "AppSync", dependencies: ["AppCore", "AppData"]),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"]),
        // Also scans every Swift source in the repository for the
        // formatting calls the one-formatting rule forbids.
        .testTarget(name: "AppTextTests", dependencies: ["AppText", "AppCore"]),
        .testTarget(name: "AppDataTests", dependencies: ["AppData", "AppCore"]),
        .testTarget(name: "AppSyncTests", dependencies: ["AppSync", "AppData", "AppCore"]),
    ]
)
