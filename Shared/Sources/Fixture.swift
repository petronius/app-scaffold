import Foundation
import AppCore

/// Sample data for screenshots, previews and tests. Fixed dates, so a
/// screenshot only changes when the app does.
enum Fixture {
    static let anchor = Date(timeIntervalSince1970: 1_762_700_000)

    static let items: [Item] = [
        Item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "Book the car service",
             notes: "Ask about the brake pads.", createdAt: anchor),
        Item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, title: "Return the library books",
             notes: "", createdAt: anchor.addingTimeInterval(-3600)),
        Item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, title: "Plant the tulip bulbs",
             notes: "Fifteen centimetres deep, pointed end up.", createdAt: anchor.addingTimeInterval(-86_400)),
    ]
}
