//
//  ScannerView.swift
//  Yeetcard
//

import SwiftUI
import SwiftData
import AVFoundation

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ScannerViewModel()
    @State private var showManualEntry = false
    @State private var cardName = ""
    @State private var showNamePrompt = false
    @State private var capturedImage: UIImage?
    @State private var capturedBarcode: DetectedBarcode?

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.hasPermission {
                    cameraPreview
                    overlayContent
                } else {
                    permissionDeniedView
                }
            }
            .navigationTitle("Scan Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Manual Entry") {
                        showManualEntry = true
                    }
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView()
            }
            .alert("Name Your Card", isPresented: $showNamePrompt) {
                TextField("Card Name", text: $cardName)
                Button("Save") {
                    saveCard()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.reset()
                }
            } message: {
                Text("Enter a name for this card")
            }
            .task {
                await viewModel.checkPermission()
                viewModel.startScanning()
            }
            .onDisappear {
                viewModel.stopScanning()
            }
        }
    }

    private var cameraPreview: some View {
        CameraPreviewView(previewLayer: viewModel.previewLayer)
            .ignoresSafeArea()
    }

    private var overlayContent: some View {
        VStack {
            Spacer()

            scannerFrame

            Spacer()

            controlsBar
        }
    }

    private var scannerFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .stroke(statusColor, lineWidth: 3)
                .frame(width: 280, height: 180)

            if case .detected = viewModel.state {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .idle, .scanning:
            return .white
        case .detected, .captured:
            return .green
        case .error:
            return .red
        }
    }

    private var controlsBar: some View {
        HStack(spacing: 40) {
            if viewModel.isFlashAvailable {
                Button {
                    viewModel.toggleFlash()
                } label: {
                    Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.bottom, 40)
        .onChange(of: viewModel.state) { _, newState in
            if case .captured(let image, let barcode) = newState {
                capturedImage = image
                capturedBarcode = barcode
                showNamePrompt = true
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please enable camera access in Settings to scan cards")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func saveCard() {
        guard let image = capturedImage, let barcode = capturedBarcode else { return }

        let cardDataService = CardDataService(modelContext: modelContext)
        _ = cardDataService.createCard(
            name: cardName.isEmpty ? "Unnamed Card" : cardName,
            barcodeData: barcode.data,
            barcodeFormat: barcode.format,
            image: image
        )

        cardName = ""
        capturedImage = nil
        capturedBarcode = nil
        dismiss()
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = CameraContainerView(previewLayer: previewLayer)
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }
}

private class CameraContainerView: UIView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

#Preview {
    ScannerView()
        .modelContainer(for: Card.self, inMemory: true)
}
