import Foundation
import Combine

@MainActor
final class PlexDataManager: ObservableObject {
    static let shared = PlexDataManager()

    @Published var streams: [PlexStream] = []
    @Published var bandwidth: [BandwidthEntry] = []
    @Published var resources: SystemResources?
    @Published var serverName: String = "—"
    @Published var serverVersion: String = ""
    @Published var isConnected: Bool = false

    private var timer: Timer?
    private let nativeStats = NativeSystemStats.shared

    // Rolling history buffers
    private var cpuHistory: [Double] = []
    private var ramHistory: [Double] = []
    private var bandwidthHistory: [BandwidthEntry] = []
    private let historySize = 30
    private let bandwidthHistorySize = 60

    func startPolling() {
        _ = nativeStats.cpuUsage() // Prime CPU baseline
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetch() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func fetch() {
        Task {
            let snapshot = await PlexAPIClient.shared.fetchSnapshot()
            self.streams = snapshot.streams
            self.serverName = snapshot.serverName
            self.serverVersion = snapshot.serverVersion
            self.isConnected = snapshot.serverName != "—"

            // Derive real-time bandwidth from active sessions
            let lanMbps = snapshot.streams
                .filter { $0.isLocal }
                .reduce(0.0) { $0 + $1.bandwidthMbps }
            let wanMbps = snapshot.streams
                .filter { !$0.isLocal }
                .reduce(0.0) { $0 + $1.bandwidthMbps }

            let entry = BandwidthEntry(
                timestamp: Date(),
                lanMbps: lanMbps,
                wanMbps: wanMbps
            )
            bandwidthHistory.append(entry)
            if bandwidthHistory.count > bandwidthHistorySize {
                bandwidthHistory.removeFirst()
            }
            self.bandwidth = bandwidthHistory

            // Native Mach APIs for host CPU/RAM (matches Activity Monitor)
            let hostCpu = nativeStats.cpuUsage()
            let hostRam = nativeStats.memoryUsage()
            cpuHistory.append(hostCpu)
            ramHistory.append(hostRam)
            if cpuHistory.count > historySize { cpuHistory.removeFirst() }
            if ramHistory.count > historySize { ramHistory.removeFirst() }

            let plexCpu = snapshot.resources?.plexCpu ?? 0
            let plexRam = snapshot.resources?.plexRam ?? 0

            self.resources = SystemResources(
                hostCpu: hostCpu,
                hostRam: hostRam,
                plexCpu: plexCpu,
                plexRam: plexRam,
                cpuHistory: cpuHistory,
                ramHistory: ramHistory
            )
        }
    }
}
