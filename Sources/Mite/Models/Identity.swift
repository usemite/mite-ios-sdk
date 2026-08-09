import Foundation

/// The fields an app can send when it identifies an end user.
public struct IdentifyPayload: Sendable {
    public var userIdentifier: String?
    public var email: String?
    public var name: String?
    public var appVersion: String?
    public var metadata: [String: String]?

    public init(
        userIdentifier: String? = nil,
        email: String? = nil,
        name: String? = nil,
        appVersion: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.userIdentifier = userIdentifier
        self.email = email
        self.name = name
        self.appVersion = appVersion
        self.metadata = metadata
    }
}

public struct IdentifyResponse: Decodable, Sendable {
    public let id: String
    public let created: Bool
}

/// The exact shape sent to `POST /api/v1/identify`.
struct IdentifyWire: Encodable {
    var anonymous_id: String
    var user_identifier: String?
    var email: String?
    var name: String?
    var app_version: String?
    var metadata: [String: String]?
    var device_info: [String: String]?
}
