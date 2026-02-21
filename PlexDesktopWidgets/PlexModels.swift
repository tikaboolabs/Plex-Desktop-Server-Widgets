import Foundation

// MARK: - Plex Stream
struct PlexStream: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let user: String
    let player: String
    let progress: Double
    let quality: String
    let bandwidthMbps: Double
    let mediaType: MediaType
    let isTranscoding: Bool
    let isLocal: Bool
    let state: PlayState
    let durationMs: Int
    let viewOffsetMs: Int
    let thumbUrl: String?

    enum MediaType: String, Codable, Hashable {
        case movie, tv, music
    }

    enum PlayState: String, Codable, Hashable {
        case playing, paused, buffering
    }

    var remainingFormatted: String {
        let remainingSec = max(0, Double(durationMs - viewOffsetMs) / 1000)
        let m = Int(remainingSec) / 60
        let s = Int(remainingSec) % 60
        return "-\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Bandwidth Entry
struct BandwidthEntry: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let lanMbps: Double
    let wanMbps: Double
    var totalMbps: Double { lanMbps + wanMbps }

    enum CodingKeys: String, CodingKey {
        case timestamp, lanMbps, wanMbps
    }
}

// MARK: - System Resources
struct SystemResources: Codable {
    let hostCpu: Double
    let hostRam: Double
    let plexCpu: Double
    let plexRam: Double
    let cpuHistory: [Double]
    let ramHistory: [Double]
}

// MARK: - Snapshot
struct PlexSnapshot {
    let timestamp: Date
    let streams: [PlexStream]
    let bandwidth: [BandwidthEntry]
    let resources: SystemResources?
    let serverName: String
    let serverVersion: String

    static let empty = PlexSnapshot(
        timestamp: Date(), streams: [], bandwidth: [],
        resources: nil, serverName: "—", serverVersion: ""
    )
}

// MARK: - API Response Models
struct PlexSessionMetadata: Codable {
    let ratingKey: String?
    let sessionKey: String?
    let type: String?
    let title: String?
    let grandparentTitle: String?
    let parentTitle: String?
    let parentIndex: Int?
    let index: Int?
    let year: Int?
    let studio: String?
    let duration: Int?
    let viewOffset: Int?
    let thumb: String?
    let grandparentThumb: String?
    let parentThumb: String?
    let art: String?
    let User: PlexUser?
    let Player: PlexPlayer?
    let Media: [PlexMedia]?
    let Session: PlexSession?
    let TranscodeSession: PlexTranscodeSession?
    let Director: [PlexTag]?
}

struct PlexUser: Codable { let title: String? }
struct PlexPlayer: Codable { let title: String?; let product: String?; let device: String?; let state: String?; let local: Bool? }
struct PlexMedia: Codable { let videoResolution: String?; let videoProfile: String?; let audioCodec: String? }
struct PlexSession: Codable { let bandwidth: Int? }
struct PlexTranscodeSession: Codable { let key: String? }
struct PlexTag: Codable { let tag: String? }

struct PlexResourceStat: Codable {
    let at: Int?
    let hostCpuUtilization: Double?
    let hostMemoryUtilization: Double?
    let processCpuUtilization: Double?
    let processMemoryUtilization: Double?
}
