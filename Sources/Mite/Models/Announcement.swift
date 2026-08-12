import Foundation

/// An in-app announcement published from the Mite dashboard.
///
/// Announcements are not tied to an app version. Their content and active
/// schedule are controlled remotely, and the API only returns announcements
/// that are currently active.
public struct Announcement: Decodable, Identifiable, Sendable {
    public let id: String
    public let title: String
    /// Markdown body. Content can change server-side at any time.
    public let content: String
    public let platform: ReleasePlatform
    /// Label of the optional action button.
    public let ctaLabel: String?
    /// URL opened by the optional action button.
    public let ctaUrl: String?
    /// Milliseconds since the epoch.
    public let publishedAt: Double?
    /// Milliseconds since the epoch.
    public let updatedAt: Double?
    /// Milliseconds since the epoch.
    public let createdAt: Double
}

struct AnnouncementsResponse: Decodable {
    let announcements: [Announcement]
}
