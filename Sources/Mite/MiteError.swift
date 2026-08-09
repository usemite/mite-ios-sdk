import Foundation

/// Faults the SDK throws. Plan quota refusals are not errors; they are
/// returned as values (`SubmitBugResult.refused`).
public enum MiteError: Error {
    /// The call needs an API key and `MiteConfig.apiKey` is nil.
    case missingAPIKey(action: String)
    /// The request never reached the server, or the connection dropped.
    case network(URLError)
    /// The server answered with a non-2xx status that is not a quota refusal.
    case server(status: Int, body: Data)
    /// The response was not an HTTP response.
    case invalidResponse
    /// The response body did not decode into the expected shape.
    case decoding(Error)
}

extension MiteError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let action):
            return "[Mite] API key is required to \(action). Provide apiKey in MiteConfig."
        case .network(let error):
            return "[Mite] Network error: \(error.localizedDescription)"
        case .server(let status, _):
            return "[Mite] Server error: HTTP \(status)"
        case .invalidResponse:
            return "[Mite] Invalid response"
        case .decoding(let error):
            return "[Mite] Failed to decode response: \(error.localizedDescription)"
        }
    }
}
