import Foundation

/// Controls how human-readable dates are rendered in formatted entry output.
public enum DSStoreDateDisplay: Sendable {
    /// Render dates in the current system time zone.
    case local
    /// Render dates in UTC.
    case utc
}
