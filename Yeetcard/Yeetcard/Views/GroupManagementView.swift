//
//  GroupManagementView.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

struct GroupManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: GroupManagementViewModel

    init(group: CardGroup? = nil) {
        _viewModel = State(initialValue: GroupManagementViewModel(group: group))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Name") {
                    TextField("e.g., Family Costco", text: $viewModel.groupName)
                }

                Section("Cards in Group (\(viewModel.selectedCards.count))") {
                    if viewModel.selectedCards.isEmpty {
                        Text("Add at least 2 cards to create a group")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.selectedCards) { card in
                            HStack {
                                Text(card.name)
                                Spacer()
                                Text(card.barcodeFormat.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    viewModel.removeCard(card)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Available Cards") {
                    if viewModel.availableCards.isEmpty {
                        Text("No ungrouped cards available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.availableCards) { card in
                            HStack {
                                Text(card.name)
                                Spacer()
                                Text(card.barcodeFormat.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    viewModel.addCard(card)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Group" : "New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save()
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    GroupManagementView()
        .modelContainer(for: [Card.self, CardGroup.self], inMemory: true)
}
