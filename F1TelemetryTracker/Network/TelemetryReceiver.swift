import Foundation
import Network
import Combine

class TelemetryReceiver: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastPacketTime: Date?
    @Published var packetsReceived: Int = 0
    
    // Packet type counters for debugging
    private var packetTypeCounts: [UInt8: Int] = [:]
    private var lastStatsTime = Date()
    
    // Current telemetry data
    @Published var currentTelemetry: CarTelemetryData?
    @Published var currentStatus: CarStatusData?
    @Published var currentLapData: LapData?
    @Published var sessionData: PacketSessionData?
    
    private var listener: NWListener?
    private let port: UInt16
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(Error)
        
        static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected),
                 (.connecting, .connecting),
                 (.connected, .connected):
                return true
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }
    
    init(port: UInt16 = 20777) {
        self.port = port
    }
    
    func startReceiving() {
        guard listener == nil else { return }
        
        print("🚀 Starting UDP telemetry receiver on port \(port)")
        connectionStatus = .connecting
        
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            parameters.allowFastOpen = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.newConnectionHandler = { [weak self] connection in
                print("🔗 New UDP connection received")
                self?.handleNewConnection(connection)
            }
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.connectionStatus = .connected
                        print("✅ UDP listener ready on port \(self?.port ?? 0)")
                        print("📡 Waiting for F1 24 telemetry data...")
                    case .failed(let error):
                        self?.connectionStatus = .failed(error)
                        print("❌ UDP listener failed: \(error)")
                    case .cancelled:
                        self?.connectionStatus = .disconnected
                        print("🔌 UDP listener cancelled")
                    case .waiting(let error):
                        print("⏳ UDP listener waiting: \(error)")
                    default:
                        print("🔄 UDP listener state: \(state)")
                        break
                    }
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            
        } catch {
            connectionStatus = .failed(error)
            print("❌ Failed to create UDP listener: \(error)")
        }
    }
    
    func stopReceiving() {
        listener?.cancel()
        listener = nil
        connectionStatus = .disconnected
        print("🔌 UDP listener stopped")
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveData(from: connection)
    }
    
    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, isComplete, error in
            
            if let error = error {
                print("❌ UDP receive error: \(error)")
                return
            }
            
            if let data = data, !data.isEmpty {
                print("📦 Received UDP packet: \(data.count) bytes")
                
                // Log packet details for debugging
                if data.count < 100 {
                    let hexString = data.map { String(format: "%02x", $0) }.joined(separator: " ")
                    print("🔍 Small packet data: \(hexString)")
                }
                
                self?.processPacket(data)
                
                DispatchQueue.main.async {
                    self?.packetsReceived += 1
                    self?.lastPacketTime = Date()
                }
            }
            
            if !isComplete {
                self?.receiveData(from: connection)
            }
        }
    }
    
    private func processPacket(_ data: Data) {
        guard data.count >= 30 else { // Minimum header size
            print("⚠️ Packet too small for F1 telemetry: \(data.count) bytes (need at least 30)")
            
            // Try to decode the packet format from small packets
            if data.count >= 2 {
                let format = readUInt16(from: data, at: 0)
                print("   Packet format detected: \(format)")
                if format == 2024 {
                    print("   ✅ This IS F1 24 data, but packet is truncated or different type")
                }
            }
            return
        }
        
        // Parse header
        guard let header = parseHeader(from: data) else {
            print("⚠️ Failed to parse packet header")
            return
        }
        
        // Validate packet format for F1 24
        guard header.packetFormat == 2024 else {
            print("⚠️ Invalid packet format: \(header.packetFormat), expected 2024")
            return
        }
        
        print("📋 F1 24 packet received: Type=\(header.packetId), Size=\(data.count) bytes, Player=\(header.playerCarIndex)")
        
        // Special debug for Type 6 packets
        if header.packetId == 6 {
            print("🚨 TYPE 6 PACKET DETECTED! Size: \(data.count) bytes")
            print("   🔍 This is the packet we need for dashboard data!")
        }
        
        // Debug ALL packet types and sizes to see what we're actually getting
        print("   📏 Packet size: \(data.count) bytes")
        
        // Process based on packet type
        if let packetType = PacketType(rawValue: header.packetId) {
            print("   Packet type: \(packetType)")
            
            // Log packet frequency for debugging
            DispatchQueue.main.async {
                self.lastPacketTime = Date()
            }
            
            // Track packet types
            packetTypeCounts[header.packetId] = (packetTypeCounts[header.packetId] ?? 0) + 1
            
            // Print stats every 5 seconds
            let now = Date()
            if now.timeIntervalSince(lastStatsTime) >= 5.0 {
                print("📊 Packet stats (last 5s): \(packetTypeCounts)")
                print("   🎯 Looking for Type 6 (carTelemetry) - this is what we need for dashboard!")
                print("   📊 Current types: \(packetTypeCounts.keys.sorted().map { "Type \($0)" }.joined(separator: ", "))")
                
                if !packetTypeCounts.keys.contains(6) {
                    print("   🚨 NO TYPE 6 PACKETS! Try these F1 24 troubleshooting steps:")
                    print("      1. Settings → Telemetry → UDP Telemetry Output = ON")
                    print("      2. Settings → Telemetry → UDP Broadcast Mode = OFF (CRITICAL!)")
                    print("      3. Settings → Telemetry → UDP Send Rate = 20Hz (try this first)")
                    print("      4. Try Practice Session instead of Time Trial")
                    print("      5. Make sure you're actively driving (not in garage/menus)")
                    print("      6. RESTART F1 24 after changing telemetry settings")
                }
                
                packetTypeCounts.removeAll()
                lastStatsTime = now
            }
            
            switch packetType {
            case .carTelemetry:
                print("🏎️ *** CAR TELEMETRY PACKET RECEIVED! *** This is what we need!")
                parseCarTelemetryPacket(data, header: header)
            case .carStatus:
                print("⚡ Processing car status packet...")
                parseCarStatusPacket(data, header: header)
            case .lapData:
                print("🏁 Processing lap data packet...")
                parseLapDataPacket(data, header: header)
            case .session:
                print("🏟️ Processing session packet...")
                parseSessionPacket(data, header: header)
            case .event:
                print("🎯 Processing event packet...")
                parseEventPacket(data, header: header)
            case .sessionHistory:
                print("📊 Processing session history packet...")
                print("   📈 Session history contains lap and sector data")
                parseSessionHistoryPacket(data, header: header)
            case .carDamage:
                print("🔧 Processing car damage packet...")
                print("   💡 Car damage packets confirm we're actively racing!")
                print("   🚨 But we still need Type 6 (carTelemetry) for dashboard data!")
                parseCarDamagePacket(data, header: header)
            default:
                print("ℹ️ Ignoring packet type: \(packetType)")
                print("   🚨 MISSING TYPE 6 (carTelemetry) - Check F1 24 telemetry settings!")
                break
            }
        } else {
            print("❓ Unknown packet type: \(header.packetId)")
        }
    }
    
    private func parseHeader(from data: Data) -> PacketHeader? {
        guard data.count >= 30 else { return nil }
        
        var offset = 0
        
        let packetFormat = readUInt16(from: data, at: offset); offset += 2
        let gameYear = data[offset]; offset += 1
        let gameMajorVersion = data[offset]; offset += 1
        let gameMinorVersion = data[offset]; offset += 1
        let packetVersion = data[offset]; offset += 1
        let packetId = data[offset]; offset += 1
        let sessionUID = readUInt64(from: data, at: offset); offset += 8
        let sessionTime = readFloat(from: data, at: offset); offset += 4
        let frameIdentifier = readUInt32(from: data, at: offset); offset += 4
        let overallFrameIdentifier = readUInt32(from: data, at: offset); offset += 4
        let playerCarIndex = data[offset]; offset += 1
        let secondaryPlayerCarIndex = data[offset]; offset += 1
        
        return PacketHeader(
            packetFormat: packetFormat,
            gameYear: gameYear,
            gameMajorVersion: gameMajorVersion,
            gameMinorVersion: gameMinorVersion,
            packetVersion: packetVersion,
            packetId: packetId,
            sessionUID: sessionUID,
            sessionTime: sessionTime,
            frameIdentifier: frameIdentifier,
            overallFrameIdentifier: overallFrameIdentifier,
            playerCarIndex: playerCarIndex,
            secondaryPlayerCarIndex: secondaryPlayerCarIndex
        )
    }
    
    private func parseCarTelemetryPacket(_ data: Data, header: PacketHeader) {
        // Car telemetry packet structure for F1 24:
        // Header (30 bytes) + 22 cars * 60 bytes per car + 3 additional bytes = 1353 bytes
        // BUT F1 24 might send different sizes, so let's be very flexible
        
        let expectedCarDataSize = 60
        let headerSize = 30
        let carsCount = 22
        let additionalBytes = 3  // mfdPanelIndex, mfdPanelIndexSecondaryPlayer, suggestedGear
        
        let expectedExactSize = headerSize + (carsCount * expectedCarDataSize) + additionalBytes  // 1353
        let minAcceptableSize = headerSize + (carsCount * expectedCarDataSize)  // 1350 - without additional bytes
        
        print("🔍 Car telemetry packet analysis:")
        print("   📏 Received size: \(data.count) bytes")
        print("   📐 Expected exact: \(expectedExactSize) bytes")
        print("   📉 Minimum acceptable: \(minAcceptableSize) bytes")
        print("   🎯 THIS IS THE TYPE 6 PACKET WE'VE BEEN LOOKING FOR!")
        
        // TEMPORARY DEBUG: Accept ANY size Type 6 packet to see if they're being sent
        if data.count < minAcceptableSize {
            print("⚠️ Car telemetry packet smaller than expected:")
            print("   📏 Got \(data.count) bytes, expected min \(minAcceptableSize)")
            print("   🧪 PROCEEDING ANYWAY for debugging - this might crash!")
            print("   💡 If this works, F1 24 is sending smaller Type 6 packets than expected")
        }
        
        if data.count == expectedExactSize {
            print("   ✅ Perfect size match!")
        } else if data.count >= minAcceptableSize {
            print("   ⚠️ Size variation: proceeding anyway (got \(data.count), expected \(expectedExactSize))")
        }
        
        // Parse player car data
        let playerIndex = Int(header.playerCarIndex)
        guard playerIndex < 22 else {
            print("⚠️ Invalid player car index: \(playerIndex)")
            return
        }
        
        let carDataOffset = 30 + (playerIndex * expectedCarDataSize)
        
        if let playerTelemetry = parseCarTelemetryData(from: data, at: carDataOffset) {
            DispatchQueue.main.async {
                self.currentTelemetry = playerTelemetry
                print("🏎️ Telemetry: Speed=\(playerTelemetry.speed)km/h, RPM=\(playerTelemetry.engineRPM), Gear=\(playerTelemetry.gear)")
                let safeThrottle = max(0, min(100, Int((playerTelemetry.throttle * 100).isFinite ? playerTelemetry.throttle * 100 : 0)))
                let safeBrake = max(0, min(100, Int((playerTelemetry.brake * 100).isFinite ? playerTelemetry.brake * 100 : 0)))
                print("   Inputs: Throttle=\(safeThrottle)%, Brake=\(safeBrake)%, DRS=\(playerTelemetry.drs > 0 ? "ON" : "OFF")")
            }
        }
    }
    
    private func parseCarTelemetryData(from data: Data, at offset: Int) -> CarTelemetryData? {
        guard offset + 60 <= data.count else { return nil }
        
        var pos = offset
        
        let speed = readUInt16(from: data, at: pos); pos += 2
        let throttle = readFloat(from: data, at: pos); pos += 4
        let steer = readFloat(from: data, at: pos); pos += 4
        let brake = readFloat(from: data, at: pos); pos += 4
        let clutch = data[pos]; pos += 1
        let gear = Int8(bitPattern: data[pos]); pos += 1
        let engineRPM = readUInt16(from: data, at: pos); pos += 2
        let drs = data[pos]; pos += 1
        let revLightsPercent = data[pos]; pos += 1
        let revLightsBitValue = readUInt16(from: data, at: pos); pos += 2
        
        // Brake temperatures (4 * 2 bytes)
        var brakesTemperature: [UInt16] = []
        for _ in 0..<4 {
            brakesTemperature.append(readUInt16(from: data, at: pos))
            pos += 2
        }
        
        // Tyre surface temperatures (4 * 1 byte)
        var tyresSurfaceTemperature: [UInt8] = []
        for _ in 0..<4 {
            tyresSurfaceTemperature.append(data[pos])
            pos += 1
        }
        
        // Tyre inner temperatures (4 * 1 byte)
        var tyresInnerTemperature: [UInt8] = []
        for _ in 0..<4 {
            tyresInnerTemperature.append(data[pos])
            pos += 1
        }
        
        let engineTemperature = readUInt16(from: data, at: pos); pos += 2
        
        // Tyre pressures (4 * 4 bytes)
        var tyresPressure: [Float] = []
        for _ in 0..<4 {
            tyresPressure.append(readFloat(from: data, at: pos))
            pos += 4
        }
        
        // Surface types (4 * 1 byte)
        var surfaceType: [UInt8] = []
        for _ in 0..<4 {
            surfaceType.append(data[pos])
            pos += 1
        }
        
        return CarTelemetryData(
            speed: speed,
            throttle: throttle,
            steer: steer,
            brake: brake,
            clutch: clutch,
            gear: gear,
            engineRPM: engineRPM,
            drs: drs,
            revLightsPercent: revLightsPercent,
            revLightsBitValue: revLightsBitValue,
            brakesTemperature: brakesTemperature,
            tyresSurfaceTemperature: tyresSurfaceTemperature,
            tyresInnerTemperature: tyresInnerTemperature,
            engineTemperature: engineTemperature,
            tyresPressure: tyresPressure,
            surfaceType: surfaceType
        )
    }
    
    private func parseCarStatusPacket(_ data: Data, header: PacketHeader) {
        // Car status packet structure: Header (30 bytes) + 22 cars * 58 bytes per car = 1306 bytes total
        
        let expectedCarDataSize = 58
        let expectedTotalSize = 30 + (22 * expectedCarDataSize)
        
        guard data.count >= expectedTotalSize else {
            print("⚠️ Car status packet size mismatch: expected \(expectedTotalSize), got \(data.count)")
            return
        }
        
        let playerIndex = Int(header.playerCarIndex)
        guard playerIndex < 22 else { return }
        
        let carDataOffset = 30 + (playerIndex * expectedCarDataSize)
        
        if let playerStatus = parseCarStatusData(from: data, at: carDataOffset) {
            DispatchQueue.main.async {
                self.currentStatus = playerStatus
                print("⚡ Status: ERS=\(Int(playerStatus.ersStoreEnergy/1000))kJ, Fuel=\(playerStatus.fuelInTank)kg")
            }
        }
    }
    
    private func parseCarStatusData(from data: Data, at offset: Int) -> CarStatusData? {
        guard offset + 58 <= data.count else { return nil }
        
        var pos = offset
        
        let tractionControl = data[pos]; pos += 1
        let antiLockBrakes = data[pos]; pos += 1
        let fuelMix = data[pos]; pos += 1
        let frontBrakeBias = data[pos]; pos += 1
        let pitLimiterStatus = data[pos]; pos += 1
        let fuelInTank = readFloat(from: data, at: pos); pos += 4
        let fuelCapacity = readFloat(from: data, at: pos); pos += 4
        let fuelRemainingLaps = readFloat(from: data, at: pos); pos += 4
        let maxRPM = readUInt16(from: data, at: pos); pos += 2
        let idleRPM = readUInt16(from: data, at: pos); pos += 2
        let maxGears = data[pos]; pos += 1
        let drsAllowed = data[pos]; pos += 1
        let drsActivationDistance = readUInt16(from: data, at: pos); pos += 2
        let actualTyreCompound = data[pos]; pos += 1
        let visualTyreCompound = data[pos]; pos += 1
        let tyresAgeLaps = data[pos]; pos += 1
        let vehicleFiaFlags = Int8(bitPattern: data[pos]); pos += 1
        let enginePowerICE = readFloat(from: data, at: pos); pos += 4
        let enginePowerMGUK = readFloat(from: data, at: pos); pos += 4
        let ersStoreEnergy = readFloat(from: data, at: pos); pos += 4
        let ersDeployMode = data[pos]; pos += 1
        let ersHarvestedThisLapMGUK = readFloat(from: data, at: pos); pos += 4
        let ersHarvestedThisLapMGUH = readFloat(from: data, at: pos); pos += 4
        let ersDeployedThisLap = readFloat(from: data, at: pos); pos += 4
        let networkPaused = data[pos]; pos += 1
        
        return CarStatusData(
            tractionControl: tractionControl,
            antiLockBrakes: antiLockBrakes,
            fuelMix: fuelMix,
            frontBrakeBias: frontBrakeBias,
            pitLimiterStatus: pitLimiterStatus,
            fuelInTank: fuelInTank,
            fuelCapacity: fuelCapacity,
            fuelRemainingLaps: fuelRemainingLaps,
            maxRPM: maxRPM,
            idleRPM: idleRPM,
            maxGears: maxGears,
            drsAllowed: drsAllowed,
            drsActivationDistance: drsActivationDistance,
            actualTyreCompound: actualTyreCompound,
            visualTyreCompound: visualTyreCompound,
            tyresAgeLaps: tyresAgeLaps,
            vehicleFiaFlags: vehicleFiaFlags,
            enginePowerICE: enginePowerICE,
            enginePowerMGUK: enginePowerMGUK,
            ersStoreEnergy: ersStoreEnergy,
            ersDeployMode: ersDeployMode,
            ersHarvestedThisLapMGUK: ersHarvestedThisLapMGUK,
            ersHarvestedThisLapMGUH: ersHarvestedThisLapMGUH,
            ersDeployedThisLap: ersDeployedThisLap,
            networkPaused: networkPaused
        )
    }
    
    private func parseLapDataPacket(_ data: Data, header: PacketHeader) {
        // Basic lap data parsing - we can expand this later
        let expectedSize = 30 + (22 * 53) + 2 // Header + 22 cars * 53 bytes + 2 bytes footer
        guard data.count >= expectedSize else { return }
        
        let playerIndex = Int(header.playerCarIndex)
        guard playerIndex < 22 else { return }
        
        // We can implement lap data parsing later if needed
        print("📊 Lap data packet received")
    }
    
    private func parseSessionPacket(_ data: Data, header: PacketHeader) {
        // Session data parsing - we can implement this later for track info, weather, etc.
        print("🏁 Session data packet received")
    }
    
    private func parseEventPacket(_ data: Data, header: PacketHeader) {
        print("🎯 Event packet received - \(data.count) bytes")
        
        // Event packets contain 4-character event codes
        if data.count >= 34 { // Header (30) + Event code (4)
            let eventCodeData = data.subdata(in: 30..<34)
            if let eventCode = String(data: eventCodeData, encoding: .ascii) {
                print("   Event code: '\(eventCode)'")
                
                // Log common event types
                switch eventCode {
                case "SSTA": print("   📍 Session Started")
                case "SEND": print("   🏁 Session Ended")
                case "FTLP": print("   🥇 Fastest Lap")
                case "RTMT": print("   🔄 Retirement")
                case "DRSE": print("   💨 DRS Enabled")
                case "DRSD": print("   🚫 DRS Disabled")
                case "TMPT": print("   🏆 Team Mate In Pits")
                case "CHQF": print("   🏁 Chequered Flag")
                case "RCWN": print("   👑 Race Winner")
                default: print("   ❓ Unknown event: \(eventCode)")
                }
            }
        }
    }
    
    private func parseSessionHistoryPacket(_ data: Data, header: PacketHeader) {
        print("📊 Session history packet received - \(data.count) bytes")
        print("   📈 Contains historical lap data and sector times")
        print("   🚨 We need Type 6 (carTelemetry) for live RPM/speed/throttle/brake!")
        print("   💡 Try changing F1 24 telemetry settings or driving more actively")
    }
    
    private func parseCarDamagePacket(_ data: Data, header: PacketHeader) {
        print("🔧 Car damage packet received - \(data.count) bytes")
        print("   ✅ This confirms F1 24 is sending racing data!")
        print("   🎯 You're actively racing - great!")
        print("   📋 But F1 24 telemetry settings need adjustment to send Type 6 packets")
        print("   💡 Look for 'Car Telemetry' or 'Vehicle Data' setting in F1 24")
    }
    
    // MARK: - Helper Functions for Safe Data Reading
    
    private func readUInt16(from data: Data, at offset: Int) -> UInt16 {
        guard offset + 1 < data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    
    private func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        guard offset + 3 < data.count else { return 0 }
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }
    
    private func readUInt64(from data: Data, at offset: Int) -> UInt64 {
        guard offset + 7 < data.count else { return 0 }
        return UInt64(data[offset]) |
               (UInt64(data[offset + 1]) << 8) |
               (UInt64(data[offset + 2]) << 16) |
               (UInt64(data[offset + 3]) << 24) |
               (UInt64(data[offset + 4]) << 32) |
               (UInt64(data[offset + 5]) << 40) |
               (UInt64(data[offset + 6]) << 48) |
               (UInt64(data[offset + 7]) << 56)
    }
    
    private func readFloat(from data: Data, at offset: Int) -> Float {
        guard offset + 3 < data.count else { return 0.0 }
        let bytes = [data[offset], data[offset + 1], data[offset + 2], data[offset + 3]]
        return bytes.withUnsafeBytes { $0.load(as: Float.self) }
    }
}
