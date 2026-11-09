import SwiftUI
import AppCore
import AppText

/// One item: its title, when it was made, and its notes.
struct ItemDetailScreen: View {
    let item: Item
    let onEdit: () -> Void

    @Environment(StoreModel.self) private var store
    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.trimmedTitle.isEmpty ? Copy.item.untitled : item.trimmedTitle)
                        .font(.title2.weight(.semibold))
                    Text(Copy.item.created(day: Format.day(item.createdAt)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
            }
            if !item.notes.isEmpty {
                Section(Copy.editor.field.notes) {
                    Text(item.notes)
                }
            }
            Section {
                Button(Copy.action.delete, role: .destructive) { confirmingDelete = true }
                    .confirmationDialog(Copy.delete.confirm, isPresented: $confirmingDelete, titleVisibility: .visible) {
                        Button(Copy.action.delete, role: .destructive) { store.delete(item.id) }
                    }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(Copy.action.edit, action: onEdit)
            }
        }
    }
}
