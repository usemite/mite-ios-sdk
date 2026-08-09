import Foundation

/// The Mite SDK client. Create one with `MiteClient(config:)`, or use
/// `Mite.configure(_:)` and `Mite.shared` for an app-wide instance.
public actor MiteClient {
    private let config: MiteConfig
    private let apiClient: APIClient
    private let identityStore: IdentityStore
    private let deviceInfo: [String: String]
    private var offlineQueue: OfflineQueue?

    private var currentAnonymousId: String
    private var currentUserIdentifier: String?
    private var identificationOptOut: Bool

    /// The last report quota refusal. While it is set and not yet past its
    /// reset time, `submitBug` refuses locally instead of sending a request
    /// that cannot succeed. Not persisted, so an app restart costs at most
    /// one wasted request.
    private var reportQuotaRefusal: MiteQuotaRefusal?

    public init(config: MiteConfig, session: URLSession = .shared) {
        self.config = config
        self.apiClient = APIClient(
            baseURL: config.endpoint,
            timeout: config.timeout,
            maxRetries: config.maxRetries,
            apiKey: config.apiKey,
            session: session
        )
        self.identityStore = IdentityStore(
            storage: config.identityStorage ?? UserDefaultsIdentityStorage()
        )
        self.deviceInfo = DeviceInfo.collect()

        // Hydrate identity. Config overrides win over persisted state.
        let persisted = identityStore.load()
        self.currentAnonymousId =
            config.anonymousId ?? persisted?.anonymousId ?? generateAnonymousId()
        self.currentUserIdentifier = persisted?.userIdentifier
        self.identificationOptOut =
            config.identificationOptOut ?? persisted?.identificationOptOut ?? false
        if identificationOptOut {
            self.currentUserIdentifier = nil
        }

        let onQuotaExceeded = config.onQuotaExceeded
        if config.enableOfflineQueue {
            self.offlineQueue = OfflineQueue(apiClient: apiClient) { refusal in
                // A queued report can meet a quota refusal long after the call
                // that created it returned. Report it through the same channel.
                onQuotaExceeded?(refusal)
            }
        }

        identityStore.save(PersistedIdentityState(
            anonymousId: currentAnonymousId,
            userIdentifier: identificationOptOut ? nil : currentUserIdentifier,
            identificationOptOut: identificationOptOut
        ))

        if config.syncIdentityOnStart, config.apiKey != nil {
            Task { [weak self] in
                // Ignore startup identity failures. Later identify calls and
                // bug reports continue to use the latest local identity state.
                try? await self?.syncIdentityState()
            }
        }
    }

    // MARK: - Bug reports

    /// Submits a bug report to the server.
    ///
    /// The result tells you what happened. `.refused` means the account is
    /// over a plan limit and the server made no report. A quota refusal does
    /// not throw, because it is an expected state and not a fault. Network
    /// faults and bad configuration still throw.
    ///
    /// If the request fails with a network fault and the offline queue is
    /// enabled, the report is queued for a later retry. Attachments are not
    /// queued. A quota refusal is never queued and never retried.
    public func submitBug(_ payload: BugReportPayload) async throws -> SubmitBugResult {
        try requireAPIKey("submit bug reports")

        if let gated = activeReportQuotaRefusal() {
            // The account is out of reports and the period has not turned
            // over. Send nothing.
            notifyQuotaExceeded(gated)
            return .refused(gated)
        }

        var uploaded: [UploadedAttachment] = []
        var dropped: SubmitBugResult.DroppedAttachments?

        if let attachments = payload.attachments, !attachments.isEmpty {
            let outcome = try await uploadAttachments(attachments)

            if let refusal = outcome.reportRefusal {
                rememberReportQuotaRefusal(refusal)
                notifyQuotaExceeded(refusal)
                return .refused(refusal)
            }

            if let refusal = outcome.storageRefusal {
                dropped = .init(
                    count: attachments.count - outcome.uploaded.count,
                    refusal: refusal
                )
            }

            uploaded = outcome.uploaded
        }

        let wire = buildBugReportWire(payload, attachments: uploaded.isEmpty ? nil : uploaded)

        do {
            let report: BugReportResponse = try await apiClient.post(
                "/api/v1/bug-reports",
                body: wire
            )
            if let dropped {
                notifyQuotaExceeded(dropped.refusal)
            }
            return .success(report: report, droppedAttachments: dropped)
        } catch {
            if let refusal = QuotaRefusalParser.parse(error) {
                rememberReportQuotaRefusal(refusal)
                notifyQuotaExceeded(refusal)
                return .refused(refusal)
            }

            if let queue = offlineQueue, isNetworkError(error) {
                var queuedWire = wire
                queuedWire.attachments = nil
                if let body = try? JSONEncoder().encode(queuedWire) {
                    await queue.enqueue(path: "/api/v1/bug-reports", body: body)
                }
            }

            throw error
        }
    }

    // MARK: - Identity

    /// Identifies an end user in your application. Uses the current
    /// anonymous identifier automatically.
    @discardableResult
    public func identify(_ payload: IdentifyPayload = IdentifyPayload()) async throws -> IdentifyResponse {
        try requireAPIKey("identify users")

        let wire = buildIdentifyWire(payload)
        let response: IdentifyResponse = try await apiClient.post("/api/v1/identify", body: wire)

        if !identificationOptOut {
            currentUserIdentifier = wire.user_identifier
        }
        persistIdentityState()

        return response
    }

    /// Removes the identified user while keeping the anonymous id stable.
    public func logout() async {
        currentUserIdentifier = nil
        persistIdentityState()

        // Ignore logout sync failures. Local state has already been updated.
        try? await syncIdentityState()
    }

    /// Toggles whether identified data is sent to Mite.
    public func setIdentificationOptOut(_ optedOut: Bool) async {
        identificationOptOut = optedOut
        if optedOut {
            currentUserIdentifier = nil
        }
        persistIdentityState()

        // Ignore preference sync failures. Local privacy state applies.
        try? await syncIdentityState()
    }

    public var anonymousId: String {
        currentAnonymousId
    }

    /// The currently identified end user, when one exists.
    public var userIdentifier: String? {
        currentUserIdentifier
    }

    public var isIdentificationOptedOut: Bool {
        identificationOptOut
    }

    // MARK: - Releases

    /// Fetches published releases for the application.
    public func getReleases(
        platform: ReleasePlatform? = nil,
        limit: Int? = nil
    ) async throws -> [Release] {
        try requireAPIKey("fetch releases")

        var query: [URLQueryItem] = []
        if let platform {
            query.append(URLQueryItem(name: "platform", value: platform.rawValue))
        }
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        let response: ReleasesResponse = try await apiClient.get("/api/v1/releases", query: query)
        return response.releases
    }

    // MARK: - Offline queue

    /// Manually flushes the offline queue.
    public func flushOfflineQueue() async {
        await offlineQueue?.flush()
    }

    /// The number of pending requests in the offline queue.
    public var pendingRequestCount: Int {
        get async {
            await offlineQueue?.pendingCount ?? 0
        }
    }

    /// Stops the offline queue and clears it.
    public func shutdown() async {
        await offlineQueue?.shutdown()
        reportQuotaRefusal = nil
    }

    // MARK: - Attachment upload

    private struct AttachmentUploadOutcome {
        var uploaded: [UploadedAttachment] = []
        /// Set when the account is out of reports. No report can be created.
        var reportRefusal: MiteQuotaRefusal?
        /// Set when the account is out of storage. The report still goes out.
        var storageRefusal: MiteQuotaRefusal?
    }

    private struct UploadURLResponse: Decodable {
        let uploadUrl: String
    }

    private struct UploadResultResponse: Decodable {
        let storageId: String
    }

    /// Uploads every attachment. The upload URL endpoint can refuse with
    /// either quota code, so branch on the code and not on the endpoint.
    private func uploadAttachments(
        _ attachments: [MiteAttachment]
    ) async throws -> AttachmentUploadOutcome {
        var outcome = AttachmentUploadOutcome()

        for attachment in attachments {
            let uploadURL: URL
            do {
                let response: UploadURLResponse = try await apiClient.post("/api/v1/upload-url")
                guard let url = URL(string: response.uploadUrl) else {
                    throw MiteError.invalidResponse
                }
                uploadURL = url
            } catch {
                guard let refusal = QuotaRefusalParser.parse(error) else { throw error }

                if refusal.code == .reportQuotaExceeded {
                    // Out of reports. The bug report would be refused as well,
                    // so stop here rather than send a request that cannot succeed.
                    outcome.reportRefusal = refusal
                    return outcome
                }

                // Out of storage. Storage is a standing total, so the
                // attachments that are left cannot fit either. The report text
                // is the value the customer must not lose, so stop uploading
                // and keep going.
                outcome.storageRefusal = refusal
                return outcome
            }

            let data = try Data(contentsOf: attachment.fileURL)
            let contentType = attachment.contentType ?? "image/jpeg"
            let result: UploadResultResponse = try await apiClient.upload(
                to: uploadURL,
                data: data,
                contentType: contentType
            )

            outcome.uploaded.append(UploadedAttachment(
                storage_id: result.storageId,
                file_type: attachment.contentType,
                file_name: attachment.fileName ?? attachment.fileURL.lastPathComponent
            ))
        }

        return outcome
    }

    // MARK: - Payload building

    private func buildBugReportWire(
        _ payload: BugReportPayload,
        attachments: [UploadedAttachment]?
    ) -> BugReportWire {
        var wire = BugReportWire(
            title: payload.title,
            description: payload.description,
            anonymous_id: currentAnonymousId,
            steps_to_reproduce: payload.stepsToReproduce,
            expected_behavior: payload.expectedBehavior,
            actual_behavior: payload.actualBehavior,
            app_version: payload.appVersion,
            environment: payload.environment,
            attachments: attachments
        )

        if !identificationOptOut {
            wire.user_identifier = currentUserIdentifier
            wire.reporter_name = payload.reporterName
            wire.reporter_email = payload.reporterEmail
            wire.device_info = payload.deviceInfo ?? deviceInfo
        }

        return wire
    }

    private func buildIdentifyWire(_ payload: IdentifyPayload) -> IdentifyWire {
        if identificationOptOut {
            return IdentifyWire(anonymous_id: currentAnonymousId)
        }

        return IdentifyWire(
            anonymous_id: currentAnonymousId,
            user_identifier: payload.userIdentifier ?? currentUserIdentifier,
            email: payload.email,
            name: payload.name,
            app_version: payload.appVersion,
            metadata: payload.metadata,
            device_info: deviceInfo
        )
    }

    // MARK: - Quota gate

    /// Closes the gate, but only when the refusal says when it opens again.
    /// The gate saves a request that cannot succeed. It must never be the
    /// reason a report is lost, so a refusal with no reset time does not
    /// close it.
    private func rememberReportQuotaRefusal(_ refusal: MiteQuotaRefusal) {
        guard refusal.code == .reportQuotaExceeded, refusal.quota.resetsAt != nil else {
            return
        }
        reportQuotaRefusal = refusal
    }

    /// The report quota refusal that is still in force, if any. The gate
    /// opens again once the billing period turns over.
    private func activeReportQuotaRefusal() -> MiteQuotaRefusal? {
        guard let refusal = reportQuotaRefusal else { return nil }

        guard
            let resetsAt = refusal.quota.resetsAt,
            Date().timeIntervalSince1970 * 1000 < resetsAt
        else {
            reportQuotaRefusal = nil
            return nil
        }

        return refusal
    }

    private func notifyQuotaExceeded(_ refusal: MiteQuotaRefusal) {
        config.onQuotaExceeded?(refusal)
    }

    // MARK: - Helpers

    private func isNetworkError(_ error: Error) -> Bool {
        if case MiteError.network = error { return true }
        return false
    }

    private func requireAPIKey(_ action: String) throws {
        guard config.apiKey != nil else {
            throw MiteError.missingAPIKey(action: action)
        }
    }

    private func persistIdentityState() {
        identityStore.save(PersistedIdentityState(
            anonymousId: currentAnonymousId,
            userIdentifier: identificationOptOut ? nil : currentUserIdentifier,
            identificationOptOut: identificationOptOut
        ))
    }

    private func syncIdentityState() async throws {
        guard config.apiKey != nil else { return }
        let wire = buildIdentifyWire(IdentifyPayload())
        let _: IdentifyResponse = try await apiClient.post("/api/v1/identify", body: wire)
    }
}
