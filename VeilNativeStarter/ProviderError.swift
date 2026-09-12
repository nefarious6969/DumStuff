import Foundation

enum ProviderError: LocalizedError {
    case missingConfiguration(String)
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let value): return value
        case .badResponse(let status): return "Feed request failed (HTTP \(status))."
        }
    }
}
