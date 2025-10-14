import Foundation
import Combine

// Driver data model for leaderboard
struct DriverData {
    let position: Int
    let name: String
    let status: String
    let pitStops: Int
    let sector1Time: String
    let sector2Time: String
    let sector3Time: String
    let delta: String
    let penalty: String
}

struct LapSpeedPoint: Identifiable, Hashable {
    let id = UUID()
    let time: Double
    let speed: Double
}

class TelemetryViewModel: ObservableObject {
    // Connection status
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var packetsReceived: Int = 0
    @Published var lastUpdate: Date?
    
    // Interpolation and smoothing
    private var interpolationTimer: Timer?
    private var lastTelemetryUpdate: Date?
    private let smoothingFactor: Double = 0.15  // EMA smoothing factor
    
    // Dashboard data
    @Published var speed: Int = 0           // km/h
    @Published var gear: Int = 0            // Current gear (N=0, R=-1, 1-8)
    @Published var rpm: Double = 0          // Current RPM
    @Published var maxRPM: Double = 15000   // Maximum RPM for gauge scaling
    @Published var ersCharge: Double = 0    // ERS energy in Joules
    @Published var maxERS: Double = 4000000 // Maximum ERS energy (4MJ)
    
    // Raw values for interpolation
    private var rawSpeed: Double = 0
    private var rawRPM: Double = 0
    private var rawERS: Double = 0
    @Published var throttlePercent: Double = 0.0  // 0.0 to 1.0
    @Published var brakePercent: Double = 0.0     // 0.0 to 1.0
    @Published var steerPercent: Double = 0.0     // -1.0 to 1.0
    @Published var isDRSActive: Bool = false
    @Published var isDRSAvailable: Bool = false
    
    // Additional telemetry data
    @Published var engineTemperature: Int = 0
    @Published var fuelInTank: Float = 0.0
    @Published var fuelCapacity: Float = 0.0
    @Published var tyreCompound: String = "Unknown"
    @Published var tyreAge: Int = 0
    
    // Temperature data for car condition
    @Published var brakesTemperature: [UInt16] = [0, 0, 0, 0] // [RL, RR, FL, FR]
    @Published var tyresSurfaceTemperature: [UInt8] = [0, 0, 0, 0] // [RL, RR, FL, FR]
    
    // Car damage data
    @Published var tyresDamage: [Float] = [0.0, 0.0, 0.0, 0.0]  // [RL, RR, FL, FR]
    @Published var engineDamage: UInt8 = 0
    @Published var gearBoxDamage: UInt8 = 0
    @Published var frontLeftWingDamage: Int8 = 0
    @Published var frontRightWingDamage: Int8 = 0
    @Published var rearWingDamage: Int8 = 0
    @Published var floorDamage: Int8 = 0
    @Published var diffuserDamage: Int8 = 0
    @Published var sidepodDamage: Int8 = 0
    
    // Splits and lap timing data
    @Published var currentLapTime: Float = -1.0  // -1 indicates no data
    @Published var sector1Time: Float = -1.0     // -1 indicates no data
    @Published var sector2Time: Float = -1.0     // -1 indicates no data
    @Published var sector3Time: Float = -1.0     // -1 indicates no data
    @Published var lastLapTime: Float = -1.0     // -1 indicates no data
    @Published var bestLapTime: Float = -1.0     // -1 indicates no data
    @Published var bestLapPoints: [LapSpeedPoint] = []
    @Published var currentLapPoints: [LapSpeedPoint] = []
    
    // Leaderboard data
    @Published var leaderboardData: [DriverData] = []
    @Published var isAI: [Bool] = Array(repeating: true, count: 22)
    @Published var currentLap: Int = 0
    @Published var totalLaps: Int = 0
    @Published var safetyCarStatus: String = "None"
    
    // Track overview data
    @Published var trackId: Int8 = -1           // Current track ID
    @Published var trackTemperature: Int8 = 0   // Track temperature in Celsius
    @Published var weather: UInt8 = 0           // Weather condition (0=clear, 1=light cloud, etc.)
    @Published var rainIntensity: UInt8 = 0     // Rain intensity/percentage
    @Published var lapProgress: Float = 0.0     // Current lap progress (0.0 to 1.0)
    
    // Car position data from motion packets
    @Published var carPositions: [CGPoint] = Array(repeating: .zero, count: 22)  // World positions for all cars
    @Published var carProgresses: [Float] = Array(repeating: 0.0, count: 22)     // Track progress for all cars
    @Published var carLapDistances: [Float] = Array(repeating: 0.0, count: 22)
    @Published var carDriverCodes: [String] = Array(repeating: "", count: 22)
    @Published var trackLengthMetres: Float = 0.0
    
