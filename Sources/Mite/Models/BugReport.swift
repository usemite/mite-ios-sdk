import Foundation

/// A local file to upload with a bug report.
public struct MiteAttachment: Sendable {
    public let fileURL: URL
    public let contentType: String?
    public let fileName: String?

    public init(fileURL: URL, contentType: String? = nil, fileName: String? = nil) {
        self.fileURL = fileURL
        self.contentType = contentType
        self.fileName = fileName
    }
}

/// The fields an app fills in to submit a bug report. Identity and device
/// info are added by the SDK.
public struct BugReportPayload: Sendable {
    public var title: String
    public var description: String
    public var stepsToReproduce: String?
    public var expectedBehavior: String?
    public var actualBehavior: String?
    public var appVersion: String?
    public var reporterName: String?
    public var reporterEmail: String?
    public var environment: [String: String]?
    /// Overrides the device info the SDK collects.
    public var deviceInfo: [String: String]?
    public var attachments: [MiteAttachment]?

    public init(
        title: String,
        description: String,
        stepsToReproduce: String? = nil,
        expectedBehavior: String? = nil,
        actualBehavior: String? = nil,
        appVersion: String? = nil,
        reporterName: String? = nil,
        reporterEmail: String? = nil,
        environment: [String: String]? = nil,
        deviceInfo: [String: String]? = nil,
        attachments: [MiteAttachment]? = nil
    ) {
        self.title = title
        self.description = description
        self.stepsToReproduce = stepsToReproduce
        self.expectedBehavior = expectedBehavior
        self.actualBehavior = actualBehavior
        self.appVersion = appVersion
        self.reporterName = reporterName
        self.reporterEmail = reporterEmail
        self.environment = environment
        self.deviceInfo = deviceInfo
        self.attachments = attachments
    }
}

public struct BugReportResponse: Decodable, Sendable {
    public let id: String
    public let status: String
}

/// The outcome of a bug report submission.
///
/// `.success` means the server created a report. When `droppedAttachments`
/// is set, the report exists but some files did not upload.
/// `.refused` means the server created no report. Read `refusal.code` to
/// know why. A refusal is an expected state, so the SDK does not throw it.
public enum SubmitBugResult: Sendable {
    public struct DroppedAttachments: Sendable {
        public let count: Int
        public let refusal: MiteQuotaRefusal
    }

    case success(report: BugReportResponse, droppedAttachments: DroppedAttachments?)
    case refused(MiteQuotaRefusal)
}

/// An attachment reference after upload, as the report endpoint expects it.
struct UploadedAttachment: Codable {
    let storage_id: String
    let file_type: String?
    let file_name: String?
}

/// The exact shape sent to `POST /api/v1/bug-reports`.
struct BugReportWire: Encodable {
    var title: String
    var description: String
    var anonymous_id: String
    var user_identifier: String?
    var reporter_name: String?
    var reporter_email: String?
    var steps_to_reproduce: String?
    var expected_behavior: String?
    var actual_behavior: String?
    var app_version: String?
    var environment: [String: String]?
    var device_info: [String: String]?
    var attachments: [UploadedAttachment]?
}
