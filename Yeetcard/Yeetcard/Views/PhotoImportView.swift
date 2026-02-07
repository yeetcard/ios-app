//
//  PhotoImportView.swift
//  Yeetcard
//

import SwiftUI
import SwiftData
import PhotosUI

struct PhotoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PhotoImportViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                switch viewModel.state {
                case .pickingPhoto:
                    PhotosPicker(
                        selection: $viewModel.selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                            Text("Select a photo containing a barcode")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                case .detecting:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Detecting barcode...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .detected(let barcode, let image):
                    detectedView(barcode: barcode, image: image)

                case .noBarcodeFound:
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("No barcode found in this photo")
                            .font(.headline)
                        Text("Try selecting a clearer photo of the barcode")
                            .foregroundStyle(.secondary)
                        Button("Try Another Photo") {
                            viewModel.reset()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .error(let message):
                    VStack(spacing: 16) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.red)
                        Text(message)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            viewModel.reset()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Import from Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
        }
    }

    private func detectedView(barcode: DetectedBarcode, image: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Label(barcode.format.displayName, systemImage: "barcode")
                    Spacer()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(barcode.data)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                TextField("Card Name", text: $viewModel.cardName)
                    .textFieldStyle(.roundedBorder)

                Button {
                    viewModel.saveCard()
                    dismiss()
                } label: {
                    Text("Save Card")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.cardName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
    }
}

#Preview {
    PhotoImportView()
        .modelContainer(for: Card.self, inMemory: true)
}
