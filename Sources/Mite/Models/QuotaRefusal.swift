import Foundation

/// Plan limits the server enforces. `reportQuotaExceeded` means the account
/// has used every report in the current billing period. `storageQuotaExceeded`
/// means the account has used all of its attachment storage.
public enum MiteQuotaCode: String, Codable, Sendable {
    case reportQuotaExceeded = "REPORT_QUOTA_EXCEEDED"
    case storageQuotaExceeded = "STORAGE_QUOTA_EXCEEDED"
}

public struct MiteQuota: Sendable, Equatable {
    public let limit: Int
    public let used: Int
    /// Milliseconds since the epoch. Sent with `reportQuotaExceeded` only.
    /// Attachment storage is a standing total and does not reset.
    public let resetsAt: Double?

    public init(limit: Int, used: Int, resetsAt: Double? = nil) {
        self.limit = limit
        self.used = used
        self.resetsAt = resetsAt
    }
}

public struct MiteQuotaRefusal: Sendable, Equatable {
    public let code: MiteQuotaCode
    /// The message the server sent. Written for developers, not end users.
    public let message: String
    public let quota: MiteQuota

    public init(code: MiteQuotaCode, message: String, quota: MiteQuota) {
        self.code = code
        self.message = message
        self.quota = quota
    }
}

/// Turns a failed request into a plan quota refusal, when that is what it is.
///
/// The server answers a quota refusal with HTTP 402 and one of the codes in
/// `MiteQuotaCode`. Anything else returns `nil` and stays an ordinary error.
/// This is the only place in the SDK that reads the refusal wire format.
enum QuotaRefusalParser {
    private struct WireBody: Decodable {
        struct WireQuota: Decodable {
            let limit: Int?
            let used: Int?
            let resets_at: Double?
        }
        let error: String?
        let code: String?
        let quota: WireQuota?
    }

    private static let defaultMessage = "This account has reached a plan limit."

    static func parse(_ error: Error) -> MiteQuotaRefusal? {
        guard case let MiteError.server(status, body) = error, status == 402 else {
            return nil
        }
        return parse(body: body)
    }

    static func parse(body: Data) -> MiteQuotaRefusal? {
        guard
            let wire = try? JSONDecoder().decode(WireBody.self, from: body),
            let rawCode = wire.code,
            let code = MiteQuotaCode(rawValue: rawCode)
        else {
            return nil
        }

        // Only the report code carries a reset time. Storage is a standing total.
        let quota = MiteQuota(
            limit: wire.quota?.limit ?? 0,
            used: wire.quota?.used ?? 0,
            resetsAt: wire.quota?.resets_at
        )

        return MiteQuotaRefusal(
            code: code,
            message: wire.error ?? defaultMessage,
            quota: quota
        )
    }
}
