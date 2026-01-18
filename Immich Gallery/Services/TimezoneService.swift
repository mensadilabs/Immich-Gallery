import Foundation

struct TimeZoneService {

    static let all: [String] = [
        "Pacific/Honolulu",
        "America/Anchorage",
        "America/Los_Angeles",
        "America/Denver",
        "America/Chicago",
        "America/New_York",
        "America/Sao_Paulo",
        "Europe/London",
        "Europe/Paris",
        "Europe/Moscow",
        "Africa/Cairo",
        "Africa/Johannesburg",
        "Asia/Dubai",
        "Asia/Kolkata",
        "Asia/Shanghai",
        "Asia/Tokyo",
        "Australia/Sydney",
        "Pacific/Auckland"
    ]
    
    static var timeZones: [TimeZone] {
        all.compactMap { TimeZone(identifier: $0) }
    }

    static func convertToLocalTime(
        isoString: String,
        timeZoneIdentifier: String,
        format: String = "yyyy-MM-dd HH:mm:ss"
    ) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = isoFormatter.date(from: isoString) else {
            return isoString
        }

        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = format

        let dateString = formatter.string(from: date)
        let abbreviation = timeZone.abbreviation(for: date) ?? ""

        return abbreviation.isEmpty
            ? dateString
            : "\(dateString) \(abbreviation)"
    }
}