    // MARK: - Coordinate Transform State
    private var worldMin = CGPoint(x: CGFloat.infinity, y: CGFloat.infinity)
    private var worldMax = CGPoint(x: -CGFloat.infinity, y: -CGFloat.infinity)
    private var alignmentIsSolved = false
    private var worldToGeom: CGAffineTransform = .identity
    private var currentTrackIdForAlignment: Int8 = -1
    private var worldSampleCount = 0
    private let minSamplesForAlignment = 100
    
    private var telemetryReceiver: SimpleTelemetryReceiver
    private var cancellables = Set<AnyCancellable>()
    private var currentLapElapsedSeconds: Double = 0
    private var currentLapNumber: Int = 0
    private var lastSampledTime: Double = -1
    private var lapStartDate: Date?
    private let maxSamplesPerLap = 1500
    private let minLapSampleInterval: Double = 0.15
    private var bestLapTimeSeconds: Double = .infinity
    
    init() {
        self.telemetryReceiver = SimpleTelemetryReceiver(port: 20777)
        setupBindings()
    }
    
    private func setupBindings() {
        // Connection status
        telemetryReceiver.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateConnectionStatus(status)
            }
            .store(in: &cancellables)
        
        // Packets received counter
        telemetryReceiver.$packetsReceived
            .receive(on: DispatchQueue.main)
            .assign(to: \.packetsReceived, on: self)
            .store(in: &cancellables)
        
