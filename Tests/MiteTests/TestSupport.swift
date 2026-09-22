import Foundation
import XCTest
@testable import Mite

/// Fakes the server. Set `responder` per test; every request is recorded.
final class StubURLProtocol: URLProtocol {
    struct RecordedRequest {
        let url: URL
        let method: String
        let body: Data?

        var bodyJSON: [String: Any]? {
            guard let body else { return nil }
            return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        }
    }

    private static let lock = NSLock()
    private static var _responder: ((URLRequest) -> Result<(Int, Data), URLError>)?
    private static var _recorded: [RecordedRequest] = []

    static var responder: ((URLRequest) -> Result<(Int, Data), URLError>)? {
        get { lock.lock(); defer { lock.unlock() }; return _responder }
        set { lock.lock(); _responder = newValue; lock.unlock() }
    }

    static var recorded: [RecordedRequest] {
        lock.lock(); defer { lock.unlock() }; return _recorded
    }

    static func reset() {
        lock.lock()
        _responder = nil
        _recorded = []
        lock.unlock()
    }

    private static func record(_ request: RecordedRequest) {
        lock.lock()
        _recorded.append(request)
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.body(of: request)
        Self.record(RecordedRequest(
            url: request.url!,
            method: request.httpMethod ?? "GET",
            body: body
        ))

        guard let responder = Self.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        switch responder(request) {
        case .success(let (status, data)):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

func makeStubSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
}

/// In-memory identity storage, so tests never touch real UserDefaults.
final class MemoryIdentityStorage: MiteIdentityStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func getItem(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }; return values[key]
    }

    func setItem(_ key: String, _ value: String) {
        lock.lock(); values[key] = value; lock.unlock()
    }

    func removeItem(_ key: String) {
        lock.lock(); values[key] = nil; lock.unlock()
    }
}

func quotaRefusalBody(
    code: String,
    resetsAt: Double? = nil,
    message: String = "Plan limit reached"
) -> Data {
    var quota: [String: Any] = ["limit": 10, "used": 10]
    if let resetsAt { quota["resets_at"] = resetsAt }
    let body: [String: Any] = ["error": message, "code": code, "quota": quota]
    return try! JSONSerialization.data(withJSONObject: body)
}

func makeTestConfig(
    apiKey: String? = "test-key",
    storage: MiteIdentityStorage = MemoryIdentityStorage(),
    enableOfflineQueue: Bool = false,
    identificationOptOut: Bool? = nil,
    onQuotaExceeded: (@Sendable (MiteQuotaRefusal) -> Void)? = nil
) -> MiteConfig {
    MiteConfig(
        apiKey: apiKey,
        identificationOptOut: identificationOptOut,
        enableOfflineQueue: enableOfflineQueue,
        syncIdentityOnStart: false,
        captureUncaughtExceptions: false,
        monitorNetworkState: false,
        identityStorage: storage,
        onQuotaExceeded: onQuotaExceeded
    )
}
