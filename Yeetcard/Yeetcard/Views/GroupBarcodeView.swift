//
//  GroupBarcodeView.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

struct GroupBarcodeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: GroupBarcodeViewModel
    @State private var currentPage: Int = 0
    @State private var showDetail = false
    @State private var cardShowingRendered: [UUID: Bool] = [:]

    init(group: CardGroup) {
        _viewModel = State(initialValue: GroupBarcodeViewModel(group: group))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.cards.isEmpty {
                    Text("No cards in this group")
                        .foregroundStyle(.gray)
                        .frame(maxHeight: .infinity)
                } else {
                    Text("\(currentPage + 1) of \(viewModel.cards.count)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.top, 8)

                    TabView(selection: $currentPage) {
                        ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                            SingleCardBarcodeContent(
                                card: card,
                                showingRendered: bindingForCard(card)
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))

                    bottomControls
                }
            }
        }
        .navigationTitle(viewModel.group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let card = currentCard {
                    NavigationLink {
                        CardDetailView(card: card)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .tint(.white)
                }
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
            viewModel.activateBrightnessBoost()
            initializeCardStates()
        }
        .onDisappear {
            viewModel.deactivateBrightnessBoost()
        }
        .onChange(of: currentPage) { _, newPage in
            viewModel.markCardAsUsed(at: newPage)
        }
    }

    private var currentCard: Card? {
        guard currentPage >= 0 && currentPage < viewModel.cards.count else { return nil }
        return viewModel.cards[currentPage]
    }

    private var bottomControls: some View {
        HStack(spacing: 30) {
            if let card = currentCard, card.barcodeFormat.canGenerate, !card.imagePath.isEmpty {
                let isShowingRendered = cardShowingRendered[card.id] ?? true
                Button {
                    cardShowingRendered[card.id] = !isShowingRendered
                } label: {
                    Label(
                        isShowingRendered ? "Photo" : "Barcode",
                        systemImage: isShowingRendered ? "photo" : "barcode"
                    )
                    .font(.subheadline)
                }
                .tint(.white)
            }
        }
        .padding(.bottom, 30)
    }

    private func bindingForCard(_ card: Card) -> Binding<Bool> {
        Binding(
            get: { cardShowingRendered[card.id] ?? card.barcodeFormat.canGenerate },
            set: { cardShowingRendered[card.id] = $0 }
        )
    }

    private func initializeCardStates() {
        for card in viewModel.cards {
            if cardShowingRendered[card.id] == nil {
                cardShowingRendered[card.id] = card.barcodeFormat.canGenerate
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupBarcodeView(group: CardGroup(name: "Family Costco"))
    }
    .modelContainer(for: [Card.self, CardGroup.self], inMemory: true)
}
