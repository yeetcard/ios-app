//
//  CardDetailView.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CardDetailViewModel

    init(card: Card) {
        _viewModel = State(initialValue: CardDetailViewModel(card: card))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                cardImageSection

                cardInfoSection

                if viewModel.canAddToWallet {
                    walletSection
                }

                if !viewModel.card.notes.isEmpty || viewModel.isEditing {
                    notesSection
                }

                deleteSection
            }
            .padding()
        }
        .navigationTitle(viewModel.isEditing ? "Edit Card" : viewModel.card.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isEditing {
                    Button("Done") {
                        viewModel.saveChanges()
                    }
                } else {
                    Menu {
                        Button {
                            viewModel.startEditing()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            viewModel.toggleFavorite()
                        } label: {
                            Label(
                                viewModel.card.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: viewModel.card.isFavorite ? "star.slash" : "star"
                            )
                        }

                        ShareLink(
                            item: viewModel.card.barcodeData,
                            subject: Text(viewModel.card.name),
                            message: Text("Barcode: \(viewModel.card.barcodeData)")
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }

            if viewModel.isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelEditing()
                    }
                }
            }
        }
        .alert("Delete Card", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deleteCard()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this card? This action cannot be undone.")
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
            viewModel.markAsUsed()
        }
        .onDisappear {
            if viewModel.isBrightnessBoostEnabled {
                viewModel.toggleBrightnessBoost()
            }
        }
    }

    private var cardImageSection: some View {
        VStack(spacing: 12) {
            if let image = viewModel.cardImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 200)
                    .overlay {
                        Image(systemName: "barcode")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                    }
            }

            Button {
                viewModel.toggleBrightnessBoost()
            } label: {
                Label(
                    viewModel.isBrightnessBoostEnabled ? "Brightness Boosted" : "Boost Brightness",
                    systemImage: viewModel.isBrightnessBoostEnabled ? "sun.max.fill" : "sun.max"
                )
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
    }

    private var cardInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isEditing {
                TextField("Card Name", text: $viewModel.editedName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Label(viewModel.card.barcodeFormat.displayName, systemImage: "barcode")
                Spacer()
                if viewModel.card.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
                if viewModel.card.isInWallet {
                    Image(systemName: "wallet.pass.fill")
                        .foregroundStyle(.blue)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text(viewModel.card.barcodeData)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if let lastUsed = viewModel.card.lastUsed {
                Text("Last used: \(lastUsed.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var walletSection: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await viewModel.addToWallet()
                }
            } label: {
                HStack {
                    Image(systemName: "wallet.pass")
                    Text("Add to Apple Wallet")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isAddingToWallet)

            if viewModel.isAddingToWallet {
                ProgressView()
            }

            if let error = viewModel.walletError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)

            if viewModel.isEditing {
                TextEditor(text: $viewModel.editedNotes)
                    .frame(minHeight: 80)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    }
            } else {
                Text(viewModel.card.notes)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deleteSection: some View {
        Button(role: .destructive) {
            viewModel.showDeleteConfirmation = true
        } label: {
            Label("Delete Card", systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: Card(
            name: "Test Card",
            barcodeData: "1234567890",
            barcodeFormat: .code128
        ))
    }
    .modelContainer(for: Card.self, inMemory: true)
}
