import Foundation

/// Common error types used across all Archaeopteryx packages
public enum ArchaeopteryxError: Error, Equatable, Sendable {
    /// Resource not found
    case notFound(resource: String)

    /// Unauthorized access
    case unauthorized

    /// Forbidden action
    case forbidden

    /// Validation failed
    case validationFailed(field: String, message: String)

    /// Rate limited
    case rateLimited(retryAfter: TimeInterval)

    /// Internal error with underlying cause
    case internalError(message: String)

    /// Configuration error
    case configurationError(message: String)
}

extension ArchaeopteryxError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notFound(let resource):
            return "Not found: \(resource)"
        case .unauthorized:
            return "Unauthorized"
        case .forbidden:
            return "Forbidden"
        case .validationFailed(let field, let message):
            return "Validation failed for \(field): \(message)"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(retryAfter) seconds"
        case .internalError(let message):
            return "Internal error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}

extension ArchaeopteryxError: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case resource
        case field
        case message
        case retryAfter
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "notFound":
            let resource = try container.decode(String.self, forKey: .resource)
            self = .notFound(resource: resource)
        case "unauthorized":
            self = .unauthorized
        case "forbidden":
            self = .forbidden
        case "validationFailed":
            let field = try container.decode(String.self, forKey: .field)
            let message = try container.decode(String.self, forKey: .message)
            self = .validationFailed(field: field, message: message)
        case "rateLimited":
            let retryAfter = try container.decode(TimeInterval.self, forKey: .retryAfter)
            self = .rateLimited(retryAfter: retryAfter)
        case "internalError":
            let message = try container.decode(String.self, forKey: .message)
            self = .internalError(message: message)
        case "configurationError":
            let message = try container.decode(String.self, forKey: .message)
            self = .configurationError(message: message)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown error type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .notFound(let resource):
            try container.encode("notFound", forKey: .type)
            try container.encode(resource, forKey: .resource)
        case .unauthorized:
            try container.encode("unauthorized", forKey: .type)
        case .forbidden:
            try container.encode("forbidden", forKey: .type)
        case .validationFailed(let field, let message):
            try container.encode("validationFailed", forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encode(message, forKey: .message)
        case .rateLimited(let retryAfter):
            try container.encode("rateLimited", forKey: .type)
            try container.encode(retryAfter, forKey: .retryAfter)
        case .internalError(let message):
            try container.encode("internalError", forKey: .type)
            try container.encode(message, forKey: .message)
        case .configurationError(let message):
            try container.encode("configurationError", forKey: .type)
            try container.encode(message, forKey: .message)
        }
    }
}
