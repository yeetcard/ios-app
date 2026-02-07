//
//  YeetcardApp.swift
//  Yeetcard
//

import SwiftUI
import SwiftData

@main
struct YeetcardApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAuthenticated = false
    @State private var needsAuthentication = true

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Card.self,
            CardGroup.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .opacity(isAuthenticated ? 1 : 0)

                if needsAuthentication {
                    AuthenticationOverlayContainer(isAuthenticated: $isAuthenticated)
                }
            }
            .onChange(of: isAuthenticated) { _, newValue in
                if newValue {
                    needsAuthentication = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    if !isAuthenticated {
                        needsAuthentication = true
                    }
                case .background:
                    isAuthenticated = false
                    needsAuthentication = true
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

struct AuthenticationOverlayContainer: View {
    @Binding var isAuthenticated: Bool
    @State private var viewModel = AuthenticationViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Image(systemName: viewModel.iconName)
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("Yeetcard")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(viewModel.promptText)
                    .foregroundStyle(.secondary)

                if viewModel.isAuthenticating {
                    ProgressView()
                        .scaleEffect(1.5)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if viewModel.showRetryButton {
                    Button {
                        Task {
                            await viewModel.authenticate()
                            if viewModel.isAuthenticated {
                                isAuthenticated = true
                            }
                        }
                    } label: {
                        Text("Try Again")
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .task {
            await viewModel.authenticate()
            if viewModel.isAuthenticated {
                isAuthenticated = true
            }
        }
    }
}
