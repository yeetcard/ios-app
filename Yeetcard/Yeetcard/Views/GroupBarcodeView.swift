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
                            SingleCardBarcodeContent(card: card)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))

                    HStack(spacing: 30) {
                        if let card = currentCard {
                            NavigationLink {
                                CardDetailView(card: card)
                            } label: {
                                Label("Details", systemImage: "info.circle")
                                    .font(.subheadline)
                            }
                            .tint(.white)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle(viewModel.group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            viewModel.setup(modelContext: modelContext)
            viewModel.activateBrightnessBoost()
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
}

#Preview {
    NavigationStack {
        GroupBarcodeView(group: CardGroup(name: "Family Costco"))
    }
    .modelContainer(for: [Card.self, CardGroup.self], inMemory: true)
}
