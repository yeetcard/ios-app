//
//  ManualEntryView.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ManualEntryViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Card Information") {
                    TextField("Card Name", text: $viewModel.cardName)

                    Picker("Barcode Type", selection: $viewModel.selectedFormat) {
                        ForEach(viewModel.generatableFormats, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }

                    TextField("Barcode Data", text: $viewModel.barcodeData)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.barcodeData) { _, _ in
                            viewModel.generatePreview()
                        }
                        .onChange(of: viewModel.selectedFormat) { _, _ in
                            viewModel.generatePreview()
                        }
                }

                if let image = viewModel.generatedImage {
                    Section("Preview") {
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 150)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 80)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.saveCard() != nil {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    ManualEntryView()
        .modelContainer(for: Card.self, inMemory: true)
}
