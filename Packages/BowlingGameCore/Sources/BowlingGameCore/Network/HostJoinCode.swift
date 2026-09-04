import Foundation

/// Payload encoded in the host QR code so a phone can skip Bonjour browsing.
public struct HostJoinCode: Codable, Sendable, Equatable {
    public static let urlScheme = "mabowl"
    public static let urlHost = "join"

    public var serviceName: String
    public var port: UInt16
    public var addresses: [String]
    public var sessionID: UUID

    public init(serviceName: String, port: UInt16, addresses: [String], sessionID: UUID) {
        self.serviceName = serviceName
        self.port = port
        self.addresses = addresses
        self.sessionID = sessionID
    }

    public var urlString: String {
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = Self.urlHost
        components.queryItems = [
            URLQueryItem(name: "n", value: serviceName),
            URLQueryItem(name: "p", value: String(port)),
            URLQueryItem(name: "a", value: addresses.joined(separator: ",")),
            URLQueryItem(name: "s", value: sessionID.uuidString),
        ]
        return components.string ?? ""
    }

    public static func parse(_ raw: String) -> HostJoinCode? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme == urlScheme,
              url.host == urlHost,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else {
            return nil
        }

        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }

        guard let serviceName = value("n"), !serviceName.isEmpty,
              let portValue = value("p"), let port = UInt16(portValue), port > 0,
              let sessionValue = value("s"), let sessionID = UUID(uuidString: sessionValue)
        else {
            return nil
        }

        let addresses = (value("a") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return HostJoinCode(
            serviceName: serviceName,
            port: port,
            addresses: addresses,
            sessionID: sessionID
        )
    }
}
