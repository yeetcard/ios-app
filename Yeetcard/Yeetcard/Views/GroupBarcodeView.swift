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
    @State private var currentPage: Int
    @State private var showDetail = false
    @State private var cardShowingRendered: [UUID: Bool] = [:]
    @State private var showMicPermissionAlert = false

    init(group: CardGroup) {
        let vm = GroupBarcodeViewModel(group: group)
        _viewModel = State(initialValue: vm)
        _currentPage = State(initialValue: vm.initialPage)
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
                    Text(viewModel.displayCounter(for: currentPage))
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.top, 8)

                    loopingTabView

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
            viewModel.stopAllDetection()
        }
        .onChange(of: currentPage) { _, newPage in
            // Ghost page snap-back (without animation)
            if let corrected = viewModel.handlePageChange(newPage) {
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    currentPage = corrected
                }
                return
            }
            // Mark the real card as used
            let realIndex = viewModel.realCardIndex(for: newPage)
            viewModel.markCardAsUsed(at: realIndex)
        }
        .onChange(of: viewModel.microphonePermissionDenied) { _, denied in
            if denied { showMicPermissionAlert = true }
        }
        .alert("Microphone Access Required", isPresented: $showMicPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Yeetcard needs microphone access to detect beep sounds for auto-advancing cards. Please enable it in Settings.")
        }
    }

    // MARK: - Looping TabView

    @ViewBuilder
    private var loopingTabView: some View {
        if viewModel.usesGhostPages {
            TabView(selection: $currentPage) {
                // Ghost of last card (tag 0)
                ghostPage(for: viewModel.cards.count - 1, tag: 0)

                // Real cards (tags 1..N)
                ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                    SingleCardBarcodeContent(
                        card: card,
                        showingRendered: bindingForCard(card)
                    )
                    .tag(index + 1)
                }

                // Ghost of first card (tag N+1)
                ghostPage(for: 0, tag: viewModel.cards.count + 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        } else {
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
        }
    }

    private func ghostPage(for cardIndex: Int, tag: Int) -> some View {
        let card = viewModel.cards[cardIndex]
        return SingleCardBarcodeContent(
            card: card,
            showingRendered: bindingForCard(card)
        )
        .tag(tag)
    }

    // MARK: - Current Card

    private var currentCard: Card? {
        viewModel.cardForPage(currentPage)
    }

    // MARK: - Bottom Controls

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

            if viewModel.cards.count > 1 {
                Button {
                    toggleBeepTapMode()
                } label: {
                    Label(
                        viewModel.isBeepTapModeEnabled ? "Auto On" : "Auto Off",
                        systemImage: viewModel.isBeepTapModeEnabled
                            ? "waveform.circle.fill"
                            : "waveform.circle"
                    )
                    .font(.subheadline)
                }
                .tint(viewModel.isBeepTapModeEnabled ? .green : .white)
            }
        }
        .padding(.bottom, 30)
    }

    // MARK: - Toggle Beep/Tap Mode

    private func toggleBeepTapMode() {
        Task {
            if viewModel.isBeepTapModeEnabled {
                viewModel.disableBeepTapMode()
            } else {
                await viewModel.enableBeepTapMode { [self] in
                    withAnimation {
                        currentPage = viewModel.nextPage(from: currentPage)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

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
