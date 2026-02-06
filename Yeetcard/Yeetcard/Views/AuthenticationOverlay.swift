//
//  AuthenticationOverlay.swift
//  Yeetcard
//

import SwiftUI

struct AuthenticationOverlay: View {
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
        }
    }

    var isAuthenticated: Bool {
        viewModel.isAuthenticated
    }
}

#Preview {
    AuthenticationOverlay()
}
