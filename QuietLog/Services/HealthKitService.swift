// HealthKitService.swift
// QuietLog — Noise & Hearing Health

import Foundation
import HealthKit

// MARK: - HealthKit Service
@Observable
@MainActor
final class HealthKitService {

    static let shared = HealthKitService()
    private init() {}

    // MARK: - State
    var isAuthorized: Bool          = false
    var lastSyncDate: Date?         = nil
    var recordsWrittenCount: Int    = 0
    var syncError: String?          = nil

    private let healthStore = HKHealthStore()
    private var batchBuffer: [(date: Date, db: Double, source: SampleSource)] = []
    private var batchTimer: Task<Void, Never>?

    // MARK: - Types
    private var writeTypes: Set<HKSampleType> {
        guard
            let envType  = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure),
            let hpType   = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure)
        else { return [] }
        return [envType, hpType]
    }

    private var readTypes: Set<HKObjectType> {
        guard
            let envType  = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure),
            let hpType   = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure)
        else { return [] }
        return [envType, hpType]
    }

    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = checkWriteAuthorization()
            return isAuthorized
        } catch {
            syncError = error.localizedDescription
            return false
        }
    }

    private func checkWriteAuthorization() -> Bool {
        guard let envType = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure) else { return false }
        return healthStore.authorizationStatus(for: envType) == .sharingAuthorized
    }

    // MARK: - Writing Samples
    /// Enqueues a single dB sample. Batch-writes to HealthKit every 60 seconds.
    func enqueueSample(db: Double, source: SampleSource, date: Date = Date()) {
        guard UserPreferences.shared.healthKitWriteEnabled, isAuthorized else { return }
        batchBuffer.append((date: date, db: db, source: source))

        // Ensure batch timer is running
        if batchTimer == nil {
            batchTimer = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    await self?.flushBatch()
                }
            }
        }
    }

    /// Flushes accumulated samples as one-minute averages
    func flushBatch() async {
        guard !batchBuffer.isEmpty else { return }

        let toWrite = batchBuffer
        batchBuffer.removeAll()

        // Group by source and build quantity samples
        var samples: [HKQuantitySample] = []
        let dbaUnit = HKUnit.decibelAWeightedSoundPressureLevel()

        // Environmental samples
        let envSamples = toWrite.filter { $0.source == .environmental }
        if !envSamples.isEmpty,
           let envType = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure) {
            let avg = envSamples.map(\.db).reduce(0, +) / Double(envSamples.count)
            let start = envSamples.min(by: { $0.date < $1.date })?.date ?? Date()
            let end   = envSamples.max(by: { $0.date < $1.date })?.date ?? Date()
            let qty = HKQuantity(unit: dbaUnit, doubleValue: avg)
            samples.append(HKQuantitySample(type: envType, quantity: qty, start: start, end: end))
        }

        // Headphone samples
        let hpSamples = toWrite.filter { $0.source == .headphone }
        if !hpSamples.isEmpty,
           let hpType = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) {
            let avg = hpSamples.map(\.db).reduce(0, +) / Double(hpSamples.count)
            let start = hpSamples.min(by: { $0.date < $1.date })?.date ?? Date()
            let end   = hpSamples.max(by: { $0.date < $1.date })?.date ?? Date()
            let qty = HKQuantity(unit: dbaUnit, doubleValue: avg)
            samples.append(HKQuantitySample(type: hpType, quantity: qty, start: start, end: end))
        }

        guard !samples.isEmpty else { return }

        do {
            try await healthStore.save(samples)
            recordsWrittenCount += samples.count
            lastSyncDate = Date()
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Reading Samples (from Apple Watch / other sources)
    func fetchRecentExposure(days: Int = 30) async -> [HKQuantitySample] {
        guard UserPreferences.shared.healthKitReadEnabled,
              let envType = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)
        else { return [] }

        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: envType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Stop
    func stopBatchTimer() {
        batchTimer?.cancel()
        batchTimer = nil
    }
}
