import Foundation

/// Date formatting utilities for Mastodon API compatibility
public extension ISO8601DateFormatter {
    /// Mastodon-compatible ISO8601 date formatter with fractional seconds
    /// Formats dates as: "2025-01-15T10:00:00.000Z"
    static var mastodonFormat: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

/// Custom date encoding strategy for Mastodon API compatibility
public extension JSONEncoder.DateEncodingStrategy {
    /// Encode dates in Mastodon-compatible ISO8601 format with milliseconds
    /// Uses a custom strategy since ISO8601DateFormatter doesn't conform to DateFormatter
    static var mastodonISO8601: JSONEncoder.DateEncodingStrategy {
        return .custom { date, encoder in
            let formatter = ISO8601DateFormatter.mastodonFormat
            let dateString = formatter.string(from: date)
            var container = encoder.singleValueContainer()
            try container.encode(dateString)
        }
    }
}

/// Custom date decoding strategy for Mastodon API compatibility
public extension JSONDecoder.DateDecodingStrategy {
    /// Decode dates from Mastodon-compatible ISO8601 format
    /// Uses a custom strategy since ISO8601DateFormatter doesn't conform to DateFormatter
    static var mastodonISO8601: JSONDecoder.DateDecodingStrategy {
        return .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatter = ISO8601DateFormatter.mastodonFormat
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Fallback to standard ISO8601 without fractional seconds
            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(dateString)"
            )
        }
    }
}
