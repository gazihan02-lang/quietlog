// QuietLogApp.swift
// QuietLog — Noise & Hearing Health
// iOS 26 · Swift 6 · SwiftData · StoreKit 2

import SwiftUI
import SwiftData

@main
struct QuietLogApp: App {

    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    // MARK: - SwiftData Container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DecibelSample.self,
            NoiseSession.self,
            AlertEvent.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("QuietLog: Could not create ModelContainer — \(error)")
        }
    }()

    // MARK: - Shared Services (injected via environment)
    @State private var subscriptionService = SubscriptionService.shared
    @State private var audioMeterService   = AudioMeterService.shared
    @State private var hapticsService      = HapticsService.shared
    @State private var notificationService = NotificationService.shared

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCompleted {
                    RootView()
                } else {
                    OnboardingContainerView()
                }
            }
            .environment(subscriptionService)
            .environment(audioMeterService)
            .environment(hapticsService)
            .environment(notificationService)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                // Stop 5 Hz UI timer — UI is not visible, no point firing it.
                AudioMeterService.shared.pauseUITimer()
                // Flush pending HealthKit samples, then stop its timer.
                Task { await HealthKitService.shared.flushBatch() }
                HealthKitService.shared.stopBatchTimer()
            case .active:
                // Restart UI timer if a session is still running.
                AudioMeterService.shared.resumeUITimer()
                // Restart HealthKit batch timer.
                HealthKitService.shared.startBatchTimerIfNeeded()
            default:
                break
            }
        }
    }

    // MARK: - Init
    init() {
        // Start StoreKit 2 transaction observer on launch
        Task {
            await SubscriptionService.shared.startObservingTransactions()
        }
        // Configure audio session early
        AudioMeterService.shared.configureAudioSession()
    }
}
