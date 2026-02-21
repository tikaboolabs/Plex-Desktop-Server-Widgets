import Foundation

final class PlexConfig {
    static let shared = PlexConfig()
    private let defaults = UserDefaults.standard

    var serverUrl: String {
        get {
            let raw = defaults.string(forKey: "plexServerUrl") ?? "http://localhost:32400"
            return Self.normalizeUrl(raw)
        }
        set { defaults.set(newValue, forKey: "plexServerUrl") }
    }

    var token: String {
        get { defaults.string(forKey: "plexToken") ?? "" }
        set { defaults.set(newValue, forKey: "plexToken") }
    }

    var isConfigured: Bool { !token.isEmpty }

    /// Ensure URL always has a scheme and no trailing slash
    static func normalizeUrl(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "http://" + url
        }
        while url.hasSuffix("/") { url.removeLast() }
        return url
    }
}
