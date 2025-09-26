import Foundation
import Network
import Combine
import Darwin

// Simplified F1 24 Telemetry Receiver - Based on working F1-Grump approach
class SimpleTelemetryReceiver: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var currentTelemetry: CarTelemetryData?
    @Published var currentStatus: CarStatusData?
    @Published var isConnected: Bool = false
    @Published var lastPacketTime: Date?
    @Published var packetsReceived: Int = 0
    
    private var listener: NWListener?
    private let port: UInt16
    private var connection: NWConnection?
    
    // Track packet size diversity to detect filtering
    private var packetSizes: Set<Int> = []
    private var sizeStats: [Int: Int] = [:]
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case failed(Error)
    }
    
    init(port: UInt16 = 20777) {
        self.port = port
    }
    
    func startReceiving() {
        guard listener == nil else { return }
        
        print("🚀 Starting STATELESS UDP receiver on port \(port)")
        print("🔧 CRITICAL: Treating UDP as stateless datagrams, not connections")
        connectionStatus = .connecting
        
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            parameters.acceptLocalOnly = false
            parameters.allowFastOpen = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            // CRITICAL: Handle each UDP datagram independently, no "connections"
            listener?.newConnectionHandler = { [weak self] newConnection in
                print("🔗 New UDP datagram source: \(newConnection.endpoint)")
                newConnection.start(queue: .global(qos: .userInitiated))
                
                // STATELESS: Process each datagram independently
                self?.receiveDatagrams(from: newConnection)
            }
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.connectionStatus = .connected
                        self?.isConnected = true
                        print("✅ UDP listener ready - accepting ALL F1 24 connections")
                    case .failed(let error):
                        self?.connectionStatus = .failed(error)
                        self?.isConnected = false
                        print("❌ UDP listener failed: \(error)")
                    case .cancelled:
                        self?.connectionStatus = .disconnected
                        self?.isConnected = false
                        print("🔌 UDP listener cancelled")
                    default:
                        print("🔄 UDP listener state: \(state)")
                        break
                    }
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            
        } catch {
            connectionStatus = .failed(error)
            isConnected = false
            print("❌ Failed to create UDP listener: \(error)")
        }
    }
    
    func stopReceiving() {
        listener?.cancel()
        connection?.cancel()
        listener = nil
        connection = nil
        connectionStatus = .disconnected
        print("🔌 Stopped UDP receiver")
    }
    
    private func startReceivingData() {
        guard let connection = connection else { return }
        receiveDatagrams(from: connection)
    }
    
    private func receiveDatagrams(from connection: NWConnection) {
        // STATELESS UDP: Each receive call gets one complete datagram
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, isComplete, error in
            
            if let error = error {
                print("❌ UDP datagram error: \(error)")
                return
            }
            
            if let data = data, !data.isEmpty {
                // CRITICAL: Log EVERY datagram we receive, completely stateless
                print("📡 UDP DATAGRAM: \(data.count) bytes from \(connection.endpoint)")
                
                // Enhanced packet size analysis
                print("   📏 PACKET SIZE ANALYSIS:")
                switch data.count {
                case 45:
                    print("      Size 45 = Type 3 (Event) packets")
                case 953:
                    print("      Size 953 = Type 10 (Car Damage) packets")
                case 1285:
                    print("      Size 1285 = Type 2 (Lap Data) packets ⚠️ ONLY SEEING THIS SIZE!")
                case 1353:
                    print("      Size 1353 = Type 6 (Car Telemetry) packets 🎯 THIS IS WHAT WE NEED!")
                case 1460:
                    print("      Size 1460 = Type 11 (Session History) packets")
                default:
                    print("      Size \(data.count) = Unknown packet type")
                }
                
                if data.count >= 10 {
                    let hexString = data.prefix(10).map { String(format: "%02x", $0) }.joined(separator: " ")
                    print("   📊 First 10 bytes: \(hexString)")
                    
                    // Try to read packet ID from multiple positions
                    for pos in 5...8 {
                        if pos < data.count {
                            let testId = data[pos]
                            if testId == 6 {
                                print("   🚨🚨🚨 FOUND TYPE 6 AT POSITION \(pos)! 🚨🚨🚨")
                            }
                        }
                    }
                }
                
                // Track packet size diversity
                self?.packetSizes.insert(data.count)
                self?.sizeStats[data.count] = (self?.sizeStats[data.count] ?? 0) + 1
                
                // Alert if we're only seeing one packet size (filtering detected)
                if let self = self, self.packetsReceived > 0 && self.packetsReceived % 10 == 0 {
                    print("🔍 FILTERING DETECTION:")
                    print("   📊 Unique packet sizes seen: \(self.packetSizes.count)")
                    print("   📈 Size distribution: \(self.sizeStats)")
                    if self.packetSizes.count == 1 {
                        print("   🚨 FILTERING DETECTED! Only seeing \(self.packetSizes.first!) byte packets")
                        print("   💡 F1 24 should send multiple packet sizes (45, 953, 1285, 1353, 1460)")
                        print("   🔧 Check F1 24 telemetry settings for individual packet type toggles")
                    }
                }
                
                self?.processPacket(data)
                
                DispatchQueue.main.async {
                    self?.packetsReceived += 1
                    self?.lastPacketTime = Date()
                }
            }
            
            // STATELESS: Always continue receiving more datagrams
            self?.receiveDatagrams(from: connection)
        }
    }
    
    private func processPacket(_ data: Data) {
        // F1 24 header is 29 bytes total based on official struct
        guard data.count >= 29 else {
            print("⚠️ Packet too small: \(data.count) bytes (need 29+ for F1 24)")
            // DEBUG: Show hex data for small packets to diagnose
            if data.count > 0 {
                let hexString = data.prefix(min(20, data.count)).map { String(format: "%02x", $0) }.joined(separator: " ")
                print("   🔍 First \(min(20, data.count)) bytes: \(hexString)")
            }
            return
        }
        
        // Parse complete F1 24 packet header
        var pos = 0
        let packetFormat = readUInt16(from: data, at: pos); pos += 2        // Bytes 0-1
        guard packetFormat == 2024 else {
            print("⚠️ Invalid format: \(packetFormat)")
            return
        }
        
        let gameYear = data[pos]; pos += 1                                  // Byte 2
        let gameMajorVersion = data[pos]; pos += 1                          // Byte 3  
        let gameMinorVersion = data[pos]; pos += 1                          // Byte 4
        let packetVersion = data[pos]; pos += 1                             // Byte 5
        let packetId = data[pos]; pos += 1                                  // Byte 6
        
        // CRITICAL DEBUG: Show raw bytes around packet ID
        if data.count >= 10 {
            let rawBytes = data.prefix(10).map { String(format: "%02x", $0) }.joined(separator: " ")
            print("   🔍 RAW HEADER BYTES: \(rawBytes)")
            print("   🔍 PacketID at byte 6: \(packetId) (0x\(String(format: "%02x", packetId)))")
            
            // BRUTE FORCE: Try reading packet ID from different positions
            print("   🧪 TESTING DIFFERENT PACKET ID POSITIONS:")
            for testPos in 4...8 {
                if testPos < data.count {
                    let testId = data[testPos]
                    print("      Byte \(testPos): \(testId) (0x\(String(format: "%02x", testId)))")
                    if testId == 6 {
                        print("      🚨 FOUND PACKET ID 6 AT BYTE \(testPos)! 🚨")
                    }
                }
            }
        }
        
        let sessionUID = readUInt64(from: data, at: pos); pos += 8          // Bytes 7-14
        let sessionTime = readFloat(from: data, at: pos); pos += 4          // Bytes 15-18
        let frameIdentifier = readUInt32(from: data, at: pos); pos += 4     // Bytes 19-22
        let overallFrameIdentifier = readUInt32(from: data, at: pos); pos += 4  // Bytes 23-26
        let playerCarIndex = data[pos]; pos += 1                            // Byte 27
        let secondaryPlayerCarIndex = data[pos]; pos += 1                   // Byte 28
        
        print("📦 F1 24 Packet: Type=\(packetId), Size=\(data.count), Player=\(playerCarIndex)")
        print("   Session: \(sessionUID), Time: \(String(format: "%.3f", sessionTime))s, Frame: \(frameIdentifier)")
        print("   Game: v\(gameMajorVersion).\(gameMinorVersion), Packet v\(packetVersion)")
        
        // DEBUG: Log ALL packet types to see what we're getting
        let packetTypeNames = [
            0: "Motion", 1: "Session", 2: "Lap Data", 3: "Event", 4: "Participants",
            5: "Car Setups", 6: "Car Telemetry", 7: "Car Status", 8: "Final Classification",
            9: "Lobby Info", 10: "Car Damage", 11: "Session History", 12: "Tyre Sets",
            13: "Motion Ex"
        ]
        let typeName = packetTypeNames[Int(packetId)] ?? "Unknown"
        print("   📋 Packet Type: \(typeName) (ID: \(packetId))")
        
        // CRITICAL DEBUG: Log EVERY packet type we receive
        print("   🔍 PACKET TYPE \(packetId) RECEIVED - Size: \(data.count) bytes")
        
        // Process Type 6 (Car Telemetry) and Type 7 (Car Status) packets
        if packetId == 6 {
            print("🚨🚨🚨 TYPE 6 PACKET DETECTED! 🚨🚨🚨")
            print("🎯 CAR TELEMETRY PACKET FOUND!")
            print("   💡 F1 24 Settings Check:")
            print("      - UDP Telemetry Output = ON")
            print("      - 'Your Telemetry' = Unrestricted (for full data)")
            print("      - UDP Broadcast Mode = OFF (recommended)")
            parseCarTelemetryPacket(data, playerCarIndex: playerCarIndex)
        } else if packetId == 7 {
            print("🔋 TYPE 7 PACKET DETECTED! (Car Status)")
            print("🎯 CAR STATUS PACKET FOUND - Contains ERS data!")
            parseCarStatusPacket(data, playerCarIndex: playerCarIndex)
        } else {
            // Add specific guidance for missing Type 6 packets
            if packetId == 2 || packetId == 10 {
                print("   ℹ️ Getting racing data but no Type 6 (Car Telemetry)")
                print("   🔧 Check F1 24: Settings → Telemetry → Car Telemetry Data = ON")
            }
            
            // REMOVED: Experimental parsing was causing crashes by trying to parse 
            // Motion/Lap Data packets as telemetry data, resulting in garbage values
            // that exceeded Float->Int conversion limits
        }
    }
    
    private func parseCarTelemetryPacket(_ data: Data, playerCarIndex: UInt8) {
        print("🔍 Parsing car telemetry - packet size: \(data.count) bytes")
        
        // Car telemetry starts after F1 24 header (29 bytes) + player car offset
        let headerSize = 29  // F1 24 header is 29 bytes based on official struct
        
        // F1 24 CarTelemetryData structure size calculation:
        // uint16 m_speed + float m_throttle + float m_steer + float m_brake + uint8 m_clutch + 
        // int8 m_gear + uint16 m_engineRPM + uint8 m_drs + uint8 m_revLightsPercent + 
        // uint16 m_revLightsBitValue + uint16[4] m_brakesTemperature + uint8[4] m_tyresSurfaceTemperature +
        // uint8[4] m_tyresInnerTemperature + uint16 m_engineTemperature + float[4] m_tyresPressure + 
        // uint8[4] m_surfaceType
        // = 2 + 4 + 4 + 4 + 1 + 1 + 2 + 1 + 1 + 2 + 8 + 4 + 4 + 2 + 16 + 4 = 60 bytes
        let carDataSize = 60 // Verified against F1 24 official specification
        let playerIndex = Int(playerCarIndex)
        
        guard playerIndex < 22 else {
            print("⚠️ Invalid player index: \(playerIndex)")
            return
        }
        
        let carDataOffset = headerSize + (playerIndex * carDataSize)
        
        guard carDataOffset + carDataSize <= data.count else {
            print("⚠️ Not enough data for car \(playerIndex)")
            return
        }
        
        // Parse the essential telemetry data with bounds checking
        var pos = carDataOffset
        
        guard pos + 19 <= data.count else {
            print("⚠️ Not enough data for telemetry parsing")
            return
        }
        
        let speed = readUInt16(from: data, at: pos); pos += 2
        let throttle = readFloat(from: data, at: pos); pos += 4
        let steer = readFloat(from: data, at: pos); pos += 4
        let brake = readFloat(from: data, at: pos); pos += 4
        let clutch = data[pos]; pos += 1
        let gear = Int8(bitPattern: data[pos]); pos += 1
        let engineRPM = readUInt16(from: data, at: pos); pos += 2
        let drs = data[pos]; pos += 1
        
        // Debug: Show parsed telemetry values (with safe conversion)
        let throttlePercent = max(0, min(100, Int(throttle.isFinite ? throttle * 100 : 0)))
        let brakePercent = max(0, min(100, Int(brake.isFinite ? brake * 100 : 0)))
        print("🏎️ Telemetry: Speed=\(speed)km/h, RPM=\(engineRPM), Gear=\(gear), Throttle=\(throttlePercent)%, Brake=\(brakePercent)%")
        
        // Validate data ranges to catch parsing errors
        guard speed <= 400 else {  // Max F1 speed ~370 km/h
            print("⚠️ Invalid speed: \(speed) km/h - parsing error detected")
            return
        }
        
        guard engineRPM <= 20000 else {  // Max F1 RPM ~15000
            print("⚠️ Invalid RPM: \(engineRPM) - parsing error detected")
            return
        }
        
        guard throttle >= 0.0 && throttle <= 1.0 else {
            print("⚠️ Invalid throttle: \(throttle) - parsing error detected")
            return
        }
        
        guard brake >= 0.0 && brake <= 1.0 else {
            print("⚠️ Invalid brake: \(brake) - parsing error detected")
            return
        }
        
        // Debug output for successful parsing
        let safeThrottlePercent = max(0, min(100, Int(throttle.isFinite ? throttle * 100 : 0)))
        let safeBrakePercent = max(0, min(100, Int(brake.isFinite ? brake * 100 : 0)))
        print("✅ VALID TELEMETRY PARSED:")
        print("   Speed: \(speed) km/h")
        print("   RPM: \(engineRPM)")
        print("   Gear: \(gear)")
        print("   Throttle: \(safeThrottlePercent)%")
        print("   Brake: \(safeBrakePercent)%")
        print("   DRS: \(drs == 1 ? "ON" : "OFF")")
        
        // Create telemetry data with minimal required fields
        let telemetry = CarTelemetryData(
            speed: speed,
            throttle: throttle,
            steer: steer,
            brake: brake,
            clutch: clutch,
            gear: gear,
            engineRPM: engineRPM,
            drs: drs,
            revLightsPercent: 0,
            revLightsBitValue: 0,
            brakesTemperature: [0, 0, 0, 0],
            tyresSurfaceTemperature: [0, 0, 0, 0],
            tyresInnerTemperature: [0, 0, 0, 0],
            engineTemperature: 0,
            tyresPressure: [0.0, 0.0, 0.0, 0.0],
            surfaceType: [0, 0, 0, 0]
        )
        
        DispatchQueue.main.async {
            self.currentTelemetry = telemetry
            
            // Safe conversion to prevent crash
            let throttlePercent = max(0, min(100, Int((throttle * 100).isFinite ? throttle * 100 : 0)))
            let brakePercent = max(0, min(100, Int((brake * 100).isFinite ? brake * 100 : 0)))
            
            print("🏎️ SUCCESS! Speed=\(speed)km/h, RPM=\(engineRPM), Gear=\(gear)")
            print("   Throttle=\(throttlePercent)%, Brake=\(brakePercent)%, DRS=\(drs > 0 ? "ON" : "OFF")")
        }
    }
    
    private func parseCarStatusPacket(_ data: Data, playerCarIndex: UInt8) {
        print("🔋 Parsing car status - packet size: \(data.count) bytes")
        
        // Car status starts after F1 24 header (29 bytes) + player car offset
        let headerSize = 29  // F1 24 header is 29 bytes
        
        // F1 24 CarStatusData structure size calculation:
        // Based on the CarStatusData struct in F1TelemetryPacket.swift
        // All the fields from tractionControl to networkPaused = 54 bytes per car
        let carStatusSize = 54 // Verified against F1 24 official specification
        let playerIndex = Int(playerCarIndex)
        
        guard playerIndex < 22 else {
            print("⚠️ Invalid player index: \(playerIndex)")
            return
        }
        
        let carStatusOffset = headerSize + (playerIndex * carStatusSize)
        
        guard carStatusOffset + carStatusSize <= data.count else {
            print("⚠️ Not enough data for car status \(playerIndex)")
            return
        }
        
        // Parse the car status data with focus on ERS
        var pos = carStatusOffset
        
        // Skip to ERS data (we need to calculate the offset to ersStoreEnergy)
        // From CarStatusData struct:
        // tractionControl (1) + antiLockBrakes (1) + fuelMix (1) + frontBrakeBias (1) + 
        // pitLimiterStatus (1) + fuelInTank (4) + fuelCapacity (4) + fuelRemainingLaps (4) +
        // maxRPM (2) + idleRPM (2) + maxGears (1) + drsAllowed (1) + drsActivationDistance (2) +
        // actualTyreCompound (1) + visualTyreCompound (1) + tyresAgeLaps (1) + vehicleFiaFlags (1) +
        // enginePowerICE (4) + enginePowerMGUK (4) = 37 bytes before ersStoreEnergy
        
        let ersOffset = pos + 37
        
        guard ersOffset + 4 <= data.count else {
            print("⚠️ Not enough data for ERS parsing")
            return
        }
        
        let ersStoreEnergy = readFloat(from: data, at: ersOffset)
        
        // Validate ERS data (should be 0-4MJ = 0-4,000,000 Joules)
        guard ersStoreEnergy >= 0.0 && ersStoreEnergy <= 4_200_000.0 else {
            print("⚠️ Invalid ERS energy: \(ersStoreEnergy) J - parsing error detected")
            return
        }
        
        print("🔋 ERS ENERGY PARSED: \(Int(ersStoreEnergy / 1000)) kJ")
        
        // Create a minimal CarStatusData with just the ERS energy we need
        // For now, we'll set other fields to default values
        let statusData = CarStatusData(
            tractionControl: 0,
            antiLockBrakes: 0,
            fuelMix: 0,
            frontBrakeBias: 0,
            pitLimiterStatus: 0,
            fuelInTank: 0.0,
            fuelCapacity: 0.0,
            fuelRemainingLaps: 0.0,
            maxRPM: 0,
            idleRPM: 0,
            maxGears: 0,
            drsAllowed: 0,
            drsActivationDistance: 0,
            actualTyreCompound: 0,
            visualTyreCompound: 0,
            tyresAgeLaps: 0,
            vehicleFiaFlags: 0,
            enginePowerICE: 0.0,
            enginePowerMGUK: 0.0,
            ersStoreEnergy: ersStoreEnergy,
            ersDeployMode: 0,
            ersHarvestedThisLapMGUK: 0.0,
            ersHarvestedThisLapMGUH: 0.0,
            ersDeployedThisLap: 0.0,
            networkPaused: 0
        )
        
        DispatchQueue.main.async {
            self.currentStatus = statusData
            print("🔋 SUCCESS! ERS Energy: \(Int(ersStoreEnergy / 1000)) kJ")
        }
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
    
    private func readDouble(from data: Data, at offset: Int) -> Double {
        guard offset + 7 < data.count else { return 0.0 }
        let bytes = [data[offset], data[offset + 1], data[offset + 2], data[offset + 3],
                     data[offset + 4], data[offset + 5], data[offset + 6], data[offset + 7]]
        return bytes.withUnsafeBytes { $0.load(as: Double.self) }
    }
}
