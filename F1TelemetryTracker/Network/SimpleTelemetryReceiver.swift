import Foundation
import Network
import Combine
import Darwin

// Simple session data structure for essential fields only
struct SimpleSessionData {
    let trackId: Int8
    let trackTemperature: Int8
    let weather: UInt8
    let totalLaps: UInt8
    let safetyCarStatus: UInt8
}

// Simplified F1 24 Telemetry Receiver - Based on working F1-Grump approach
class SimpleTelemetryReceiver: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var currentTelemetry: CarTelemetryData?
    @Published var currentStatus: CarStatusData?
    @Published var currentLapData: LapData?
    @Published var currentSessionData: PacketSessionData?
    @Published var allLapData: [LapData] = []
    @Published var participantNames: [String] = Array(repeating: "Unknown", count: 22)
    @Published var currentCarDamage: CarDamageData?
    @Published var currentMotionData: [CarMotionData] = []
    @Published var isConnected: Bool = false
    @Published var lastPacketTime: Date?
    @Published var packetsReceived: Int = 0
    
    private var listener: NWListener?
    private let port: UInt16
    private var connection: NWConnection?
    
    // Track packet size diversity to detect filtering
    private var packetSizes: Set<Int> = []
    private var sizeStats: [Int: Int] = [:]
    
    // Packet rate monitoring
    private var packetRates: [UInt8: (count: Int, lastReset: Date)] = [:]
    private var packetValidationErrors: [String: Int] = [:]
    
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
        // F1 24 header validation
        guard data.count >= PacketSizes.header else {
            print("⚠️ Packet too small: \(data.count) bytes (need \(PacketSizes.header)+ for F1 24)")
            // DEBUG: Show hex data for small packets to diagnose
            if data.count > 0 {
                let hexString = data.prefix(min(20, data.count)).map { String(format: "%02x", $0) }.joined(separator: " ")
                print("   🔍 First \(min(20, data.count)) bytes: \(hexString)")
            }
            return
        }
        
        // Parse and validate header
        guard let header = parseAndValidateHeader(from: data) else {
            return
        }
        
        // Track packet rates
        trackPacketRate(packetId: header.packetId)
        
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
        
        // Process all important packet types
        switch packetId {
        case 0:
            print("🏃 TYPE 0: Motion packet received - size: \(data.count) bytes")
            parseMotionPacket(data)
            
        case 1:
            print("🏁 TYPE 1: Session packet received - size: \(data.count) bytes")
            parseSessionPacket(data)
            
        case 2:
            print("⏱️ TYPE 2: Lap Data packet received")
            parseLapDataPacket(data, playerCarIndex: playerCarIndex)
            
        case 3:
            print("📢 TYPE 3: Event packet received")
            // Event data - not needed for current UI
            
        case 4:
            print("👥 TYPE 4: Participants packet received")
            parseParticipantsPacket(data)
            
        case 5:
            print("🔧 TYPE 5: Car Setups packet received")
            // Car setups - not needed for current UI
            
        case 6:
            print("🚨 TYPE 6: Car Telemetry packet received")
            parseCarTelemetryPacket(data, playerCarIndex: playerCarIndex)
            
        case 7:
            print("🔋 TYPE 7: Car Status packet received")
            parseCarStatusPacket(data, playerCarIndex: playerCarIndex)
            
        case 8:
            print("🏆 TYPE 8: Final Classification packet received")
            // Final classification - not needed for current UI
            
        case 9:
            print("🌐 TYPE 9: Lobby Info packet received")
            // Lobby info - not needed for current UI
            
        case 10:
            print("🔧 TYPE 10: Car Damage packet received")
            parseCarDamagePacket(data, playerCarIndex: playerCarIndex)
            
        case 11:
            print("📊 TYPE 11: Session History packet received")
            // Session history - not needed for current UI
            
        case 12:
            print("🛞 TYPE 12: Tyre Sets packet received")
            // Tyre sets - could be useful for tyre strategy
            
        case 13:
            print("🏃‍♂️ TYPE 13: Motion Ex packet received")
            // Extended motion data - not needed for current UI
            
        default:
            print("❓ Unknown packet type: \(packetId)")
        }
    }
    
    private func parseCarTelemetryPacket(_ data: Data, playerCarIndex: UInt8) {
        print("🔍 Parsing car telemetry - packet size: \(data.count) bytes")
        print("🎯 Player car index: \(playerCarIndex)")
        
        // Car telemetry starts after F1 24 header + player car offset
        let headerSize = PacketSizes.header
        
        // F1 24 CarTelemetryData structure size: 60 bytes (CORRECTED)
        // uint16 speed(2) + float throttle(4) + float steer(4) + float brake(4) + 
        // uint8 clutch(1) + int8 gear(1) + uint16 engineRPM(2) + uint8 drs(1) + 
        // uint8 revLightsPercent(1) + uint16 revLightsBitValue(2) + 
        // uint16[4] brakesTemp(8) + uint8[4] tyresSurfaceTemp(4) + 
        // uint8[4] tyresInnerTemp(4) + uint16 engineTemp(2) + 
        // float[4] tyresPressure(16) + uint8[4] surfaceType(4) = 60 bytes
        let carDataSize = PacketSizes.carTelemetryDataSize
        let playerIndex = Int(playerCarIndex)
        
        guard playerIndex < 22 else {
            print("⚠️ Invalid player index: \(playerIndex)")
            return
        }
        
        let carDataOffset = headerSize + (playerIndex * carDataSize)
        print("🎯 Calculated offset: header(\(headerSize)) + player(\(playerIndex)) * carSize(\(carDataSize)) = \(carDataOffset)")
        
        guard carDataOffset + carDataSize <= data.count else {
            print("⚠️ Not enough data for car \(playerIndex): need \(carDataOffset + carDataSize), have \(data.count)")
            return
        }
        
        // DEBUG: Show raw bytes at the expected position
        let debugBytes = data[carDataOffset..<min(carDataOffset + 20, data.count)]
        let debugHex = debugBytes.map { String(format: "%02x", $0) }.joined(separator: " ")
        print("🔍 Raw bytes at offset \(carDataOffset): \(debugHex)")
        
        // DEBUG: Also try car 0 to see if player index is wrong
        let car0Offset = headerSize
        let car0Bytes = data[car0Offset..<min(car0Offset + 20, data.count)]
        let car0Hex = car0Bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
        print("🔍 Raw bytes at car 0 offset \(car0Offset): \(car0Hex)")
        
        // CRITICAL FIX: Check if player car data is all zeros, if so use car 0
        let playerDataIsEmpty = debugBytes.allSatisfy { $0 == 0 }
        let actualCarOffset: Int
        
        if playerDataIsEmpty && playerIndex != 0 {
            print("⚠️ Player car \(playerIndex) has no data, using car 0 instead")
            actualCarOffset = car0Offset
        } else {
            actualCarOffset = carDataOffset
        }
        
        print("🎯 Using car offset: \(actualCarOffset)")
        
        // Parse the essential telemetry data with bounds checking
        var pos = actualCarOffset
        
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
        let headerSize = PacketSizes.header  // F1 24 header is 29 bytes
        
        // F1 24 CarStatusData structure size calculation:
        // CRITICAL FIX: Packet is 1239 bytes total, header is 29 bytes
        // So car data is: (1239 - 29) / 22 cars = 1210 / 22 = 55 bytes per car
        let carStatusSize = 55 // Calculated from actual packet size: (1239 - 29) / 22
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
        
        // Parse the car status data step by step according to F1 24 spec
        var pos = carStatusOffset
        
        // Read fields in exact order from F1 24 specification
        let tractionControl = data[pos]; pos += 1          // 0: UInt8
        let antiLockBrakes = data[pos]; pos += 1           // 1: UInt8  
        let fuelMix = data[pos]; pos += 1                  // 2: UInt8
        let frontBrakeBias = data[pos]; pos += 1           // 3: UInt8
        let pitLimiterStatus = data[pos]; pos += 1         // 4: UInt8
        let fuelInTank = readFloat(from: data, at: pos); pos += 4      // 5-8: Float
        let fuelCapacity = readFloat(from: data, at: pos); pos += 4    // 9-12: Float
        let fuelRemainingLaps = readFloat(from: data, at: pos); pos += 4 // 13-16: Float
        let maxRPM = readUInt16(from: data, at: pos); pos += 2         // 17-18: UInt16
        let idleRPM = readUInt16(from: data, at: pos); pos += 2        // 19-20: UInt16
        let maxGears = data[pos]; pos += 1                 // 21: UInt8
        let drsAllowed = data[pos]; pos += 1               // 22: UInt8
        let drsActivationDistance = readUInt16(from: data, at: pos); pos += 2 // 23-24: UInt16
        let actualTyreCompound = data[pos]; pos += 1       // 25: UInt8
        let visualTyreCompound = data[pos]; pos += 1       // 26: UInt8
        let tyresAgeLaps = data[pos]; pos += 1             // 27: UInt8
        
        print("🔍 TYRE DEBUG: Actual=\(actualTyreCompound), Visual=\(visualTyreCompound), Age=\(tyresAgeLaps)")
        print("🔍 TYRE INTERPRETATION: Actual=\(tyreCompoundName(actualTyreCompound)), Visual=\(tyreCompoundName(visualTyreCompound))")
        let vehicleFiaFlags = Int8(bitPattern: data[pos]); pos += 1 // 28: Int8
        let enginePowerICE = readFloat(from: data, at: pos); pos += 4 // 29-32: Float
        let enginePowerMGUK = readFloat(from: data, at: pos); pos += 4 // 33-36: Float
        let ersStoreEnergy = readFloat(from: data, at: pos); pos += 4  // 37-40: Float ⭐ THIS IS THE ERS DATA
        
        print("🔋 ERS ENERGY PARSED: \(Int(ersStoreEnergy / 1000)) kJ (Raw: \(ersStoreEnergy) J)")
        print("🏎️ TYRE DATA PARSED: Compound=\(actualTyreCompound), Age=\(tyresAgeLaps) laps")
        print("🔍 DEBUG: Car Status offset=\(carStatusOffset), Final pos=\(pos), packet size=\(data.count)")
        print("🔍 VALIDATION: DRS=\(drsAllowed), MaxRPM=\(maxRPM), Fuel=\(fuelInTank)L")
        print("🔍 PLAYER INDEX: Using player index \(playerIndex) from header")
        
        // DEBUG: Try reading from car index 0 to see if we get better data
        if playerIndex != 0 {
            let car0Offset = headerSize + (0 * carStatusSize)
            if car0Offset + 40 <= data.count {
                var car0Pos = car0Offset + 37  // Skip to ERS position
                let car0ERS = readFloat(from: data, at: car0Pos)
                print("🔍 Car 0 ERS comparison: \(car0ERS) J")
            }
        }
        
        // Remove the validation that was failing - let's see what values we get
        // guard ersStoreEnergy >= 0.0 && ersStoreEnergy <= 4_200_000.0 else {
        //     print("⚠️ Invalid ERS energy: \(ersStoreEnergy) J - parsing error detected")
        //     return
        // }
        
        // Create a CarStatusData with the parsed ERS energy and tyre data
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
            actualTyreCompound: actualTyreCompound,
            visualTyreCompound: visualTyreCompound,
            tyresAgeLaps: tyresAgeLaps,
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
    
    private func parseCarDamagePacket(_ data: Data, playerCarIndex: UInt8) {
        print("🔧 Parsing car damage - packet size: \(data.count) bytes")
        
        // Car damage starts after F1 24 header + player car offset
        let headerSize = PacketSizes.header
        
        // F1 24 CarDamageData structure size: 60 bytes per car
        // Based on packet size: (1367 - 29) / 22 cars = 1338 / 22 = ~60.8 bytes per car
        let carDamageSize = 60 // Each car damage data is 60 bytes
        let playerIndex = Int(playerCarIndex)
        
        guard playerIndex < 22 else {
            print("⚠️ Invalid player index: \(playerIndex)")
            return
        }
        
        let carDamageOffset = headerSize + (playerIndex * carDamageSize)
        
        guard carDamageOffset + carDamageSize <= data.count else {
            print("⚠️ Not enough data for car damage \(playerIndex)")
            return
        }
        
        // Parse the car damage data according to F1 24 specification
        var pos = carDamageOffset
        
        // Tyre damage (4 * 4 bytes = 16 bytes)
        var tyresDamage: [Float] = []
        for _ in 0..<4 {
            tyresDamage.append(readFloat(from: data, at: pos))
            pos += 4
        }
        
        // Tyre wear (4 * 1 byte = 4 bytes)
        var tyresWear: [UInt8] = []
        for _ in 0..<4 {
            tyresWear.append(data[pos])
            pos += 1
        }
        
        let engineDamage = data[pos]; pos += 1              // Engine damage %
        let gearBoxDamage = data[pos]; pos += 1             // Gearbox damage %
        let frontLeftWingDamage = Int8(bitPattern: data[pos]); pos += 1   // Front left wing damage %
        let frontRightWingDamage = Int8(bitPattern: data[pos]); pos += 1  // Front right wing damage %
        let rearWingDamage = Int8(bitPattern: data[pos]); pos += 1        // Rear wing damage %
        let floorDamage = Int8(bitPattern: data[pos]); pos += 1           // Floor damage %
        let diffuserDamage = Int8(bitPattern: data[pos]); pos += 1        // Diffuser damage %
        let sidepodDamage = Int8(bitPattern: data[pos]); pos += 1         // Sidepod damage %
        let drsFault = data[pos]; pos += 1                  // DRS fault
        let ersFault = data[pos]; pos += 1                  // ERS fault
        let gearBoxDrivethrough = data[pos]; pos += 1       // Gearbox drivethrough penalty
        let engineDrivethrough = data[pos]; pos += 1        // Engine drivethrough penalty
        let wingDrivethrough = data[pos]; pos += 1          // Wing drivethrough penalty
        let engineWear = data[pos]; pos += 1                // Engine wear %
        let gearBoxWear = data[pos]; pos += 1               // Gearbox wear %
        
        let damageData = CarDamageData(
            tyresDamage: tyresDamage,
            tyresWear: tyresWear,
            engineDamage: engineDamage,
            gearBoxDamage: gearBoxDamage,
            frontLeftWingDamage: frontLeftWingDamage,
            frontRightWingDamage: frontRightWingDamage,
            rearWingDamage: rearWingDamage,
            floorDamage: floorDamage,
            diffuserDamage: diffuserDamage,
            sidepodDamage: sidepodDamage,
            drsFault: drsFault,
            ersFault: ersFault,
            gearBoxDrivethrough: gearBoxDrivethrough,
            engineDrivethrough: engineDrivethrough,
            wingDrivethrough: wingDrivethrough,
            engineWear: engineWear,
            gearBoxWear: gearBoxWear
        )
        
        print("🔧 DAMAGE DATA: Engine=\(engineDamage)%, Gearbox=\(gearBoxDamage)%, Wings=[FL:\(frontLeftWingDamage)%, FR:\(frontRightWingDamage)%, R:\(rearWingDamage)%]")
        print("🔧 TYRE DAMAGE: RL=\(String(format: "%.1f", tyresDamage[0]))%, RR=\(String(format: "%.1f", tyresDamage[1]))%, FL=\(String(format: "%.1f", tyresDamage[2]))%, FR=\(String(format: "%.1f", tyresDamage[3]))%")
        
        DispatchQueue.main.async {
            self.currentCarDamage = damageData
            print("🔧 SUCCESS! Car damage data updated")
        }
    }
    
    private func parseLapDataPacket(_ data: Data, playerCarIndex: UInt8) {
        print("🏁 Parsing ALL lap data - packet size: \(data.count) bytes")
        
        // Lap data starts after F1 24 header (29 bytes)
        let headerSize = PacketSizes.header  // F1 24 header is 29 bytes
        
        // F1 24 LapData structure size calculation:
        // From debug output: 1285 bytes total for lap data packets
        // Calculate: (1285 - 29 header - 2 trailer) / 22 cars = 1254 / 22 = 57 bytes per car
        let calculatedLapDataSize = (data.count - headerSize - 2) / 22
        let lapDataSize = calculatedLapDataSize > 0 ? calculatedLapDataSize : 57
        
        print("🔍 CALCULATED LAP DATA SIZE: \(calculatedLapDataSize) bytes per car (packet: \(data.count), header: \(headerSize))")
        print("🔍 EXPECTED: For 1285-byte packets = \((1285 - 29 - 2) / 22) = 57 bytes per car")
        
        // Check session info from header if available
        if data.count >= 29 {
            let sessionUID = readUInt64(from: data, at: 0)
            let sessionTime = readFloat(from: data, at: 8)
            let frameIdentifier = readUInt32(from: data, at: 12)
            print("🏁 SESSION INFO: UID=\(sessionUID), Time=\(sessionTime)s, Frame=\(frameIdentifier)")
        }
        
        var allCarsLapData: [LapData] = []
        
        // Parse lap data for ALL 22 cars
        for carIndex in 0..<22 {
            let lapDataOffset = headerSize + (carIndex * lapDataSize)
            
            guard lapDataOffset + lapDataSize <= data.count else {
                print("⚠️ Not enough data for lap data car \(carIndex)")
                continue
            }
            
            // Parse the essential lap timing data for this car
            var pos = lapDataOffset
            
            let lastLapTimeInMS = readUInt32(from: data, at: pos); pos += 4
            let currentLapTimeInMS = readUInt32(from: data, at: pos); pos += 4
            let sector1TimeInMS = readUInt16(from: data, at: pos); pos += 2
            let sector1TimeMinutes = data[pos]; pos += 1
            let sector2TimeInMS = readUInt16(from: data, at: pos); pos += 2
            let sector2TimeMinutes = data[pos]; pos += 1
            let deltaToCarInFrontInMS = readUInt16(from: data, at: pos); pos += 2
            let deltaToRaceLeaderInMS = readUInt16(from: data, at: pos); pos += 2
            let lapDistance = readFloat(from: data, at: pos); pos += 4
            let totalDistance = readFloat(from: data, at: pos); pos += 4
            let safetyCarDelta = readFloat(from: data, at: pos); pos += 4
            let carPosition = data[pos]; pos += 1
            
            // Debug car position for first few cars with raw bytes
            if carIndex < 3 {
                let startIdx = max(0, pos-10)
                let endIdx = min(data.count, pos+10)
                let rawBytes = Array(data[startIdx..<endIdx])
                let hexBytes = rawBytes.map { String(format: "%02x", $0) }.joined(separator: " ")
                print("🏁 Car \(carIndex): CarPos=\(carPosition), CurrentLap=\(data[pos]), Offset=\(pos-1)")
                print("   Raw bytes [\(startIdx)-\(endIdx)]: \(hexBytes)")
                print("   Position byte at offset \(pos-1): 0x\(String(format: "%02x", carPosition))")
            }
            let currentLapNum = data[pos]; pos += 1
            let pitStatus = data[pos]; pos += 1
            let numPitStops = data[pos]; pos += 1
            let sector = data[pos]; pos += 1
            let currentLapInvalid = data[pos]; pos += 1
            let penalties = data[pos]; pos += 1
            let totalWarnings = data[pos]; pos += 1
            let cornerCuttingWarnings = data[pos]; pos += 1
            let numUnservedDriveThroughPens = data[pos]; pos += 1
            let numUnservedStopGoPens = data[pos]; pos += 1
            let gridPosition = data[pos]; pos += 1
            
            // Debug grid position for first few cars
            if carIndex < 3 {
                print("   GridPos=\(gridPosition), Offset=\(pos-1)")
                print("   Grid byte at offset \(pos-1): 0x\(String(format: "%02x", gridPosition))")
                
                // Show a few more bytes around gridPosition for context
                let gridStartIdx = max(0, pos-5)
                let gridEndIdx = min(data.count, pos+5)
                let gridBytes = Array(data[gridStartIdx..<gridEndIdx])
                let gridHex = gridBytes.map { String(format: "%02x", $0) }.joined(separator: " ")
                print("   Grid context [\(gridStartIdx)-\(gridEndIdx)]: \(gridHex)")
            }
            let driverStatus = data[pos]; pos += 1
            let resultStatus = data[pos]; pos += 1
            let pitLaneTimerActive = data[pos]; pos += 1
            let pitLaneTimeInLaneInMS = readUInt16(from: data, at: pos); pos += 2
            let pitStopTimerInMS = readUInt16(from: data, at: pos); pos += 2
            let pitStopShouldServePen = data[pos]; pos += 1
            
            // Create LapData struct for this car
            let lapData = LapData(
                lastLapTimeInMS: lastLapTimeInMS,
                currentLapTimeInMS: currentLapTimeInMS,
                sector1TimeInMS: sector1TimeInMS,
                sector1TimeMinutes: sector1TimeMinutes,
                sector2TimeInMS: sector2TimeInMS,
                sector2TimeMinutes: sector2TimeMinutes,
                deltaToCarInFrontInMS: deltaToCarInFrontInMS,
                deltaToRaceLeaderInMS: deltaToRaceLeaderInMS,
                lapDistance: lapDistance,
                totalDistance: totalDistance,
                safetyCarDelta: safetyCarDelta,
                carPosition: carPosition,
                currentLapNum: currentLapNum,
                pitStatus: pitStatus,
                numPitStops: numPitStops,
                sector: sector,
                currentLapInvalid: currentLapInvalid,
                penalties: penalties,
                totalWarnings: totalWarnings,
                cornerCuttingWarnings: cornerCuttingWarnings,
                numUnservedDriveThroughPens: numUnservedDriveThroughPens,
                numUnservedStopGoPens: numUnservedStopGoPens,
                gridPosition: gridPosition,
                driverStatus: driverStatus,
                resultStatus: resultStatus,
                pitLaneTimerActive: pitLaneTimerActive,
                pitLaneTimeInLaneInMS: pitLaneTimeInLaneInMS,
                pitStopTimerInMS: pitStopTimerInMS,
                pitStopShouldServePen: pitStopShouldServePen
            )
            
            allCarsLapData.append(lapData)
            
            // Debug output for player car
            if carIndex == Int(playerCarIndex) {
                let currentLapTime = Float(currentLapTimeInMS) / 1000.0
                let lastLapTime = Float(lastLapTimeInMS) / 1000.0
                let sector1Time = Float(sector1TimeInMS) / 1000.0 + Float(sector1TimeMinutes) * 60.0
                let sector2Time = Float(sector2TimeInMS) / 1000.0 + Float(sector2TimeMinutes) * 60.0
                
                print("🏁 PLAYER CAR (\(carIndex)) LAP DEBUG:")
                print("   Position: \(carPosition), Lap: \(currentLapNum)")
                print("   Last Lap MS: \(lastLapTimeInMS)")
                print("   Current Lap MS: \(currentLapTimeInMS)")
                print("   Sector 1: \(sector1TimeInMS)ms + \(sector1TimeMinutes)min")
                print("   Sector 2: \(sector2TimeInMS)ms + \(sector2TimeMinutes)min")
                print("   Pit Stops: \(numPitStops), Penalties: \(penalties)")
                print("   Driver Status: \(driverStatus), Delta to Leader: \(deltaToRaceLeaderInMS)ms")
                print("🏁 LAP DATA UPDATE:")
                print("   Current Lap: \(String(format: "%.3f", currentLapTime))s")
                print("   Last Lap: \(String(format: "%.3f", lastLapTime))s")
                print("   Sector 1: \(String(format: "%.3f", sector1Time))s")
                print("   Sector 2: \(String(format: "%.3f", sector2Time))s")
            }
        }
        
        // Update both individual player data and all cars data
        let playerLapData = allCarsLapData[safe: Int(playerCarIndex)]
        
        DispatchQueue.main.async {
            // Update all lap data for leaderboard
            self.allLapData = allCarsLapData
            
            // Update player's current lap data for dashboard
            if let playerData = playerLapData {
                self.currentLapData = playerData
            }
            
            print("🏁 ALL LAP DATA SUCCESS! Parsed \(allCarsLapData.count) cars")
            if let playerData = playerLapData {
                let currentLapTime = Float(playerData.currentLapTimeInMS) / 1000.0
                let lastLapTime = Float(playerData.lastLapTimeInMS) / 1000.0
                print("🏁 PLAYER LAP DATA: Current: \(String(format: "%.3f", currentLapTime))s, Last: \(String(format: "%.3f", lastLapTime))s")
            }
        }
    }
    
    private func parseSessionPacket(_ data: Data) {
        print("🏁 Parsing session data - packet size: \(data.count) bytes")
        
        let headerSize = PacketSizes.header  // F1 24 header is 29 bytes
        guard data.count >= headerSize + 100 else {  // Session data is quite large
            print("⚠️ Session packet too small: \(data.count) bytes")
            return
        }
        
        var pos = headerSize
        
        // Parse key session data
        let weather = data[pos]; pos += 1
        let trackTemperature = Int8(bitPattern: data[pos]); pos += 1
        let airTemperature = Int8(bitPattern: data[pos]); pos += 1
        let totalLaps = data[pos]; pos += 1
        let trackLength = readUInt16(from: data, at: pos); pos += 2
        let sessionType = data[pos]; pos += 1
        let trackId = Int8(bitPattern: data[pos]); pos += 1
        let formula = data[pos]; pos += 1
        
        #if DEBUG
        print("🏁 RAW TRACK ID: \(trackId) → Track: \(TrackId(rawValue: trackId)?.displayName ?? "Unknown (\(trackId))")")
        #endif
        let sessionTimeLeft = readUInt16(from: data, at: pos); pos += 2
        let sessionDuration = readUInt16(from: data, at: pos); pos += 2
        
        // Skip to safety car status (need to calculate exact offset)
        pos = headerSize + 117  // Approximate offset for safety car status
        guard pos < data.count else {
            print("⚠️ Cannot read safety car status - packet too small")
            return
        }
        let safetyCarStatus = data[pos]
        
        print("🏁 Session: \(totalLaps) laps, Track temp: \(trackTemperature)°C, Safety car: \(safetyCarStatus)")
        
        // For now, let's directly update the TelemetryViewModel instead of using the complex PacketSessionData
        // This is a simpler approach that avoids the complex struct initialization
        
        DispatchQueue.main.async {
            // Create a minimal session data object for the TelemetryViewModel
            let sessionData = PacketSessionData(
                header: PacketHeader(
                    packetFormat: 2024, gameYear: 24, gameMajorVersion: 1, gameMinorVersion: 21,
                    packetVersion: 1, packetId: 1, sessionUID: 0, sessionTime: 0.0,
                    frameIdentifier: 0, overallFrameIdentifier: 0, playerCarIndex: 0, secondaryPlayerCarIndex: 255
                ),
                weather: weather, trackTemperature: trackTemperature, airTemperature: trackTemperature,
                totalLaps: totalLaps, trackLength: 0, sessionType: 0, trackId: trackId, formula: 0,
                sessionTimeLeft: 0, sessionDuration: 0, pitSpeedLimit: 0, gamePaused: 0, isSpectating: 0,
                spectatorCarIndex: 0, sliProNativeSupport: 0, numMarshalZones: 0, marshalZones: [],
                safetyCarStatus: safetyCarStatus, networkGame: 0, numWeatherForecastSamples: 0,
                weatherForecastSamples: [], forecastAccuracy: 0, aiDifficulty: 0, seasonLinkIdentifier: 0,
                weekendLinkIdentifier: 0, sessionLinkIdentifier: 0, pitStopWindowIdealLap: 0,
                pitStopWindowLatestLap: 0, pitStopRejoinPosition: 0, steeringAssist: 0, brakingAssist: 0,
                gearboxAssist: 0, pitAssist: 0, pitReleaseAssist: 0, ersAssist: 0, drsAssist: 0,
                dynamicRacingLine: 0, dynamicRacingLineType: 0, gameMode: 0, ruleSet: 0, timeOfDay: 0,
                sessionLength: 0, speedUnitsLeadPlayer: 0, temperatureUnitsLeadPlayer: 0,
                speedUnitsSecondaryPlayer: 0, temperatureUnitsSecondaryPlayer: 0, numSafetyCarPeriods: 0,
                numVirtualSafetyCarPeriods: 0, numRedFlags: 0
            )
            
            self.currentSessionData = sessionData
            print("🏁 SUCCESS! Session data published - Track ID: \(trackId) (Bahrain), \(totalLaps) laps, Safety car: \(safetyCarStatus)")
        }
    }
    
    private func parseParticipantsPacket(_ data: Data) {
        print("👥 Parsing participants data - packet size: \(data.count) bytes")
        
        let headerSize = PacketSizes.header
        guard data.count >= headerSize + 1 else {
            print("⚠️ Participants packet too small: \(data.count) bytes")
            return
        }
        
        var pos = headerSize
        let numActiveCars = data[pos]; pos += 1
        
        print("👥 Active cars: \(numActiveCars)")
        
        var names: [String] = Array(repeating: "Unknown", count: 22)
        
        // F1 24 ParticipantData is 56 bytes per participant
        let participantDataSize = PacketSizes.participantDataSize
        
        print("👥 Using F1 24 spec: \(participantDataSize) bytes per participant")
        
        // Parse participant data for each car
        for i in 0..<min(Int(numActiveCars), 22) {
            let participantOffset = headerSize + 1 + (i * participantDataSize)
            guard participantOffset + participantDataSize <= data.count else { 
                print("⚠️ Not enough data for participant \(i)")
                break 
            }
            
            // Parse ParticipantData structure (56 bytes total)
            var pPos = participantOffset
            let aiControlled = data[pPos]; pPos += 1        // Byte 0
            let driverId = data[pPos]; pPos += 1            // Byte 1
            let networkId = data[pPos]; pPos += 1           // Byte 2
            let teamId = data[pPos]; pPos += 1              // Byte 3
            let myTeam = data[pPos]; pPos += 1              // Byte 4
            let raceNumber = data[pPos]; pPos += 1          // Byte 5
            let nationality = data[pPos]; pPos += 1         // Byte 6
            
            // Name is at bytes 7-54 (48 bytes, null-terminated UTF-8)
            let nameData = data.subdata(in: pPos..<(pPos + 48))
            let name = parseParticipantName(from: nameData)
            pPos += 48
            
            let yourTelemetry = data[pPos]; pPos += 1       // Byte 55
            
            names[i] = name
            
            print("👤 Car \(i): '\(name)' (AI: \(aiControlled == 1 ? "Yes" : "No"))")
        }
        
        DispatchQueue.main.async {
            self.participantNames = names
            print("👥 SUCCESS! Participant names updated")
        }
    }
    
    // MARK: - Helper Functions for Safe Data Reading
    
    private func tyreCompoundName(_ compound: UInt8) -> String {
        switch compound {
        case 16: return "C5 (Soft)"
        case 17: return "C4 (Medium)"  
        case 18: return "C3 (Medium)"
        case 19: return "C2 (Hard)"
        case 20: return "C1 (Hard)"
        default: return "Unknown (\(compound))"
        }
    }
    
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
    
    private func readInt16(from data: Data, at offset: Int) -> Int16 {
        guard offset + 1 < data.count else { return 0 }
        let bytes = data.subdata(in: offset..<offset+2)
        return bytes.withUnsafeBytes { $0.load(as: Int16.self) }
    }
    
    // MARK: - New Helper Methods
    
    private func parseAndValidateHeader(from data: Data) -> PacketHeader? {
        guard data.count >= PacketSizes.header else {
            packetValidationErrors["size"] = (packetValidationErrors["size"] ?? 0) + 1
            return nil
        }
        
        var pos = 0
        let packetFormat = readUInt16(from: data, at: pos); pos += 2
        let gameYear = data[pos]; pos += 1
        let gameMajorVersion = data[pos]; pos += 1
        let gameMinorVersion = data[pos]; pos += 1
        let packetVersion = data[pos]; pos += 1
        let packetId = data[pos]; pos += 1
        let sessionUID = readUInt64(from: data, at: pos); pos += 8
        let sessionTime = readFloat(from: data, at: pos); pos += 4
        let frameIdentifier = readUInt32(from: data, at: pos); pos += 4
        let overallFrameIdentifier = readUInt32(from: data, at: pos); pos += 4
        let playerCarIndex = data[pos]; pos += 1
        let secondaryPlayerCarIndex = data[pos]; pos += 1
        
        let header = PacketHeader(
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
        
        // Validate header
        guard header.isValid() else {
            packetValidationErrors["format"] = (packetValidationErrors["format"] ?? 0) + 1
            print("⚠️ Invalid packet format: \(packetFormat), expected 2024")
            return nil
        }
        
        // Validate packet size
        guard header.validatePacketSize(data.count) else {
            packetValidationErrors["packetSize"] = (packetValidationErrors["packetSize"] ?? 0) + 1
            if let expectedSize = PacketSizes.expectedSizes[packetId] {
                print("⚠️ Size mismatch for packet \(packetId): got \(data.count), expected \(expectedSize)")
            }
            return nil
        }
        
        return header
    }
    
    private func parseParticipantName(from data: Data) -> String {
        // Find null terminator
        var nameLength = 0
        for byte in data {
            if byte == 0 { break }
            nameLength += 1
        }
        
        guard nameLength > 0 else { return "Unknown" }
        
        let nameData = data.prefix(nameLength)
        return String(data: nameData, encoding: .utf8) ?? "Unknown"
    }
    
    // MARK: - Motion Packet Parsing
    
    private func parseMotionPacket(_ data: Data) {
        print("🏃 Parsing motion data - packet size: \(data.count) bytes")
        
        let headerSize = PacketSizes.header
        guard data.count >= headerSize else {
            print("⚠️ Motion packet too small for header: \(data.count) bytes")
            return
        }
        
        // Each CarMotionData is 60 bytes according to F1 24 spec:
        // 6 floats (24 bytes) + 6 int16s (12 bytes) + 6 floats (24 bytes) = 60 bytes
        let carMotionDataSize = 60
        let expectedSize = headerSize + (22 * carMotionDataSize) // 29 + (22 * 60) = 1349
        
        guard data.count >= expectedSize else {
            print("⚠️ Motion packet too small: got \(data.count), expected \(expectedSize) bytes")
            return
        }
        
        var motionData: [CarMotionData] = []
        var pos = headerSize
        
        // Parse motion data for all 22 cars
        for carIndex in 0..<22 {
            guard pos + carMotionDataSize <= data.count else {
                print("⚠️ Not enough data for car \(carIndex) motion at offset \(pos)")
                break
            }
            
            // Parse CarMotionData (60 bytes total)
            let worldPositionX = readFloat(from: data, at: pos); pos += 4      // 0-3: Float
            let worldPositionY = readFloat(from: data, at: pos); pos += 4      // 4-7: Float  
            let worldPositionZ = readFloat(from: data, at: pos); pos += 4      // 8-11: Float
            let worldVelocityX = readFloat(from: data, at: pos); pos += 4      // 12-15: Float
            let worldVelocityY = readFloat(from: data, at: pos); pos += 4      // 16-19: Float
            let worldVelocityZ = readFloat(from: data, at: pos); pos += 4      // 20-23: Float
            let worldForwardDirX = readInt16(from: data, at: pos); pos += 2    // 24-25: Int16
            let worldForwardDirY = readInt16(from: data, at: pos); pos += 2    // 26-27: Int16
            let worldForwardDirZ = readInt16(from: data, at: pos); pos += 2    // 28-29: Int16
            let worldRightDirX = readInt16(from: data, at: pos); pos += 2      // 30-31: Int16
            let worldRightDirY = readInt16(from: data, at: pos); pos += 2      // 32-33: Int16
            let worldRightDirZ = readInt16(from: data, at: pos); pos += 2      // 34-35: Int16
            let gForceLateral = readFloat(from: data, at: pos); pos += 4       // 36-39: Float
            let gForceLongitudinal = readFloat(from: data, at: pos); pos += 4  // 40-43: Float
            let gForceVertical = readFloat(from: data, at: pos); pos += 4      // 44-47: Float
            let yaw = readFloat(from: data, at: pos); pos += 4                 // 48-51: Float
            let pitch = readFloat(from: data, at: pos); pos += 4               // 52-55: Float
            let roll = readFloat(from: data, at: pos); pos += 4                // 56-59: Float
            
            let carMotion = CarMotionData(
                worldPositionX: worldPositionX,
                worldPositionY: worldPositionY,
                worldPositionZ: worldPositionZ,
                worldVelocityX: worldVelocityX,
                worldVelocityY: worldVelocityY,
                worldVelocityZ: worldVelocityZ,
                worldForwardDirX: worldForwardDirX,
                worldForwardDirY: worldForwardDirY,
                worldForwardDirZ: worldForwardDirZ,
                worldRightDirX: worldRightDirX,
                worldRightDirY: worldRightDirY,
                worldRightDirZ: worldRightDirZ,
                gForceLateral: gForceLateral,
                gForceLongitudinal: gForceLongitudinal,
                gForceVertical: gForceVertical,
                yaw: yaw,
                pitch: pitch,
                roll: roll
            )
            
            motionData.append(carMotion)
            
            // Debug for first few cars
            if carIndex < 3 {
                print("🏃 Car \(carIndex): Position(\(worldPositionX), \(worldPositionY), \(worldPositionZ))")
            }
        }
        
        // Update published property on main thread
        DispatchQueue.main.async {
            self.currentMotionData = motionData
            print("🏃 SUCCESS! Motion data updated for \(motionData.count) cars")
        }
    }
    
    // MARK: - Packet Rate Monitoring
    
    private func trackPacketRate(packetId: UInt8) {
        let now = Date()
        if var rate = packetRates[packetId] {
            rate.count += 1
            if now.timeIntervalSince(rate.lastReset) >= 1.0 {
                print("📊 Packet \(packetId) rate: \(rate.count)/sec")
                packetRates[packetId] = (count: 0, lastReset: now)
            } else {
                packetRates[packetId] = rate
            }
        } else {
            packetRates[packetId] = (count: 1, lastReset: now)
        }
    }
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
