//
//  GroupBarcodeViewModel.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class GroupBarcodeViewModel {
    private var cardDataService: CardDataService?
    private var previousBrightness: CGFloat = 0.5
    private let audioDetectionService: any AudioDetectionServiceProtocol
    private let tapDetectionService: any TapDetectionServiceProtocol

    var group: CardGroup
    var isBeepTapModeEnabled: Bool = false
    var microphonePermissionDenied: Bool = false
    var isDetectionActive: Bool = false
    var tapDebugInfo: TapDebugInfo?
    var audioDebugInfo: AudioDebugInfo?

    var cards: [Card] {
        group.sortedCards
    }

    /// Whether the TabView should use ghost pages for looping (needs > 1 card).
    var usesGhostPages: Bool {
        cards.count > 1
    }

    /// Total page count including ghost pages at each end.
    var loopingPageCount: Int {
        usesGhostPages ? cards.count + 2 : cards.count
    }

    /// The initial page (1 if ghost pages, 0 otherwise).
    var initialPage: Int {
        usesGhostPages ? 1 : 0
    }

    init(
        group: CardGroup,
        audioDetectionService: any AudioDetectionServiceProtocol = AudioDetectionService(),
        tapDetectionService: any TapDetectionServiceProtocol = TapDetectionService()
    ) {
        self.group = group
        self.audioDetectionService = audioDetectionService
        self.tapDetectionService = tapDetectionService
    }

    func setup(modelContext: ModelContext) {
        cardDataService = CardDataService(modelContext: modelContext)
    }

    func currentCardName(at index: Int) -> String {
        guard index >= 0 && index < cards.count else { return "" }
        return cards[index].name
    }

    func markCardAsUsed(at index: Int) {
        guard index >= 0 && index < cards.count else { return }
        cardDataService?.markCardAsUsed(cards[index])
    }

    // MARK: - Ghost Page Helpers

    /// Maps a TabView page tag to a cards array index.
    /// Ghost page 0 → last card, ghost page N+1 → first card.
    func realCardIndex(for page: Int) -> Int {
        guard !cards.isEmpty else { return 0 }
        if !usesGhostPages { return page }
        if page <= 0 { return cards.count - 1 }
        if page > cards.count { return 0 }
        return page - 1
    }

    /// Returns the card to display for a given page tag.
    func cardForPage(_ page: Int) -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards[realCardIndex(for: page)]
    }

    /// Returns the display string "X of Y" for the current page.
    func displayCounter(for page: Int) -> String {
        guard !cards.isEmpty else { return "" }
        let real = realCardIndex(for: page)
        return "\(real + 1) of \(cards.count)"
    }

    /// If the page is on a ghost, returns the corrected real page to snap to. Otherwise nil.
    func handlePageChange(_ page: Int) -> Int? {
        guard usesGhostPages else { return nil }
        let n = cards.count
        if page == 0 { return n }          // ghost-last → snap to real last
        if page == n + 1 { return 1 }      // ghost-first → snap to real first
        return nil
    }

    // MARK: - Auto-Advance

    /// Returns the next page index (in ghost-page space), looping from last real card to first.
    func nextPage(from currentPage: Int) -> Int {
        guard cards.count > 1 else { return currentPage }
        if usesGhostPages {
            let n = cards.count
            let realIndex = currentPage - 1
            let nextReal = (realIndex + 1) % n
            return nextReal + 1
        } else {
            return currentPage
        }
    }

    // MARK: - Beep/Tap Mode

    func enableBeepTapMode(advanceAction: @escaping () -> Void) async {
        let hasPermission = await AudioDetectionService.checkPermission()
        guard hasPermission else {
            microphonePermissionDenied = true
            isBeepTapModeEnabled = false
            return
        }

        audioDetectionService.onSpikeDetected = advanceAction
        audioDetectionService.onDebugUpdate = { [weak self] info in
            self?.audioDebugInfo = info
        }
        tapDetectionService.onTapDetected = advanceAction
        tapDetectionService.onDebugUpdate = { [weak self] info in
            self?.tapDebugInfo = info
        }

        do {
            try audioDetectionService.startListening()
        } catch {
            // Audio failed — tap detection still works
        }
        tapDetectionService.startDetecting()

        isDetectionActive = true
        isBeepTapModeEnabled = true
    }

    func disableBeepTapMode() {
        audioDetectionService.stopListening()
        tapDetectionService.stopDetecting()
        audioDetectionService.onSpikeDetected = nil
        audioDetectionService.onDebugUpdate = nil
        tapDetectionService.onTapDetected = nil
        tapDetectionService.onDebugUpdate = nil
        tapDebugInfo = nil
        audioDebugInfo = nil
        isDetectionActive = false
        isBeepTapModeEnabled = false
    }

    func stopAllDetection() {
        guard isDetectionActive else { return }
        disableBeepTapMode()
    }

    // MARK: - Brightness

    func activateBrightnessBoost() {
        previousBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
    }

    func deactivateBrightnessBoost() {
        UIScreen.main.brightness = previousBrightness
    }
}
