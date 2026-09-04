import Foundation

public enum BowlingProtocolError: Error, Sendable, Equatable {
    case payloadTooLarge(Int)
    case decodingFailed
}

/// Length-prefixed JSON frames: 4-byte big-endian size, then a `NetworkMessage` payload.
public struct MessageAssembler: Sendable {
    public static let maxPayloadSize = 256_000

    private var buffer = Data()

    public init() {}

    public static func encode(_ message: NetworkMessage) throws -> Data {
        try JSONEncoder().encode(message)
    }

    public static func frame(_ message: NetworkMessage) throws -> Data {
        let payload = try encode(message)
        guard payload.count <= maxPayloadSize else {
            throw BowlingProtocolError.payloadTooLarge(payload.count)
        }
        var length = UInt32(payload.count).bigEndian
        var data = Data(bytes: &length, count: 4)
        data.append(payload)
        return data
    }

    public mutating func append(_ data: Data) throws -> [NetworkMessage] {
        buffer.append(data)
        var messages: [NetworkMessage] = []

        while buffer.count >= 4 {
            let length = buffer.prefix(4).withUnsafeBytes { raw -> Int in
                Int(UInt32(bigEndian: raw.loadUnaligned(as: UInt32.self)))
            }
            guard length > 0, length <= Self.maxPayloadSize else {
                buffer.removeAll()
                throw BowlingProtocolError.payloadTooLarge(length)
            }
            guard buffer.count >= 4 + length else { break }

            let payload = buffer.subdata(in: 4..<(4 + length))
            buffer.removeSubrange(0..<(4 + length))
            do {
                messages.append(try JSONDecoder().decode(NetworkMessage.self, from: payload))
            } catch {
                throw BowlingProtocolError.decodingFailed
            }
        }

        return messages
    }
}
