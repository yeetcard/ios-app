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

                SingleCardBarcodeContent(card: viewModel.card)

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
            Button {
                showDetail = true
            } label: {
                Label("Details", systemImage: "info.circle")
                    .font(.subheadline)
            }
            .tint(.white)
        }
        .padding(.bottom, 30)
    }
}

// MARK: - Shared barcode content used by both single card and group views

struct SingleCardBarcodeContent: View {
    let card: Card

    @State private var renderedBarcode: UIImage?
    @State private var originalPhoto: UIImage?
    @State private var showingRendered: Bool = true
    @State private var hasLoaded = false

    private var canToggle: Bool {
        renderedBarcode != nil && originalPhoto != nil
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(card.name)
                .font(.headline)
                .foregroundStyle(.white)

            if showingRendered, let rendered = renderedBarcode {
                Image(uiImage: rendered)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 40)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            } else if let photo = originalPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            } else if !hasLoaded {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                    .frame(height: 200)
            } else {
                Image(systemName: "barcode")
                    .font(.system(size: 80))
                    .foregroundStyle(.gray)
                    .frame(height: 200)
            }

            Text(card.barcodeData)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.gray)
                .textSelection(.enabled)

            Text(card.barcodeFormat.displayName)
                .font(.caption2)
                .foregroundStyle(.gray.opacity(0.7))

            if canToggle {
                Button {
                    showingRendered.toggle()
                } label: {
                    Label(
                        showingRendered ? "Show Photo" : "Show Barcode",
                        systemImage: showingRendered ? "photo" : "barcode"
                    )
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .tint(.white)
            }
        }
        .task {
            await loadImages()
        }
    }

    private func loadImages() async {
        let imageStorage = ImageStorageService.shared
        let barcodeGenerator = BarcodeGeneratorService.shared

        // Load original photo from disk (off main if possible)
        if !card.imagePath.isEmpty {
            originalPhoto = imageStorage.loadImage(named: card.imagePath)
        }

        // Generate rendered barcode if format supports it
        if card.barcodeFormat.canGenerate {
            let screenWidth = await MainActor.run { UIScreen.main.bounds.width }
            let scale = await MainActor.run { UIScreen.main.scale }
            let pixelWidth = screenWidth * scale
            let size: CGSize
            switch card.barcodeFormat {
            case .qr, .aztec:
                size = CGSize(width: pixelWidth, height: pixelWidth)
            case .code128, .code39:
                size = CGSize(width: pixelWidth, height: pixelWidth * 0.4)
            case .pdf417:
                size = CGSize(width: pixelWidth, height: pixelWidth * 0.3)
            default:
                size = CGSize(width: pixelWidth, height: pixelWidth)
            }
            renderedBarcode = barcodeGenerator.generateBarcode(
                data: card.barcodeData,
                format: card.barcodeFormat,
                size: size
            )
        }

        // Default to rendered if available, otherwise photo
        showingRendered = renderedBarcode != nil
        hasLoaded = true
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
    .modelContainer(for: [Card.self, CardGroup.self], inMemory: true)
}
