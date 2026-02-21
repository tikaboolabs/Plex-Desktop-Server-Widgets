import Foundation

final class PlexAPIClient {
    static let shared = PlexAPIClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        self.session = URLSession(configuration: config, delegate: InsecureDelegate.shared, delegateQueue: nil)
    }

    func fetchSnapshot() async -> PlexSnapshot {
        let serverUrl = PlexConfig.shared.serverUrl
        let token = PlexConfig.shared.token
        guard !token.isEmpty else { return .empty }

        async let s = fetchSessions(serverUrl: serverUrl, token: token)
        async let r = fetchResources(serverUrl: serverUrl, token: token)
        async let i = fetchIdentity(serverUrl: serverUrl, token: token)

        return PlexSnapshot(
            timestamp: Date(),
            streams: await s,
            bandwidth: [],  // Bandwidth derived from sessions in PlexDataManager
            resources: await r,
            serverName: await i.0,
            serverVersion: await i.1
        )
    }

    // MARK: - Sessions
    private func fetchSessions(serverUrl: String, token: String) async -> [PlexStream] {
        guard let data = await fetch(serverUrl: serverUrl, path: "/status/sessions", token: token) else { return [] }
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let mc = json?["MediaContainer"] as? [String: Any]
            let metadataArray = mc?["Metadata"] as? [[String: Any]] ?? []

            let reencoded = try JSONSerialization.data(withJSONObject: metadataArray)
            let metadata = try JSONDecoder().decode([PlexSessionMetadata].self, from: reencoded)

            return metadata.map { m in
                let quality = formatQuality(m)
                let bwKbps = m.Session?.bandwidth ?? 0

                let mediaType: PlexStream.MediaType
                switch m.type {
                case "episode": mediaType = .tv
                case "track":   mediaType = .music
                default:        mediaType = .movie
                }

                let subtitle: String
                if m.grandparentTitle != nil {
                    let sNum = m.parentIndex.map { "S\($0)" } ?? ""
                    let eNum = m.index.map { "E\($0)" } ?? ""
                    subtitle = "\(sNum)·\(eNum) — \"\(m.title ?? "")\""
                } else if let year = m.year {
                    let dir = m.Director?.first?.tag ?? m.studio ?? ""
                    subtitle = "\(year) · \(dir)"
                } else {
                    subtitle = m.parentTitle ?? ""
                }

                let state: PlexStream.PlayState
                switch m.Player?.state {
                case "paused":    state = .paused
                case "buffering": state = .buffering
                default:          state = .playing
                }

                // Poster URL: TV → series poster, Music → album art, Movie → movie poster
                let thumbPath: String?
                switch m.type {
                case "episode": thumbPath = m.grandparentThumb ?? m.parentThumb ?? m.thumb
                case "track":   thumbPath = m.parentThumb ?? m.thumb
                default:        thumbPath = m.thumb
                }
                let thumbUrl: String?
                if let path = thumbPath {
                    thumbUrl = "\(serverUrl)/photo/:/transcode?width=120&height=180&minSize=1&upscale=1&url=\(path)&X-Plex-Token=\(token)"
                } else {
                    thumbUrl = nil
                }

                return PlexStream(
                    id: m.sessionKey ?? m.ratingKey ?? UUID().uuidString,
                    title: m.grandparentTitle ?? m.title ?? "Unknown",
                    subtitle: subtitle,
                    user: m.User?.title ?? "Unknown",
                    player: [m.Player?.product, m.Player?.title ?? m.Player?.device]
                        .compactMap { $0 }.joined(separator: " · "),
                    progress: (m.viewOffset != nil && m.duration != nil && m.duration! > 0)
                        ? Double(m.viewOffset!) / Double(m.duration!) : 0,
                    quality: quality,
                    bandwidthMbps: Double(bwKbps) / 1000.0,
                    mediaType: mediaType,
                    isTranscoding: m.TranscodeSession != nil,
                    isLocal: m.Player?.local ?? true,
                    state: state,
                    durationMs: m.duration ?? 0,
                    viewOffsetMs: m.viewOffset ?? 0,
                    thumbUrl: thumbUrl
                )
            }
        } catch {
            print("Sessions decode error: \(error)")
            return []
        }
    }

    // MARK: - Resources
    private func fetchResources(serverUrl: String, token: String) async -> SystemResources? {
        guard let data = await fetch(serverUrl: serverUrl, path: "/statistics/resources?timespan=6", token: token) else { return nil }
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let mc = json?["MediaContainer"] as? [String: Any]
            let statsArray = mc?["StatisticsResources"] as? [[String: Any]] ?? []

            let reencoded = try JSONSerialization.data(withJSONObject: statsArray)
            let stats = try JSONDecoder().decode([PlexResourceStat].self, from: reencoded)

            guard let latest = stats.last else { return nil }
            return SystemResources(
                hostCpu: latest.hostCpuUtilization ?? 0,
                hostRam: latest.hostMemoryUtilization ?? 0,
                plexCpu: latest.processCpuUtilization ?? 0,
                plexRam: latest.processMemoryUtilization ?? 0,
                cpuHistory: stats.suffix(30).map { $0.hostCpuUtilization ?? 0 },
                ramHistory: stats.suffix(30).map { $0.hostMemoryUtilization ?? 0 }
            )
        } catch {
            print("Resources decode error: \(error)")
            return nil
        }
    }

    // MARK: - Identity
    private func fetchIdentity(serverUrl: String, token: String) async -> (String, String) {
        guard let data = await fetch(serverUrl: serverUrl, path: "/", token: token) else { return ("Plex Server", "") }
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let mc = json?["MediaContainer"] as? [String: Any]
            return (mc?["friendlyName"] as? String ?? "Plex Server", mc?["version"] as? String ?? "")
        } catch {
            return ("Plex Server", "")
        }
    }

    // MARK: - HTTP
    private func fetch(serverUrl: String, path: String, token: String) async -> Data? {
        guard var components = URLComponents(string: serverUrl + path) else { return nil }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "X-Plex-Token", value: token))
        components.queryItems = items
        guard let url = components.url else { return nil }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await session.data(for: req)
            return data
        } catch {
            print("Fetch error (\(path)): \(error.localizedDescription)")
            return nil
        }
    }

    private func formatQuality(_ m: PlexSessionMetadata) -> String {
        guard let media = m.Media?.first else { return "Direct" }
        var parts: [String] = []
        if let res = media.videoResolution {
            parts.append(res == "4k" || res == "2160" ? "4K" : "\(res)p")
        }
        if let p = media.videoProfile, p.lowercased().contains("hdr") { parts.append("HDR") }
        if m.type == "track" { parts.append(media.audioCodec?.uppercased() ?? "Audio") }
        return parts.isEmpty ? "Direct" : parts.joined(separator: " · ")
    }
}

// MARK: - Trust self-signed certs
private class InsecureDelegate: NSObject, URLSessionDelegate {
    static let shared = InsecureDelegate()
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