        // Last packet time
        telemetryReceiver.$lastPacketTime
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastUpdate, on: self)
            .store(in: &cancellables)
        
        // Car telemetry data
        telemetryReceiver.$currentTelemetry
            .receive(on: DispatchQueue.main)
            .sink { [weak self] telemetry in
                self?.updateTelemetryData(telemetry)
            }
            .store(in: &cancellables)
        
        // Car status data (includes ERS)
        telemetryReceiver.$currentStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateStatusData(status)
            }
            .store(in: &cancellables)
        
        // Car damage data
        telemetryReceiver.$currentCarDamage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] damage in
                self?.updateCarDamage(damage)
            }
            .store(in: &cancellables)
        
        // Lap data (includes splits timing)
        telemetryReceiver.$currentLapData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lapData in
                self?.updateLapData(lapData)
            }
            .store(in: &cancellables)

        telemetryReceiver.$driverCodes
            .receive(on: DispatchQueue.main)
            .assign(to: \.carDriverCodes, on: self)
            .store(in: &cancellables)

        telemetryReceiver.$allLapData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] allLapData in
                guard let self else { return }
                if !allLapData.isEmpty {
                    self.carLapDistances = allLapData.map { $0.lapDistance }
                }
                self.updateLeaderboard(allLapData)
            }
            .store(in: &cancellables)
        
        // Participant names
        telemetryReceiver.$participantNames
            .receive(on: DispatchQueue.main)
            .sink { [weak self] names in
                self?.updateParticipantNames(names)
            }
            .store(in: &cancellables)
        
        // AI flags
        telemetryReceiver.$isAI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] aiFlags in
                self?.updateAIFlags(aiFlags)
            }
            .store(in: &cancellables)
        
        // Subscribe to session data for total laps and safety car status
        telemetryReceiver.$currentSessionData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionData in
                self?.updateSessionData(sessionData)
            }
            .store(in: &cancellables)
        
        telemetryReceiver.$currentMotionData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] motionData in
                self?.updateMotionData(motionData)
            }
            .store(in: &cancellables)
    }
    
    func connect() {
        print("🔌 TelemetryViewModel: Starting connection...")
        telemetryReceiver.startReceiving()
        startInterpolation()
        
        // Preload common track geometries to prevent flicker
        TrackGeometryCache.shared.preloadCommonTracks()
        
        #if DEBUG
        print("🎯 TELEMETRY CONNECTED: Speed tile will show speedMPH=\(speedMPH)")
        #endif
        
    }
    
    func disconnect() {
        telemetryReceiver.stopReceiving()
        stopInterpolation()
        cancellables.removeAll()
    }
    
    private func updateConnectionStatus(_ status: SimpleTelemetryReceiver.ConnectionStatus) {
        switch status {
        case .disconnected:
            isConnected = false
            connectionStatus = "Disconnected"
        case .connecting:
            isConnected = false
            connectionStatus = "Connecting..."
        case .connected:
            isConnected = true
            connectionStatus = "Connected"
        case .failed(let error):
            isConnected = false
            connectionStatus = "Failed: \(error.localizedDescription)"
        }
    }
    
    private func updateTelemetryData(_ telemetry: CarTelemetryData?) {
        guard let telemetry = telemetry else { 
            #if DEBUG
            print("📊 No telemetry data received")
            #endif
            return 
        }
        
        #if DEBUG
        print("🎯 Updating UI with telemetry: Speed=\(telemetry.speed)km/h, RPM=\(telemetry.engineRPM), Gear=\(telemetry.gear)")
        #endif
        
        // Update raw values with clamping for interpolation
        let newRawSpeed = Self.clamp(Double(telemetry.speed), min: 0.0, max: 400.0)
        let newRawRPM = Self.clamp(Double(telemetry.engineRPM), min: 0.0, max: 20000.0)
        
        #if DEBUG
        if abs(newRawSpeed - rawSpeed) > 1.0 {
            print("🏎️ SPEED UPDATE: \(Int(rawSpeed))km/h → \(Int(newRawSpeed))km/h (\(speedMPH)mph)")
        }
        #endif
        
        rawSpeed = newRawSpeed
        rawRPM = newRawRPM

        // Direct updates for non-interpolated values
        gear = Self.clamp(Int(telemetry.gear), min: -1, max: 8)
        engineTemperature = Self.clamp(Int(telemetry.engineTemperature), min: 0, max: 200)

        // Clamp control inputs
        throttlePercent = Self.clamp(Double(telemetry.throttle), min: 0.0, max: 1.0)
        brakePercent = Self.clamp(Double(telemetry.brake), min: 0.0, max: 1.0)
        steerPercent = Self.clamp(Double(telemetry.steer), min: -1.0, max: 1.0)
        isDRSActive = telemetry.drs > 0

        lastTelemetryUpdate = Date()

        // Clamp values to valid ranges
        throttlePercent = max(0.0, min(1.0, throttlePercent))
        brakePercent = max(0.0, min(1.0, brakePercent))
        steerPercent = max(-1.0, min(1.0, steerPercent))

        let safeRPM = max(0, min(Int.max, Int(rpm.isFinite ? rpm : 0)))
        let safeThrottle = max(0, min(100, Int((throttlePercent*100).isFinite ? throttlePercent*100 : 0)))
        let safeBrake = max(0, min(100, Int((brakePercent*100).isFinite ? brakePercent*100 : 0)))
        print("🎮 UI Values: Speed=\(speedMPH)mph, RPM=\(safeRPM), Gear=\(gear), Throttle=\(safeThrottle)%, Brake=\(safeBrake)%")

        updateLapSpeedSeries(withSpeed: newRawSpeed)
    }
    
    private func updateStatusData(_ status: CarStatusData?) {
        guard let status = status else { 
            print("⚠️ ERS UPDATE: No status data received")
            return 
        }
        
        // Update raw ERS with clamping
        rawERS = Self.clamp(Double(status.ersStoreEnergy), min: 0, max: 4000000)
        print("🔋 ERS UPDATE: Raw=\(status.ersStoreEnergy)J, Stored=\(Int(rawERS / 1000))kJ, UI=\(Int(ersValue * 100))%")
        
        // Update fuel data
        fuelInTank = status.fuelInTank
        fuelCapacity = status.fuelCapacity
        
        // Update maximum RPM for accurate gauge scaling
        if status.maxRPM > 0 {
            maxRPM = Double(status.maxRPM)
        }
        
        // Update DRS availability
        isDRSAvailable = status.drsAllowed > 0
        
        // Update tyre information
        tyreAge = Int(status.tyresAgeLaps)
        tyreCompound = getTyreCompoundName(status.visualTyreCompound)
    }
    
    private func updateCarDamage(_ damage: CarDamageData?) {
        guard let damage = damage else {
            print("⚠️ DAMAGE UPDATE: No damage data received")
            return
        }
        
        // Update damage data with clamping
        tyresDamage = damage.tyresDamage.map { Self.clamp($0, min: 0.0, max: 100.0) }
        engineDamage = Self.clamp(damage.engineDamage, min: 0, max: 100)
        gearBoxDamage = Self.clamp(damage.gearBoxDamage, min: 0, max: 100)
        frontLeftWingDamage = Self.clamp(damage.frontLeftWingDamage, min: -100, max: 100)
        frontRightWingDamage = Self.clamp(damage.frontRightWingDamage, min: -100, max: 100)
        rearWingDamage = Self.clamp(damage.rearWingDamage, min: -100, max: 100)
        floorDamage = Self.clamp(damage.floorDamage, min: -100, max: 100)
        diffuserDamage = Self.clamp(damage.diffuserDamage, min: -100, max: 100)
        sidepodDamage = Self.clamp(damage.sidepodDamage, min: -100, max: 100)
        
        print("🔧 DAMAGE UPDATE: Engine=\(engineDamage)%, Gearbox=\(gearBoxDamage)%, Wings=[FL:\(frontLeftWingDamage)%, FR:\(frontRightWingDamage)%, R:\(rearWingDamage)%]")
        print("🔧 TYRE DAMAGE UPDATE: RL=\(String(format: "%.1f", tyresDamage[0]))%, RR=\(String(format: "%.1f", tyresDamage[1]))%, FL=\(String(format: "%.1f", tyresDamage[2]))%, FR=\(String(format: "%.1f", tyresDamage[3]))%")
    }
    
    private func updateLapData(_ lapData: LapData?) {
        guard let lapData = lapData else { return }
        
        // Convert milliseconds to seconds for display
        currentLapTime = Float(lapData.currentLapTimeInMS) / 1000.0
        lastLapTime = Float(lapData.lastLapTimeInMS) / 1000.0
        
        // Convert sector times (milliseconds + minutes) to seconds
        sector1Time = Float(lapData.sector1TimeInMS) / 1000.0 + Float(lapData.sector1TimeMinutes) * 60.0
        sector2Time = Float(lapData.sector2TimeInMS) / 1000.0 + Float(lapData.sector2TimeMinutes) * 60.0
        
        // For now, we don't have sector 3 time directly, so we'll calculate it or leave it as mock
        // sector3Time would need to be calculated from total lap time - sector1 - sector2
        
        // Debug the raw values
        print("🏁 LAP DATA DEBUG:")
        print("   Raw Current Lap MS: \(lapData.currentLapTimeInMS)")
        print("   Raw Last Lap MS: \(lapData.lastLapTimeInMS)")
        print("   Raw Sector 1 MS: \(lapData.sector1TimeInMS), Minutes: \(lapData.sector1TimeMinutes)")
        print("   Raw Sector 2 MS: \(lapData.sector2TimeInMS), Minutes: \(lapData.sector2TimeMinutes)")
        
        // Calculate lap progress from lap distance
        // lapDistance is the distance around the current lap in metres
        // We need track length to calculate progress, but for now use a rough estimate
        let estimatedTrackLength: Float = 5000.0 // Average F1 track length in meters
        if lapData.lapDistance > 0 {
            lapProgress = min(1.0, max(0.0, lapData.lapDistance / estimatedTrackLength))
        }
        
        let lapNumber = Int(lapData.currentLapNum)
        if currentLapNumber == 0 {
            currentLapNumber = lapNumber
        }

        if lapNumber != currentLapNumber {
            let finishedLapSeconds = Double(lapData.lastLapTimeInMS) / 1000.0
            finalizeLapIfNeeded(lastLapSeconds: finishedLapSeconds)
            currentLapPoints = []
            currentLapElapsedSeconds = 0
            lastSampledTime = -1
            currentLapNumber = lapNumber
            lapStartDate = Date()
        }

        if let lapStartDate {
            currentLapElapsedSeconds = Date().timeIntervalSince(lapStartDate)
        } else {
            currentLapElapsedSeconds = Double(lapData.currentLapTimeInMS) / 1000.0
            lapStartDate = Date().addingTimeInterval(-currentLapElapsedSeconds)
        }

        if bestLapTimeSeconds.isFinite {
            bestLapTime = Float(bestLapTimeSeconds)
        } else {
            bestLapTime = -1
        }

        print("🏁 LAP DATA UPDATE:")
        print("   Current Lap: \(formatTime(currentLapTime))")
        print("   Last Lap: \(formatTime(lastLapTime))")
        print("   Sector 1: \(formatTime(sector1Time))")
        print("   Sector 2: \(formatTime(sector2Time))")
        print("   Lap Progress: \(String(format: "%.1f%%", lapProgress * 100))")
    }

    private func finalizeLapIfNeeded(lastLapSeconds: Double) {
        guard lastLapSeconds > 0 else { return }
        let finishedLapPoints = currentLapPoints
        guard !finishedLapPoints.isEmpty else { return }

        if lastLapSeconds < bestLapTimeSeconds {
            bestLapTimeSeconds = lastLapSeconds
            bestLapPoints = finishedLapPoints
            bestLapTime = Float(lastLapSeconds)
        }
    }

    private func updateLapSpeedSeries(withSpeed speedKMH: Double) {
        guard currentLapElapsedSeconds >= 0 else { return }
        let clampedSpeed = max(0, min(speedKMH, 400))
        guard clampedSpeed > 0 else { return }

        let sampleTime = currentLapElapsedSeconds
        guard sampleTime.isFinite else { return }

        if lastSampledTime >= 0, sampleTime - lastSampledTime < minLapSampleInterval {
            return
        }

        if currentLapPoints.count >= maxSamplesPerLap {
            currentLapPoints.removeFirst()
        }

        let point = LapSpeedPoint(time: sampleTime, speed: clampedSpeed)
        currentLapPoints.append(point)
        lastSampledTime = sampleTime
    }
    
    private func getTyreCompoundName(_ compound: UInt8) -> String {
        switch compound {
        case 16: return "C5 (Soft)"
        case 17: return "C4 (Medium)"
        case 18: return "C3 (Medium)"
        case 19: return "C2 (Hard)"
        case 20: return "C1 (Hard)"
        case 7: return "Inter"
        case 8: return "Wet"
        default: return "Unknown"
        }
    }
    
    // Computed properties for UI
    var rpmValue: Double {
        guard maxRPM > 0 else { return 0.0 }
        return min(1.0, rpm / maxRPM)
    }
    
    var ersValue: Double {
        guard maxERS > 0 else { return 0.0 }
        return min(1.0, ersCharge / maxERS)
    }
    
    var speedMPH: Int {
        let mph = Double(speed) * 0.621371
        return max(0, min(Int.max, Int(mph.isFinite ? mph : 0))) // Convert km/h to mph safely
    }
    
    var fuelPercentage: Double {
        guard fuelCapacity > 0 else { return 0.0 }
        return min(1.0, Double(fuelInTank) / Double(fuelCapacity))
    }
    
    // Helper function to format time in MM:SS.mmm format
    func formatTime(_ timeInSeconds: Float) -> String {
        guard timeInSeconds > 0 && timeInSeconds.isFinite else { return "--:--.---" }
        
        let minutes = Int(timeInSeconds) / 60
        let seconds = timeInSeconds.truncatingRemainder(dividingBy: 60)
        
        return String(format: "%d:%06.3f", minutes, seconds)
    }
    
    private func updateLeaderboard(_ allLapData: [LapData]) {
        guard !allLapData.isEmpty else { return }
        
        // Create leaderboard data from lap data
        var newLeaderboardData: [DriverData] = []
        
        for (index, lapData) in allLapData.enumerated() {
            // Get driver name with fallback
            let driverName = getDriverName(for: index)
            
            let status = getDriverStatus(lapData.driverStatus)
            let delta = formatDelta(lapData.deltaToRaceLeaderInMS)
            let penalty = lapData.penalties > 0 ? "▲" : "-"
            
            let sector1 = formatSectorTime(Float(lapData.sector1TimeInMS) / 1000.0 + Float(lapData.sector1TimeMinutes) * 60.0)
            let sector2 = formatSectorTime(Float(lapData.sector2TimeInMS) / 1000.0 + Float(lapData.sector2TimeMinutes) * 60.0)
            let sector3 = "-:-:-"  // Sector 3 time calculation would need additional data
            
            // Use gridPosition before race starts, carPosition during race
            let racePosition = getRacePosition(lapData: lapData)
            
            let driver = DriverData(
                position: racePosition,
                name: driverName,
                status: status,
                pitStops: Int(lapData.numPitStops),
                sector1Time: sector1,
                sector2Time: sector2,
                sector3Time: sector3,
                delta: delta,
                penalty: penalty
            )
            
            newLeaderboardData.append(driver)
        }
        
        // Filter out invalid positions and sort by race position
        // F1 positions should be 1-22, but temporarily allow 0 for debugging
        let validDrivers = newLeaderboardData.filter { driver in
            driver.position >= 0 && driver.position <= 22 && driver.position != 255
        }
        
        // Sort by race position with fallback for position=0
        let sortedDrivers = validDrivers.sorted { driver1, driver2 in
            guard driver1.position > 0 else { return false }
            guard driver2.position > 0 else { return true }
            return driver1.position < driver2.position
        }
        
        print("🏁 LEADERBOARD SORTING: Found \(validDrivers.count) drivers with valid positions")
        for driver in sortedDrivers.prefix(5) {
            print("   P\(driver.position): \(driver.name)")
        }
        
        newLeaderboardData = sortedDrivers
        
        self.leaderboardData = newLeaderboardData
        
        // Update current lap and total laps from player data
        if let playerData = allLapData.first {
            self.currentLap = Int(playerData.currentLapNum)
        }
        
        print("🏁 Leaderboard updated with \(newLeaderboardData.count) drivers")
        
        // Debug first few drivers
        for (i, driver) in newLeaderboardData.prefix(3).enumerated() {
            print("   Driver \(i): Pos=\(driver.position), Name='\(driver.name)', Status=\(driver.status)")
        }
    }
    
    private func updateParticipantNames(_ names: [String]) {
        // Names are automatically used in updateLeaderboard
        print("👥 Participant names updated: \(names.prefix(5).joined(separator: ", "))...")
    }
    
    private func updateAIFlags(_ aiFlags: [Bool]) {
        self.isAI = aiFlags
        let humanCount = aiFlags.filter { !$0 }.count
        print("🤖 AI flags updated: \(humanCount) human(s), \(22 - humanCount) AI")
    }
    
    private func updateSessionData(_ sessionData: PacketSessionData?) {
        guard let sessionData = sessionData else { 
            #if DEBUG
            print("⚠️ SESSION DATA IS NIL - trackId may become invalid")
            #endif
            return 
        }
        
        // Update session information for leaderboard
        totalLaps = Int(sessionData.totalLaps)
        safetyCarStatus = getSafetyCarStatus(sessionData.safetyCarStatus)
        
        // Update track overview data
        let newTrackId = sessionData.trackId
        #if DEBUG
        print("🏁 SESSION UPDATE: Raw trackId=\(newTrackId), Current trackId=\(trackId)")
        #endif
        
        if trackId != newTrackId {
            #if DEBUG
            print("🏁 TRACK ID CHANGED: \(trackId) → \(newTrackId) → Track: \(TrackId(rawValue: newTrackId)?.displayName ?? "Unknown (\(newTrackId))")")
            #endif
            trackId = newTrackId
        }
        
        trackTemperature = sessionData.trackTemperature
        weather = sessionData.weather
        trackLengthMetres = Float(sessionData.trackLength)
        if trackId == -1 {
            trackId = TrackId.britain.rawValue
        }
        
        // Calculate rain intensity from weather forecast if available
        if !sessionData.weatherForecastSamples.isEmpty {
            rainIntensity = sessionData.weatherForecastSamples[0].rainPercentage
        } else {
            // Estimate rain from current weather
            rainIntensity = estimateRainFromWeather(sessionData.weather)
        }
        
        #if DEBUG
        print("🏁 SESSION DATA UPDATE: Total Laps=\(totalLaps), Safety Car=\(safetyCarStatus)")
        print("🌡️ TRACK DATA: ID=\(trackId), Temp=\(trackTemperature)°C, Weather=\(weather), Rain=\(rainIntensity)mm")
        #endif
    }
    
    private func updateMotionData(_ motionData: [CarMotionData]) {
        guard !motionData.isEmpty else { return }
        
        var newPositions: [CGPoint] = []
        var newProgresses: [Float] = []
        
        for (index, carMotion) in motionData.enumerated() {
            // Store world position (X, Z coordinates - Y is vertical)
            let worldPosition = CGPoint(
                x: CGFloat(carMotion.worldPositionX),
                y: CGFloat(carMotion.worldPositionZ)  // Use Z for 2D track representation
            )
            newPositions.append(worldPosition)
            
            // Calculate track progress using TrackProjector
            let progress = calculateTrackProgress(from: worldPosition)
            newProgresses.append(progress)
            
            #if DEBUG
            // Log first few cars for debugging coordinate transformation
            if index < 3 {
                print("🏎️ Car \(index): F1 World(\(carMotion.worldPositionX), \(carMotion.worldPositionZ)) → Progress: \(progress)")
            }
            #endif
        }
        
        // Update published properties
        carPositions = newPositions
        carProgresses = newProgresses
        
        #if DEBUG
        if motionData.count > 0 {
            let car0 = motionData[0]
            print("🏃 MOTION UPDATE: Car 0 at (\(car0.worldPositionX), \(car0.worldPositionZ)), Progress: \(newProgresses[0])")
        }
        #endif
    }
    
    private func calculateTrackProgress(from worldPosition: CGPoint) -> Float {
        guard let projector = trackProjector(for: self.trackId) else { return 0.0 }
        
        // Project world position using cached projector for current track
        return projectWorldPositionToTrack(worldPosition: worldPosition, projector: projector)
    }
    
    private func projectWorldPositionToTrack(worldPosition: CGPoint, projector: TrackProjector) -> Float {
        // Transform world coordinates to track-relative coordinates
        let transformedPosition = transformWorldToTrackCoordinates(worldPosition: worldPosition)
        
        // Use cached TrackProjector for robust projection with coarse sampling + refinement
        let progress = projector.projectGeometryPointToProgress(transformedPosition)
        
        return Float(progress)
    }

    private func trackProjector(for trackId: Int8) -> TrackProjector? {
        let resolvedTrackId = TrackId(rawValue: trackId) ?? .britain
        let geometry = TrackGeometryCache.shared.geometry(for: resolvedTrackId)
        return TrackProjector(trackGeometry: TrackGeometryImpl(geometry: geometry))
    }
    
    private func transformWorldToTrackCoordinates(worldPosition: CGPoint) -> CGPoint {
        let currentTrackId = TrackId(rawValue: self.trackId) ?? .britain
        let geometry = TrackGeometryCache.shared.geometry(for: currentTrackId)
        
        // Reset alignment if track changed
        if self.trackId != currentTrackIdForAlignment {
            resetAlignment()
            currentTrackIdForAlignment = self.trackId
        }
        
        // Collect world coordinate samples for alignment
        if !alignmentIsSolved {
            collectWorldSample(worldPosition)
            
            // Try to solve alignment once we have enough samples
            if worldSampleCount >= minSamplesForAlignment {
                solveWorldToGeometryTransform(geometry: geometry)
            }
        }
        
        // Apply the transform (identity if not yet solved)
        let result = worldPosition.applying(worldToGeom)
        
        #if DEBUG
        if worldSampleCount < 5 || worldSampleCount % 50 == 0 {
            let bounds = geometry.bounds
            print("🌍 F1 WORLD: (\(worldPosition.x), \(worldPosition.y)) → GEOM: (\(result.x), \(result.y)) [samples: \(worldSampleCount), solved: \(alignmentIsSolved)]")
            print("📐 GEOM BOUNDS: (\(bounds.minX), \(bounds.minY)) to (\(bounds.maxX), \(bounds.maxY)) [\(bounds.width) x \(bounds.height)]")
        }
        #endif
        
        return result
    }
    
    private func resetAlignment() {
        worldMin = CGPoint(x: CGFloat.infinity, y: CGFloat.infinity)
        worldMax = CGPoint(x: -CGFloat.infinity, y: -CGFloat.infinity)
        alignmentIsSolved = false
        worldToGeom = .identity
        worldSampleCount = 0
        
        #if DEBUG
        print("🔄 COORDINATE ALIGNMENT RESET for track \(trackId)")
        #endif
    }
    
    private func collectWorldSample(_ worldPosition: CGPoint) {
        guard worldPosition.x.isFinite && worldPosition.y.isFinite else { return }
        
        worldMin.x = min(worldMin.x, worldPosition.x)
        worldMin.y = min(worldMin.y, worldPosition.y)
        worldMax.x = max(worldMax.x, worldPosition.x)
        worldMax.y = max(worldMax.y, worldPosition.y)
        worldSampleCount += 1
    }
    
    private func solveWorldToGeometryTransform(geometry: PolylineGeometry) -> CGFloat {
        let g = geometry.bounds
        guard worldMin.x.isFinite, worldMax.x.isFinite,
              worldMin.y.isFinite, worldMax.y.isFinite else {
            #if DEBUG
            print("⚠️ ALIGNMENT FAILED: Invalid world bounds")
            #endif
            return .greatestFiniteMagnitude
        }
        
        let w = CGRect(
            x: worldMin.x, y: worldMin.y,
            width: worldMax.x - worldMin.x,
            height: worldMax.y - worldMin.y
        )
        
        guard w.width > 1.0 && w.height > 1.0 else {
            #if DEBUG
            print("⚠️ ALIGNMENT FAILED: World bounds too small (\(w.width) x \(w.height))")
            #endif
            return .greatestFiniteMagnitude
        }
        
        #if DEBUG
        print("🎯 SOLVING ALIGNMENT:")
        print("   World bounds: (\(w.minX), \(w.minY)) to (\(w.maxX), \(w.maxY)) [\(w.width) x \(w.height)]")
        print("   Geom bounds:  (\(g.minX), \(g.minY)) to (\(g.maxX), \(g.maxY)) [\(g.width) x \(g.height)]")
        #endif
        
        // Try 4 rotation candidates: 0°, 90°, 180°, 270°
        let candidates: [CGAffineTransform] = [
            .identity,                                    // 0°
            CGAffineTransform(rotationAngle: .pi/2),     // 90°
            CGAffineTransform(rotationAngle: .pi),       // 180°
            CGAffineTransform(rotationAngle: 3 * .pi/2), // 270°
        ]
        
        var best: (transform: CGAffineTransform, score: CGFloat) = (.identity, .greatestFiniteMagnitude)
        
        for (index, baseRotation) in candidates.enumerated() {
            // 1) Move world to origin, apply rotation
            var transform = CGAffineTransform(translationX: -w.midX, y: -w.midY)
                .concatenating(baseRotation)
            
            // 2) Calculate rotated bounding box
            let corners = [
                CGPoint(x: -w.width/2, y: -w.height/2).applying(baseRotation),
                CGPoint(x:  w.width/2, y: -w.height/2).applying(baseRotation),
                CGPoint(x: -w.width/2, y:  w.height/2).applying(baseRotation),
                CGPoint(x:  w.width/2, y:  w.height/2).applying(baseRotation),
            ]
            
            let rxMin = corners.map { $0.x }.min()!
            let rxMax = corners.map { $0.x }.max()!
            let ryMin = corners.map { $0.y }.min()!
            let ryMax = corners.map { $0.y }.max()!
            
            let rotatedWidth = rxMax - rxMin
            let rotatedHeight = ryMax - ryMin
            
            // 3) Scale to fit geometry bounds (preserve aspect ratio)
            let scaleX = g.width / max(rotatedWidth, 1e-6)
            let scaleY = g.height / max(rotatedHeight, 1e-6)
            let scale = min(scaleX, scaleY) // Preserve aspect ratio
            
            transform = transform.scaledBy(x: scale, y: scale)
            
            // 4) Translate to geometry center
            transform = transform.translatedBy(x: g.midX, y: g.midY)
            
            // 5) Score this transform by sampling projection error
            let score = sampleProjectionError(transform: transform, geometry: geometry)
            
            #if DEBUG
            print("   Candidate \(index) (\(index * 90)°): scale=\(String(format: "%.3f", scale)), score=\(String(format: "%.1f", score))")
            #endif
            
            if score < best.score {
                best = (transform, score)
            }
        }
        
        worldToGeom = best.transform
        alignmentIsSolved = true
        
        #if DEBUG
        print("✅ ALIGNMENT SOLVED: score=\(best.score)")
        #endif
        return best.score
    }
    
    private func sampleProjectionError(transform: CGAffineTransform, geometry: PolylineGeometry) -> CGFloat {
        let samplePoints = [
            CGPoint(x: worldMin.x, y: worldMin.y),
            CGPoint(x: worldMax.x, y: worldMin.y),
            CGPoint(x: worldMin.x, y: worldMax.y),
            CGPoint(x: worldMax.x, y: worldMax.y),
            CGPoint(x: (worldMin.x + worldMax.x) / 2, y: (worldMin.y + worldMax.y) / 2),
        ]
        
        var totalError: CGFloat = 0
        let trackPoints = geometry.points
        
        for worldPoint in samplePoints {
            let geomPoint = worldPoint.applying(transform)
            
            // Find distance to nearest track point
            var minDistance: CGFloat = .greatestFiniteMagnitude
            for trackPoint in trackPoints {
                let distance = geomPoint.distance(to: trackPoint)
                minDistance = min(minDistance, distance)
            }
            
            totalError += minDistance
        }
        
        return totalError / CGFloat(samplePoints.count)
    }
    
    
    private func getDriverStatus(_ status: UInt8) -> String {
        switch status {
        case 0: return "In garage"
        case 1: return "Flying lap"
        case 2: return "In lap"
        case 3: return "Out lap"
        case 4: return "On track"
        default: return "Unknown"
        }
    }
    
    private func formatDelta(_ deltaMS: UInt16) -> String {
        guard deltaMS > 0 else { return "-" }
        let deltaSeconds = Float(deltaMS) / 1000.0
        return String(format: "+%.3f", deltaSeconds)
    }
    
    private func getSafetyCarStatus(_ status: UInt8) -> String {
        switch status {
        case 0: return "None"
        case 1: return "Safety Car"
        case 2: return "Virtual Safety Car"
        case 3: return "Formation Lap"
        default: return "Unknown"
        }
    }
    
    private func estimateRainFromWeather(_ weather: UInt8) -> UInt8 {
        switch weather {
        case 0, 1, 2: return 0      // Clear, light cloud, overcast - no rain
        case 3: return 2            // Light rain - 2mm
        case 4: return 8            // Heavy rain - 8mm
        case 5: return 15           // Storm - 15mm
        default: return 0
        }
    }
    
    private func getDriverName(for index: Int) -> String {
        // Try to get real name from participants data
        if index < telemetryReceiver.participantNames.count {
            let name = telemetryReceiver.participantNames[index]
            if !name.isEmpty && name != "Unknown" {
                return name
            }
        }
        
        // Fallback to generic driver names
        let fallbackNames = [
            "Driver 1", "Driver 2", "Driver 3", "Driver 4", "Driver 5",
            "Driver 6", "Driver 7", "Driver 8", "Driver 9", "Driver 10",
            "Driver 11", "Driver 12", "Driver 13", "Driver 14", "Driver 15",
            "Driver 16", "Driver 17", "Driver 18", "Driver 19", "Driver 20",
            "Driver 21", "Driver 22"
        ]
        
        return index < fallbackNames.count ? fallbackNames[index] : "Driver \(index + 1)"
    }
    
    private func formatSectorTime(_ timeInSeconds: Float) -> String {
        guard timeInSeconds > 0 && timeInSeconds.isFinite else { return "-:-:-" }
        
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        let milliseconds = Int((timeInSeconds.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%d:%02d:%03d", minutes, seconds, milliseconds)
    }
    
    var connectionStatusColor: String {
        return isConnected ? "green" : "red"
    }
    
    private func getRacePosition(lapData: LapData) -> Int {
        // Use carPosition during race (1-22, 0=invalid)
        if lapData.carPosition > 0 && lapData.carPosition <= 22 {
            return Int(lapData.carPosition)
        }
        
        // Use gridPosition before race starts (1-22, 0=invalid)
        if lapData.gridPosition > 0 && lapData.gridPosition <= 22 {
            return Int(lapData.gridPosition)
        }
        
        // No valid position data
        return 0
    }
    
    // MARK: - UI Interpolation
    
    private func startInterpolation() {
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            self.interpolateValues()
        }
    }
    
    private func stopInterpolation() {
        interpolationTimer?.invalidate()
        interpolationTimer = nil
    }
    
    private func interpolateValues() {
        // Apply exponential moving average for smooth UI updates
        let oldSpeed = speed
        speed = Int(Self.lerp(Double(speed), rawSpeed, smoothingFactor))
        rpm = Self.lerp(rpm, rawRPM, smoothingFactor)
        ersCharge = Self.lerp(ersCharge, rawERS, smoothingFactor)
        
        #if DEBUG
        // Log significant speed changes for debugging
        if abs(speed - oldSpeed) > 2 {
            print("🏎️ SPEED INTERPOLATED: \(oldSpeed)km/h → \(speed)km/h (\(speedMPH)mph)")
        }
        #endif
    }
    
    // MARK: - Utility Functions
    
    private static func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
        return Swift.max(minValue, Swift.min(maxValue, value))
    }
    
    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a * (1.0 - t) + b * t
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
