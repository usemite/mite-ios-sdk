import Combine
import Foundation

/// Main-actor state machine for presenting the latest active announcement.
///
/// Use this directly for a custom interface, or pass it to
/// `View.miteAnnouncementPopup(controller:dismissLabel:onDismiss:onCTAPress:)`.
/// The newest announcement is presented automatically once per device. Older
/// unseen announcements are deliberately not presented as a backlog.
@MainActor
public final class MiteAnnouncementController: ObservableObject {
    /// The latest active announcement returned by the server.
    @Published public private(set) var announcement: Announcement?
    /// The announcement currently selected for presentation.
    @Published public private(set) var presentedAnnouncement: Announcement?
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?

    public var isPresented: Bool {
        presentedAnnouncement != nil
    }

    private let client: MiteClient?
    private let platform: ReleasePlatform?
    private let limit: Int?
    private let enabled: Bool
    private var hasLoaded = false
    private var seenIDs: Set<String> = []
    private var pendingDismissal: Announcement?

    /// Creates an announcement controller.
    ///
    /// - Parameters:
    ///   - client: Client to use. When nil, the currently configured shared
    ///     client is resolved each time a request is made.
    ///   - platform: Platform filter. Defaults to iOS.
    ///   - limit: Maximum announcements fetched. Only the newest is presented.
    ///   - enabled: Whether the newest unseen announcement is presented
    ///     automatically. `show()` still works when this is false.
    public init(
        client: MiteClient? = nil,
        platform: ReleasePlatform? = .ios,
        limit: Int? = 10,
        enabled: Bool = true
    ) {
        self.client = client
        self.platform = platform
        self.limit = limit
        self.enabled = enabled
    }

    /// Loads announcements once and performs automatic show-once presentation.
    public func load() async {
        guard !hasLoaded, enabled else { return }
        await refresh(presentIfUnseen: true)
    }

    /// Refetches announcements and optionally presents the newest unseen one.
    public func refresh() async {
        await refresh(presentIfUnseen: enabled)
    }

    /// Presents the latest active announcement even if it was already seen.
    /// If announcements have not been loaded yet, this first fetches them.
    public func show() {
        if let announcement {
            pendingDismissal = nil
            presentedAnnouncement = announcement
        } else {
            Task { await fetchAndShowLatest() }
        }
    }

    /// Hides the current announcement and records it as seen on this device.
    /// Returns true only for the call that performs a dismissal.
    @discardableResult
    public func dismiss() async -> Bool {
        prepareForDismissal()
        guard let dismissed = pendingDismissal else { return false }
        pendingDismissal = nil

        guard let client = resolvedClient else { return true }
        await client.markAnnouncementSeen(dismissed.id)
        seenIDs.insert(dismissed.id)
        return true
    }

    /// Clears the per-device seen list. The current announcement is not
    /// presented immediately; call `show()` or `refresh()` when desired.
    public func clearSeenAnnouncements() async {
        guard let client = resolvedClient else { return }
        await client.clearSeenAnnouncements()
        seenIDs = []
    }

    /// Called by the SwiftUI presentation binding before its dismissal
    /// callback. Public custom interfaces should normally call `dismiss()`.
    func prepareForDismissal() {
        guard let presentedAnnouncement else { return }
        pendingDismissal = presentedAnnouncement
        self.presentedAnnouncement = nil
    }

    private var resolvedClient: MiteClient? {
        client ?? Mite.sharedIfConfigured
    }

    private func fetchAndShowLatest() async {
        await refresh(presentIfUnseen: false)
        guard let announcement else { return }
        pendingDismissal = nil
        presentedAnnouncement = announcement
    }

    private func refresh(presentIfUnseen: Bool) async {
        guard !isLoading, let client = resolvedClient else { return }
        isLoading = true
        error = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            async let fetchedAnnouncements = client.getAnnouncements(
                platform: platform,
                limit: limit
            )
            async let fetchedSeenIDs = client.getSeenAnnouncementIds()

            let (announcements, storedSeenIDs) = try await (
                fetchedAnnouncements,
                fetchedSeenIDs
            )
            guard !Task.isCancelled else { return }

            seenIDs = Set(storedSeenIDs)
            announcement = announcements.first

            if
                presentIfUnseen,
                let announcement,
                !seenIDs.contains(announcement.id)
            {
                pendingDismissal = nil
                presentedAnnouncement = announcement
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = error
        }
    }
}
