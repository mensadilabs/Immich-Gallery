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
        
        // Try parsing with fractional seconds first (e.g., .123Z)
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: isoString)
        
        // Fallback: Try parsing without fractional seconds (your specific case)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: isoString)
        }

        guard let validDate = date else {
            return isoString
        }

        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = format

        let dateString = formatter.string(from: validDate)
        let abbreviation = timeZone.abbreviation(for: validDate) ?? ""

        return abbreviation.isEmpty
            ? dateString
            : "\(dateString) \(abbreviation)"
    }
}
