import Foundation

/// URLSession wrapper for the Mite backend. JSON in and out, Bearer auth,
/// retry with exponential backoff for transient faults only.
final class APIClient: @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let timeout: TimeInterval
    private let maxRetries: Int
    private let apiKey: String?

    init(
        baseURL: URL,
        timeout: TimeInterval,
        maxRetries: Int,
        apiKey: String?,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = max(0, maxRetries)
        self.apiKey = apiKey
        self.session = session
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let data = try await send(method: "GET", path: path, query: query, body: nil)
        return try decode(data)
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let data = try await send(method: "POST", path: path, body: try encode(body))
        return try decode(data)
    }

    func post<T: Decodable>(_ path: String) async throws -> T {
        let data = try await send(method: "POST", path: path, body: nil)
        return try decode(data)
    }

    /// Sends pre-encoded JSON. Used by the offline queue, which stores
    /// request bodies as raw data.
    func postRaw(_ path: String, bodyData: Data) async throws {
        _ = try await send(method: "POST", path: path, body: bodyData)
    }

    /// Uploads raw file bytes to an absolute URL (attachment upload target).
    /// Not retried: an upload URL is single-use.
    func upload<T: Decodable>(to url: URL, data: Data, contentType: String) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (body, response) = try await execute(request)
        guard (200..<300).contains(response.statusCode) else {
            throw MiteError.server(status: response.statusCode, body: body)
        }
        return try decode(body)
    }

    // MARK: - Core

    private func send(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Data?
    ) async throws -> Data {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else {
            throw MiteError.invalidResponse
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        var attempt = 0
        while true {
            do {
                let (data, response) = try await execute(request)

                if (200..<300).contains(response.statusCode) {
                    return data
                }

                // A 4xx is not transient. A retry gives the same answer, so it
                // only costs battery and delays the error the developer sees.
                // This covers the 402 plan quota refusals.
                if response.statusCode >= 500, attempt < maxRetries {
                    attempt += 1
                    try await backoff(attempt)
                    continue
                }

                throw MiteError.server(status: response.statusCode, body: data)
            } catch let error as URLError {
                if attempt < maxRetries {
                    attempt += 1
                    try await backoff(attempt)
                    continue
                }
                throw MiteError.network(error)
            }
        }
    }

    private func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MiteError.invalidResponse
        }
        return (data, http)
    }

    private func backoff(_ attempt: Int) async throws {
        let milliseconds = min(1000 * pow(2, Double(attempt)), 10000)
        try await Task.sleep(nanoseconds: UInt64(milliseconds * 1_000_000))
    }

    private func encode(_ value: some Encodable) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MiteError.decoding(error)
        }
    }
}
