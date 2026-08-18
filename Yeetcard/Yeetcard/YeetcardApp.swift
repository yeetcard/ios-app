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
            rootView
        }
        .modelContainer(sharedModelContainer)
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if ScreenshotHarness.isActive {
            ScreenshotRootView()
        } else {
            mainContent
        }
        #else
        mainContent
        #endif
    }

    @ViewBuilder
    private var mainContent: some View {
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

#if DEBUG
// MARK: - App Store screenshot harness (DEBUG only, never in a Release archive)
//
// Activated only when the app is launched with `-screenshots`. Seeds a set of
// sample cards and routes directly to a requested screen so screenshots can be
// captured on the Simulator without a camera, biometrics, or manual data entry.
// The whole block is compiled out of Release builds.

enum ScreenshotHarness {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshots")
    }

    /// Which screen to show: "gallery" (default) or "barcode".
    static var screen: String {
        argument(after: "-screen") ?? "gallery"
    }

    /// For the "barcode" screen, which card to open (by name).
    static var cardName: String {
        argument(after: "-card") ?? "Safeway Club"
    }

    private static func argument(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    struct Sample {
        let name: String
        let data: String
        let format: BarcodeFormat
        let favorite: Bool
    }

    static let samples: [Sample] = [
        Sample(name: "Safeway Club", data: "2847193056", format: .code128, favorite: false),
        Sample(name: "Starbucks Rewards", data: "SBUX88912245", format: .qr, favorite: true),
        Sample(name: "CVS ExtraCare", data: "4025519987", format: .code128, favorite: false),
        Sample(name: "United MileagePlus", data: "MP58204417", format: .pdf417, favorite: false),
        Sample(name: "Chipotle Rewards", data: "CMG773412200", format: .aztec, favorite: false),
        Sample(name: "Costco Membership", data: "111827465003", format: .code39, favorite: false),
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Card>())) ?? []
        guard existing.isEmpty else { return }

        let service = CardDataService(modelContext: context)
        let generator = BarcodeGeneratorService.shared
        for sample in samples {
            let image = generator.generateBarcode(data: sample.data, format: sample.format)
            let card = service.createCard(
                name: sample.name,
                barcodeData: sample.data,
                barcodeFormat: sample.format,
                image: image
            )
            if sample.favorite {
                card.isFavorite = true
                service.updateCard(card)
            }
        }
    }
}

struct ScreenshotRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var seeded = false

    var body: some View {
        Group {
            if seeded {
                content
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }
        }
        .task {
            ScreenshotHarness.seedIfNeeded(context: modelContext)
            seeded = true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch ScreenshotHarness.screen {
        case "barcode":
            if let card = cardForBarcode() {
                NavigationStack {
                    FullScreenBarcodeView(card: card)
                }
            } else {
                MainTabView()
            }
        default:
            MainTabView()
        }
    }

    private func cardForBarcode() -> Card? {
        let target = ScreenshotHarness.cardName
        let all = (try? modelContext.fetch(FetchDescriptor<Card>())) ?? []
        return all.first { $0.name == target } ?? all.first
    }
}
#endif
