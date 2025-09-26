import Foundation
import Combine

class TelemetryViewModel: ObservableObject {
    // Connection status
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var packetsReceived: Int = 0
    @Published var lastUpdate: Date?
    
    // Dashboard data
    @Published var speed: Int = 0           // km/h
    @Published var gear: Int = 0            // Current gear (N=0, R=-1, 1-8)
    @Published var rpm: Double = 0          // Current RPM
    @Published var maxRPM: Double = 15000   // Maximum RPM for gauge scaling
    @Published var ersCharge: Double = 0    // ERS energy in Joules
    @Published var maxERS: Double = 4000000 // Maximum ERS energy (4MJ)
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
    
    // Splits and lap timing data
    @Published var currentLapTime: Float = 0.0
    @Published var sector1Time: Float = 0.0
    @Published var sector2Time: Float = 0.0
    @Published var sector3Time: Float = 0.0
    @Published var lastLapTime: Float = 0.0
    @Published var bestLapTime: Float = 0.0
    
    private var telemetryReceiver: SimpleTelemetryReceiver
    private var cancellables = Set<AnyCancellable>()
    
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
    }
    
    func connect() {
        print("🔌 TelemetryViewModel: Starting connection...")
        telemetryReceiver.startReceiving()
        
        // Add a test timer to verify UI updates are working
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            print("🧪 Testing UI updates with mock data...")
            self.speed = 150
            self.rpm = 8500
            self.gear = 4
            self.throttlePercent = 0.75
            self.brakePercent = 0.0
            self.ersCharge = 2500000.0  // 2.5MJ = 2500kJ for testing
            
            // Mock splits data
            self.currentLapTime = 83.456  // 1:23.456
            self.sector1Time = 28.123
            self.sector2Time = 32.456
            self.sector3Time = 22.877
            self.lastLapTime = 83.456
            self.bestLapTime = 81.234     // 1:21.234
            
            // Mock temperature data for car condition
            self.engineTemperature = 95  // Slightly warm but good
            self.brakesTemperature = [250, 280, 320, 290]  // Mixed conditions
            self.tyresSurfaceTemperature = [85, 88, 92, 87]  // Good to warning range
            
            // Mock tyre data
            self.tyreCompound = "C3 (Medium)"
            self.tyreAge = 12
            
            print("🧪 Mock data set - UI should update now")
            print("🔋 Mock ERS: \(Int(self.ersCharge / 1000)) kJ (ersValue: \(self.ersValue))")
            print("🌡️ Mock Temps: Engine=\(self.engineTemperature)°C, Brakes=\(self.brakesTemperature), Tyres=\(self.tyresSurfaceTemperature)")
        }
    }
    
    func disconnect() {
        telemetryReceiver.stopReceiving()
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
            print("📊 No telemetry data received")
            return 
        }
        
        print("🎯 Updating UI with telemetry: Speed=\(telemetry.speed)km/h, RPM=\(telemetry.engineRPM), Gear=\(telemetry.gear)")
        
        // Update basic telemetry
        speed = Int(telemetry.speed)
        gear = Int(telemetry.gear)
        rpm = Double(telemetry.engineRPM)
        engineTemperature = Int(telemetry.engineTemperature)
        
        // Update driver inputs
        throttlePercent = Double(telemetry.throttle)
        brakePercent = Double(telemetry.brake)
        steerPercent = Double(telemetry.steer)
        isDRSActive = telemetry.drs > 0
        
        // Clamp values to valid ranges
        throttlePercent = max(0.0, min(1.0, throttlePercent))
        brakePercent = max(0.0, min(1.0, brakePercent))
        steerPercent = max(-1.0, min(1.0, steerPercent))
        
        let safeRPM = max(0, min(Int.max, Int(rpm.isFinite ? rpm : 0)))
        let safeThrottle = max(0, min(100, Int((throttlePercent*100).isFinite ? throttlePercent*100 : 0)))
        let safeBrake = max(0, min(100, Int((brakePercent*100).isFinite ? brakePercent*100 : 0)))
        print("🎮 UI Values: Speed=\(speedMPH)mph, RPM=\(safeRPM), Gear=\(gear), Throttle=\(safeThrottle)%, Brake=\(safeBrake)%")
    }
    
    private func updateStatusData(_ status: CarStatusData?) {
        guard let status = status else { return }
        
        // Update ERS data
        ersCharge = Double(status.ersStoreEnergy)
        print("🔋 ERS UPDATE: \(Int(ersCharge / 1000)) kJ (ersValue: \(ersValue))")
        
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
        tyreCompound = getTyreCompoundName(status.actualTyreCompound)
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
    
    var connectionStatusColor: String {
        return isConnected ? "green" : "red"
    }
}
