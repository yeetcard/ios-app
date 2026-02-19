//
//  SettingsView.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @AppStorage("showDebugOverlay") private var showDebugOverlay = false

    var body: some View {
        NavigationStack {
            List {
                Section("Security") {
                    HStack {
                        Label(viewModel.biometricType.displayName, systemImage: iconForBiometric)
                        Spacer()
                        Text(viewModel.isBiometricsAvailable ? "Enabled" : "Unavailable")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Data") {
                    HStack {
                        Text("Saved Cards")
                        Spacer()
                        Text("\(viewModel.cardCount)")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        viewModel.showDeleteAllConfirmation = true
                    } label: {
                        Label("Delete All Cards", systemImage: "trash")
                    }
                    .disabled(viewModel.cardCount == 0)
                }

                Section {
                    Toggle(isOn: $showDebugOverlay) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Debug Overlay")
                            Text("Shows real-time detection data when auto-advance is active")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Developer")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "mailto:support@yeetcard.rocks")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }

                    Link(destination: URL(string: "https://yeetcard.rocks/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Link(destination: URL(string: "https://yeetcard.rocks/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Delete All Cards", isPresented: $viewModel.showDeleteAllConfirmation) {
                Button("Delete All", role: .destructive) {
                    viewModel.deleteAllCards()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete all \(viewModel.cardCount) cards? This action cannot be undone.")
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
        }
    }

    private var iconForBiometric: String {
        switch viewModel.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock"
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Card.self, inMemory: true)
}
