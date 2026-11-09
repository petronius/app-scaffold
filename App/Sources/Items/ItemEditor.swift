import SwiftUI
import AppCore
import AppText

/// What the editor sheet opens on.
enum EditorTarget: Identifiable, Hashable {
    case new
    case edit(Item)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let item): item.id.uuidString
        }
    }
}

/// Adds or edits an item. Save writes to the store, which syncs it.
struct ItemEditor: View {
    let target: EditorTarget
    /// Called with the id of the item saved.
    let onSave: (Item.ID) -> Void

    @Environment(StoreModel.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField(Copy.editor.field.title, text: $title)
                    .focused($titleFocused)
                TextField(Copy.editor.field.notes, text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle(isNew ? Copy.editor.new : Copy.editor.edit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.action.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.action.save, action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if case .edit(let item) = target {
                title = item.title
                notes = item.notes
            }
            titleFocused = true
        }
    }

    private var isNew: Bool { target == .new }

    private func save() {
        switch target {
        case .new:
            if let item = store.add(title: title, notes: notes) { onSave(item.id) }
        case .edit(var item):
            item.title = title
            item.notes = notes
            store.update(item)
            onSave(item.id)
        }
        dismiss()
    }
}
