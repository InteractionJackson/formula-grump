import Foundation

// MARK: - Packet Validation Utilities
class PacketValidator {
    
    static func validatePacket(_ data: Data) -> PacketValidationResult {
        // Check minimum size
        guard data.count >= PacketSizes.header else {
            return .invalidSize(expected: PacketSizes.header, actual: data.count)
        }
        
        // Parse header for validation
        let packetFormat = readUInt16(from: data, at: 0)
        let packetId = data[6]
        
        // Validate format
        guard packetFormat == 2024 else {
            return .invalidFormat(packetFormat)
        }
        
        // Validate packet size for known types
        if let expectedSize = PacketSizes.expectedSizes[packetId] {
            guard data.count == expectedSize else {
                return .invalidSize(expected: expectedSize, actual: data.count)
            }
        }
        
        return .valid
    }
    
    static func logValidationError(_ result: PacketValidationResult, packetId: UInt8) {
        switch result {
        case .valid:
            break
        case .invalidFormat(let format):
            print("⚠️ Invalid packet format: \(format), expected 2024")
        case .invalidSize(let expected, let actual):
            print("⚠️ Size mismatch for packet \(packetId): got \(actual), expected \(expected)")
        case .unknownPacketType(let id):
            print("⚠️ Unknown packet type: \(id)")
        }
    }
}

// MARK: - Helper Functions
func readUInt16(from data: Data, at offset: Int) -> UInt16 {
    guard offset + 1 < data.count else { return 0 }
    return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
}

func readUInt32(from data: Data, at offset: Int) -> UInt32 {
    guard offset + 3 < data.count else { return 0 }
    return UInt32(data[offset]) | 
           (UInt32(data[offset + 1]) << 8) |
           (UInt32(data[offset + 2]) << 16) |
           (UInt32(data[offset + 3]) << 24)
}

func readUInt64(from data: Data, at offset: Int) -> UInt64 {
    guard offset + 7 < data.count else { return 0 }
    let low = UInt64(readUInt32(from: data, at: offset))
    let high = UInt64(readUInt32(from: data, at: offset + 4))
    return low | (high << 32)
}

func readFloat(from data: Data, at offset: Int) -> Float {
    guard offset + 3 < data.count else { return 0.0 }
    let bits = readUInt32(from: data, at: offset)
    return Float(bitPattern: bits)
}
