import SwiftUI
import AppCore
import AppText

/// The watch app: a peer of the phone, with its own store and its own sync.
/// It works without the phone in reach; the two meet through iCloud.
///
/// DEBUG launch argument: `-DebugFixture 1` for sample items in a store in
/// memory, with no sync.
@main
struct ScaffoldWatchApp: App {
    @State private var store = StoreModel(fixture: WatchLaunch.fixture, syncAllowed: !WatchLaunch.fixture)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
                .task { store.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: store.sceneBecameActive()
            case .background: store.sceneWentToBackground()
            default: break
            }
        }
    }
}

enum WatchLaunch {
    static let fixture: Bool = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let i = arguments.firstIndex(of: "-DebugFixture"), i + 1 < arguments.count else { return false }
        return arguments[i + 1] == "1"
        #else
        return false
        #endif
    }()
}

struct WatchRootView: View {
    @Environment(StoreModel.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if !store.loaded {
                    ProgressView()
                } else {
                    List {
                        TextFieldLink(prompt: Text(Copy.editor.field.title)) {
                            Label(Copy.action.add, systemImage: "plus")
                        } onSubmit: { title in
                            store.add(title: title, notes: "")
                        }
                        if store.items.isEmpty {
                            Text(Copy.watch.empty).foregroundStyle(.secondary)
                        }
                        ForEach(store.items) { item in
                            NavigationLink(value: item.id) {
                                Text(item.trimmedTitle.isEmpty ? Copy.item.untitled : item.trimmedTitle)
                                    .lineLimit(2)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { store.delete(store.items[index].id) }
                        }
                    }
                }
            }
            .navigationTitle(Copy.app.name)
            .navigationDestination(for: Item.ID.self) { id in
                if let item = store.item(id) { WatchItemView(item: item) }
            }
        }
    }
}

struct WatchItemView: View {
    let item: Item

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.trimmedTitle.isEmpty ? Copy.item.untitled : item.trimmedTitle)
                    .font(.headline)
                Text(Format.day(item.createdAt))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if !item.notes.isEmpty {
                    Text(item.notes).font(.body)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
