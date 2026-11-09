import SwiftUI
import AppCore
import AppText

/// The example feature: a list of items and the selected item's detail. A
/// split view, so iPad shows both columns and iPhone pushes the detail.
///
/// DEBUG `-DebugScreen` values for this tab:
/// - `item:<n>`: the n-th item selected, counting from 0.
/// - `editor`: the new-item sheet open.
struct ItemsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreModel.self) private var store
    @State private var selection: Item.ID?
    @State private var editing: EditorTarget?
    @State private var appliedLaunch = false

    var body: some View {
        NavigationSplitView {
            list
                .navigationTitle(Copy.tab.items)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            editing = .new
                        } label: {
                            Label(Copy.action.add, systemImage: "plus")
                        }
                    }
                }
        } detail: {
            if let item = store.item(selection) {
                ItemDetailScreen(item: item, onEdit: { editing = .edit(item) })
            } else {
                ContentUnavailableView(Copy.items.select, systemImage: "checklist")
            }
        }
        .sheet(item: $editing) { target in
            ItemEditor(target: target) { selection = $0 }
        }
        .onChange(of: store.loaded) { applyLaunch() }
        .onAppear(perform: applyLaunch)
    }

    @ViewBuilder
    private var list: some View {
        if !store.loaded {
            ProgressView()
        } else if store.items.isEmpty {
            ContentUnavailableView {
                Label(Copy.items.empty.title, systemImage: "checklist")
            } description: {
                Text(Copy.items.empty.message)
            }
        } else {
            List(selection: $selection) {
                ForEach(store.items) { item in
                    ItemRow(item: item)
                        .tag(item.id)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(item.id)
                            } label: {
                                Label(Copy.action.delete, systemImage: "trash")
                            }
                        }
                }
            }
            .refreshable { await store.syncNow() }
        }
    }

    private func applyLaunch() {
        #if DEBUG
        guard !appliedLaunch, store.loaded, model.launch.tab ?? .items == .items,
              let screen = model.launch.screen else { return }
        appliedLaunch = true
        if screen == "editor" {
            editing = .new
        } else if screen.hasPrefix("item:"), let n = Int(screen.dropFirst(5)), store.items.indices.contains(n) {
            selection = store.items[n].id
        }
        #endif
    }
}

/// One item in the list: its title and the day it was made.
private struct ItemRow: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.trimmedTitle.isEmpty ? Copy.item.untitled : item.trimmedTitle)
                .font(.body)
                .foregroundStyle(item.trimmedTitle.isEmpty ? .secondary : .primary)
            Text(Format.day(item.createdAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
