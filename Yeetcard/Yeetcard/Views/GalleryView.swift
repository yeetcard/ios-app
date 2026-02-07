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
    @State private var showPhotoImport = false
    @State private var showGroupCreation = false
    @State private var selectedCard: Card?
    @State private var selectedGroup: CardGroup?
    @State private var groupToEdit: CardGroup?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isEmpty {
                    emptyStateView
                } else {
                    galleryGrid
                }
            }
            .navigationTitle("My Cards")
            .searchable(text: $viewModel.searchText, prompt: "Search cards")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan Card", systemImage: "camera")
                        }

                        Button {
                            showPhotoImport = true
                        } label: {
                            Label("Import from Photo", systemImage: "photo")
                        }

                        Divider()

                        Button {
                            showGroupCreation = true
                        } label: {
                            Label("Create Group", systemImage: "folder.badge.plus")
                        }
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
            .sheet(isPresented: $showPhotoImport) {
                PhotoImportView()
            }
            .sheet(isPresented: $showGroupCreation) {
                GroupManagementView()
            }
            .sheet(item: $groupToEdit) { group in
                GroupManagementView(group: group)
            }
            .navigationDestination(item: $selectedCard) { card in
                FullScreenBarcodeView(card: card)
            }
            .navigationDestination(item: $selectedGroup) { group in
                GroupBarcodeView(group: group)
            }
            .onChange(of: showScanner) { _, isShowing in
                if !isShowing { viewModel.loadCards() }
            }
            .onChange(of: showPhotoImport) { _, isShowing in
                if !isShowing { viewModel.loadCards() }
            }
            .onChange(of: showGroupCreation) { _, isShowing in
                if !isShowing { viewModel.loadCards() }
            }
            .onChange(of: groupToEdit) { _, newValue in
                if newValue == nil { viewModel.loadCards() }
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

            Text("Tap the + button to scan or import your first card")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showScanner = true
            } label: {
                Label("Scan Card", systemImage: "camera")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var galleryGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.galleryItems) { item in
                switch item {
                case .card(let card):
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

                case .group(let group):
                    GroupGridItem(group: group)
                        .onTapGesture {
                            selectedGroup = group
                        }
                        .contextMenu {
                            Button {
                                groupToEdit = group
                            } label: {
                                Label("Edit Group", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                viewModel.deleteGroup(group)
                            } label: {
                                Label("Delete Group", systemImage: "trash")
                            }
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

struct GroupGridItem: View {
    let group: CardGroup
    private let imageStorage = ImageStorageService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                // Back card layer (offset for stacked effect)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 120)
                    .offset(x: 4, y: -4)

                // Front card layer
                if let primaryCard = group.primaryCard, let image = loadThumbnail(for: primaryCard) {
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
                            Image(systemName: "rectangle.stack")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                }

                // Card count badge
                VStack {
                    HStack {
                        Spacer()
                        Text("\(group.cardCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue)
                            .clipShape(Capsule())
                            .padding(8)
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("\(group.cardCount) cards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    private func loadThumbnail(for card: Card) -> UIImage? {
        guard !card.thumbnailPath.isEmpty else { return nil }
        return imageStorage.loadImage(named: card.thumbnailPath)
    }
}

#Preview {
    GalleryView()
        .modelContainer(for: [Card.self, CardGroup.self], inMemory: true)
}
