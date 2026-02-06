//
//  GalleryView.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = GalleryViewModel()
    @State private var showScanner = false
    @State private var selectedCard: Card?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.filteredCards.isEmpty {
                    emptyStateView
                } else {
                    cardGrid
                }
            }
            .navigationTitle("My Cards")
            .searchable(text: $viewModel.searchText, prompt: "Search cards")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Picker("Sort", selection: $viewModel.sortOption) {
                            ForEach(CardSortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }

                        Toggle("Favorites Only", isOn: $viewModel.showFavoritesOnly)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                ScannerView()
            }
            .navigationDestination(item: $selectedCard) { card in
                CardDetailView(card: card)
            }
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.loadCards()
            }
            .onChange(of: viewModel.sortOption) { _, _ in
                viewModel.loadCards()
            }
            .onChange(of: viewModel.showFavoritesOnly) { _, _ in
                viewModel.loadCards()
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "creditcard")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Cards Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the + button to scan your first card")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showScanner = true
            } label: {
                Label("Add Card", systemImage: "plus")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.filteredCards) { card in
                CardGridItem(card: card)
                    .onTapGesture {
                        viewModel.markAsUsed(card)
                        selectedCard = card
                    }
                    .contextMenu {
                        Button {
                            viewModel.toggleFavorite(card)
                        } label: {
                            Label(
                                card.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: card.isFavorite ? "star.slash" : "star"
                            )
                        }

                        Button(role: .destructive) {
                            viewModel.deleteCard(card)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .padding()
    }
}

struct CardGridItem: View {
    let card: Card
    private let imageStorage = ImageStorageService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let image = loadThumbnail() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 120)
                        .overlay {
                            Image(systemName: "barcode")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                }

                if card.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .padding(8)
                        }
                        Spacer()
                    }
                }

                if card.isInWallet {
                    VStack {
                        HStack {
                            Image(systemName: "wallet.pass")
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                                .padding(8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(card.barcodeFormat.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    private func loadThumbnail() -> UIImage? {
        guard !card.thumbnailPath.isEmpty else { return nil }
        return imageStorage.loadImage(named: card.thumbnailPath)
    }
}

#Preview {
    GalleryView()
        .modelContainer(for: Card.self, inMemory: true)
}
