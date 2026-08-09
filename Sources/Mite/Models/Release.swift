import Foundation

public enum ReleasePlatform: String, Codable, Sendable {
    case ios
    case android
    case all
}

public struct Release: Decodable, Sendable {
    public let id: String
    public let version: String
    public let versionCode: Int
    public let platform: ReleasePlatform
    public let notes: String?
    /// Milliseconds since the epoch.
    public let releasedAt: Double?
    /// Milliseconds since the epoch.
    public let createdAt: Double
}

struct ReleasesResponse: Decodable {
    let releases: [Release]
}
