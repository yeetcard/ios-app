//
//  FullScreenBarcodeView.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

struct FullScreenBarcodeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: FullScreenBarcodeViewModel
    @State private var showDetail = false

    init(card: Card) {
        _viewModel = State(initialValue: FullScreenBarcodeViewModel(card: card))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                SingleCardBarcodeContent(
                    card: viewModel.card,
                    showingRendered: $viewModel.showingRenderedBarcode
                )

                Spacer()

                bottomControls
            }
        }
        .navigationTitle(viewModel.card.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showDetail = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .tint(.white)
            }
        }
        .navigationDestination(isPresented: $showDetail) {
            CardDetailView(card: viewModel.card)
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
            viewModel.activateBrightnessBoost()
        }
        .onDisappear {
            viewModel.deactivateBrightnessBoost()
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 30) {
            if viewModel.canToggleView {
                Button {
                    viewModel.toggleDisplayMode()
                } label: {
                    Label(
                        viewModel.showingRenderedBarcode ? "Photo" : "Barcode",
                        systemImage: viewModel.showingRenderedBarcode ? "photo" : "barcode"
                    )
                    .font(.subheadline)
                }
                .tint(.white)
            }
        }
        .padding(.bottom, 30)
    }
}

// MARK: - Shared barcode content used by both single card and group views

struct SingleCardBarcodeContent: View {
    let card: Card
    @Binding var showingRendered: Bool

    private let barcodeGenerator: any BarcodeGeneratorServiceProtocol = BarcodeGeneratorService.shared
    private let imageStorage: any ImageStorageServiceProtocol = ImageStorageService.shared

    var body: some View {
        VStack(spacing: 12) {
            Text(card.name)
                .font(.headline)
                .foregroundStyle(.white)

            if showingRendered, card.barcodeFormat.canGenerate,
               let rendered = generateBarcode() {
                Image(uiImage: rendered)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 40)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            } else if let photo = loadPhoto() {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            } else {
                Image(systemName: "barcode")
                    .font(.system(size: 80))
                    .foregroundStyle(.gray)
            }

            Text(card.barcodeData)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.gray)
                .textSelection(.enabled)

            Text(card.barcodeFormat.displayName)
                .font(.caption2)
                .foregroundStyle(.gray.opacity(0.7))
        }
    }

    private func generateBarcode() -> UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let scale = UIScreen.main.scale
        let pixelWidth = screenWidth * scale
        let size: CGSize
        switch card.barcodeFormat {
        case .qr, .aztec:
            size = CGSize(width: pixelWidth, height: pixelWidth)
        case .code128, .code39, .ean13:
            size = CGSize(width: pixelWidth, height: pixelWidth * 0.4)
        case .pdf417:
            size = CGSize(width: pixelWidth, height: pixelWidth * 0.3)
        default:
            size = CGSize(width: pixelWidth, height: pixelWidth)
        }
        return barcodeGenerator.generateBarcode(data: card.barcodeData, format: card.barcodeFormat, size: size)
    }

    private func loadPhoto() -> UIImage? {
        guard !card.imagePath.isEmpty else { return nil }
        return imageStorage.loadImage(named: card.imagePath)
    }
}

#Preview {
    NavigationStack {
        FullScreenBarcodeView(card: Card(
            name: "Test Card",
            barcodeData: "1234567890",
            barcodeFormat: .code128
        ))
    }
    .modelContainer(for: Card.self, inMemory: true)
}
