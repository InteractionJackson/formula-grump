import Foundation

// MARK: - F1 24 Telemetry Packet Structures & Validation
// Based on the official F1 24 UDP telemetry specification

// MARK: - Packet Size Constants
struct PacketSizes {
    static let header: Int = 29
    static let carTelemetryDataSize: Int = 60  // CORRECTED: F1 24 official spec
    static let participantDataSize: Int = 56   // Correct F1 24 size
    
    static let expectedSizes: [UInt8: Int] = [
        0: 1349,  // Motion
        1: 753,   // Session - CORRECTED from 644 to 753  
        2: 1285,  // LapData
        3: 45,    // Event (variable, minimum)
        4: 1350,  // Participants
        6: 1352,  // CarTelemetry (29 + 22*60 + 3) = 1352 bytes
        7: 1239,  // CarStatus
        10: 1367, // CarDamage (29 + 22*60 + 18)
    ]
}

struct PacketHeader {
    let packetFormat: UInt16         // 2024 for F1 24
    let gameYear: UInt8              // Game year - 24 for F1 24
    let gameMajorVersion: UInt8      // Game major version
    let gameMinorVersion: UInt8      // Game minor version
    let packetVersion: UInt8         // Version of this packet type
    let packetId: UInt8              // Identifier for the packet type
    let sessionUID: UInt64           // Unique identifier for the session
    let sessionTime: Float           // Session timestamp
    let frameIdentifier: UInt32      // Identifier for the frame
    let overallFrameIdentifier: UInt32 // Overall identifier for the frame
    let playerCarIndex: UInt8        // Index of player's car in the array
    let secondaryPlayerCarIndex: UInt8 // Index of secondary player's car (255 if no second player)
    
    // MARK: - Validation
    func isValid() -> Bool {
        return packetFormat == 2024 && gameYear == 24
    }
    
    func validatePacketSize(_ actualSize: Int) -> Bool {
        guard let expectedSize = PacketSizes.expectedSizes[packetId] else {
            // Unknown packet type - allow for future expansion
            return actualSize >= PacketSizes.header
        }
        // Accept a small overage; some builds pad or tack on trailing bytes
        return actualSize >= expectedSize && actualSize < expectedSize + 64
    }
}

// MARK: - Packet Validation Result
enum PacketValidationResult {
    case valid
    case invalidFormat(UInt16)
    case invalidSize(expected: Int, actual: Int)
    case unknownPacketType(UInt8)
}

// MARK: - Motion Packet (ID: 0)
struct CarMotionData {
    let worldPositionX: Float            // World space X position - metres
    let worldPositionY: Float            // World space Y position
    let worldPositionZ: Float            // World space Z position
    let worldVelocityX: Float            // Velocity in world space X – metres/s
    let worldVelocityY: Float            // Velocity in world space Y
    let worldVelocityZ: Float            // Velocity in world space Z
    let worldForwardDirX: Int16          // World space forward X direction (normalised)
    let worldForwardDirY: Int16          // World space forward Y direction (normalised)
    let worldForwardDirZ: Int16          // World space forward Z direction (normalised)
    let worldRightDirX: Int16            // World space right X direction (normalised)
    let worldRightDirY: Int16            // World space right Y direction (normalised)
    let worldRightDirZ: Int16            // World space right Z direction (normalised)
    let gForceLateral: Float             // Lateral G-Force component
    let gForceLongitudinal: Float        // Longitudinal G-Force component
    let gForceVertical: Float            // Vertical G-Force component
    let yaw: Float                       // Yaw angle in radians
    let pitch: Float                     // Pitch angle in radians
    let roll: Float                      // Roll angle in radians
}

struct PacketMotionData {
    let header: PacketHeader             // Header
    let carMotionData: [CarMotionData]   // Data for all cars on track (22 cars)
}

// MARK: - Car Telemetry Packet (ID: 6)
struct CarTelemetryData {
    let speed: UInt16                    // Speed of car in km/h
    let throttle: Float                  // Amount of throttle applied (0.0 to 1.0)
    let steer: Float                     // Steering (-1.0 (full lock left) to 1.0 (full lock right))
    let brake: Float                     // Amount of brake applied (0.0 to 1.0)
    let clutch: UInt8                    // Amount of clutch applied (0 to 100)
    let gear: Int8                       // Gear selected (1-8, N=0, R=-1)
    let engineRPM: UInt16                // Engine RPM
    let drs: UInt8                       // 0 = off, 1 = on
    let revLightsPercent: UInt8          // Rev lights indicator (percentage)
    let revLightsBitValue: UInt16        // Rev lights (bit 0 = leftmost LED, bit 14 = rightmost LED)
    let brakesTemperature: [UInt16]      // Brakes temperature (celsius) [RL, RR, FL, FR]
    let tyresSurfaceTemperature: [UInt8] // Tyres surface temperature (celsius) [RL, RR, FL, FR]
    let tyresInnerTemperature: [UInt8]   // Tyres inner temperature (celsius) [RL, RR, FL, FR]
    let engineTemperature: UInt16        // Engine temperature (celsius)
    let tyresPressure: [Float]           // Tyres pressure (PSI) [RL, RR, FL, FR]
    let surfaceType: [UInt8]             // Driving surface [RL, RR, FL, FR]
}

struct PacketCarTelemetryData {
    let header: PacketHeader             // Header
    let carTelemetryData: [CarTelemetryData] // Data for all cars on track (22 cars)
    let mfdPanelIndex: UInt8             // Index of MFD panel open - 255 = MFD closed
    let mfdPanelIndexSecondaryPlayer: UInt8 // See above
    let suggestedGear: Int8              // Suggested gear for the player (1-8), 0 if no gear suggested
}

// MARK: - Car Status Packet (ID: 7)
struct CarStatusData {
    let tractionControl: UInt8           // Traction control - 0 = off, 1 = medium, 2 = full
    let antiLockBrakes: UInt8            // 0 (off) - 1 (on)
    let fuelMix: UInt8                   // Fuel mix - 0 = lean, 1 = standard, 2 = rich, 3 = max
    let frontBrakeBias: UInt8            // Front brake bias (percentage)
    let pitLimiterStatus: UInt8          // Pit limiter status - 0 = off, 1 = on
    let fuelInTank: Float                // Current fuel mass
    let fuelCapacity: Float              // Fuel capacity
    let fuelRemainingLaps: Float         // Fuel remaining in terms of laps (value on MFD)
    let maxRPM: UInt16                   // Cars max RPM, point of rev limiter
    let idleRPM: UInt16                  // Cars idle RPM
    let maxGears: UInt8                  // Maximum number of gears
    let drsAllowed: UInt8                // 0 = not allowed, 1 = allowed
    let drsActivationDistance: UInt16    // 0 = DRS not available, non-zero - DRS will be available in [X] metres
    let actualTyreCompound: UInt8        // F1 Modern - 16 = C5, 17 = C4, 18 = C3, 19 = C2, 20 = C1
    let visualTyreCompound: UInt8        // F1 visual (can be different from actual compound)
    let tyresAgeLaps: UInt8              // Age in laps of the current set of tyres
    let vehicleFiaFlags: Int8            // -1 = invalid/unknown, 0 = none, 1 = green, 2 = blue, 3 = yellow
    let enginePowerICE: Float            // Engine power output of ICE (watts)
    let enginePowerMGUK: Float           // Engine power output of MGU-K (watts)
    let ersStoreEnergy: Float            // ERS energy store in Joules
    let ersDeployMode: UInt8             // ERS deployment mode, 0 = none, 1 = medium, 2 = hotlap, 3 = overtake
    let ersHarvestedThisLapMGUK: Float   // ERS energy harvested this lap by MGU-K
    let ersHarvestedThisLapMGUH: Float   // ERS energy harvested this lap by MGU-H
    let ersDeployedThisLap: Float        // ERS energy deployed this lap
    let networkPaused: UInt8             // Whether the car is paused in a network game
}

struct PacketCarStatusData {
    let header: PacketHeader             // Header
    let carStatusData: [CarStatusData]   // Data for all cars on track
}

// MARK: - Session Packet (ID: 1)
struct MarshalZone {
    let zoneStart: Float                 // Fraction (0..1) of way through the lap the marshal zone starts
    let zoneFlag: Int8                   // -1 = invalid/unknown, 0 = none, 1 = green, 2 = blue, 3 = yellow, 4 = red
}

struct WeatherForecastSample {
    let sessionType: UInt8               // 0 = unknown, 1 = P1, 2 = P2, 3 = P3, 4 = Short P, 5 = Q1, 6 = Q2, 7 = Q3, 8 = Short Q, 9 = OSQ, 10 = R, 11 = R2, 12 = R3, 13 = Time Trial
    let timeOffset: UInt8                // Time in minutes the forecast is for
    let weather: UInt8                   // Weather - 0 = clear, 1 = light cloud, 2 = overcast, 3 = light rain, 4 = heavy rain, 5 = storm
    let trackTemperature: Int8           // Track temp. in degrees Celsius
    let trackTemperatureChange: Int8     // Track temp. change – 0 = up, 1 = down, 2 = no change
    let airTemperature: Int8             // Air temp. in degrees Celsius
    let airTemperatureChange: Int8       // Air temp. change – 0 = up, 1 = down, 2 = no change
    let rainPercentage: UInt8            // Rain percentage (0-100)
}

struct PacketSessionData {
    let header: PacketHeader             // Header
    let weather: UInt8                   // Weather - 0 = clear, 1 = light cloud, 2 = overcast, 3 = light rain, 4 = heavy rain, 5 = storm
    let trackTemperature: Int8           // Track temp. in degrees celsius
    let airTemperature: Int8             // Air temp. in degrees celsius
    let totalLaps: UInt8                 // Total number of laps in this race
    let trackLength: UInt16              // Track length in metres
    let sessionType: UInt8               // 0 = unknown, 1 = P1, 2 = P2, 3 = P3, 4 = Short P, 5 = Q1, 6 = Q2, 7 = Q3, 8 = Short Q, 9 = OSQ, 10 = R, 11 = R2, 12 = R3, 13 = Time Trial
    let trackId: Int8                    // -1 for unknown, see appendix
    let formula: UInt8                   // Formula, 0 = F1 Modern, 1 = F1 Classic, 2 = F2, 3 = F1 Generic, 4 = Beta, 5 = Supercars, 6 = Esports, 7 = F2 2021
    let sessionTimeLeft: UInt16          // Time left in session in seconds
    let sessionDuration: UInt16          // Session duration in seconds
    let pitSpeedLimit: UInt8             // Pit speed limit in km/h
    let gamePaused: UInt8                // Whether the game is paused – network game only
    let isSpectating: UInt8              // Whether the player is spectating
    let spectatorCarIndex: UInt8         // Index of the car being spectated
    let sliProNativeSupport: UInt8       // SLI Pro support, 0 = inactive, 1 = active
    let numMarshalZones: UInt8           // Number of marshal zones to follow
    let marshalZones: [MarshalZone]      // List of marshal zones – max 21
    let safetyCarStatus: UInt8           // 0 = no safety car, 1 = full, 2 = virtual, 3 = formation lap
    let networkGame: UInt8               // 0 = offline, 1 = online
    let numWeatherForecastSamples: UInt8 // Number of weather samples to follow
    let weatherForecastSamples: [WeatherForecastSample] // Array of weather forecast samples
    let forecastAccuracy: UInt8          // 0 = Perfect, 1 = Approximate
    let aiDifficulty: UInt8              // AI Difficulty rating – 0-110
    let seasonLinkIdentifier: UInt32     // Identifier for season - persists across saves
    let weekendLinkIdentifier: UInt32    // Identifier for weekend - persists across saves
    let sessionLinkIdentifier: UInt32    // Identifier for session - persists across saves
    let pitStopWindowIdealLap: UInt8     // Ideal lap to pit on for current strategy (player)
    let pitStopWindowLatestLap: UInt8    // Latest lap to pit on for current strategy (player)
    let pitStopRejoinPosition: UInt8     // Predicted position to rejoin at (player)
    let steeringAssist: UInt8            // 0 = off, 1 = on
    let brakingAssist: UInt8             // 0 = off, 1 = low, 2 = medium, 3 = high
    let gearboxAssist: UInt8             // 1 = manual, 2 = manual & suggested gear, 3 = auto
    let pitAssist: UInt8                 // 0 = off, 1 = on
    let pitReleaseAssist: UInt8          // 0 = off, 1 = on
    let ersAssist: UInt8                 // 0 = off, 1 = on
    let drsAssist: UInt8                 // 0 = off, 1 = on
    let dynamicRacingLine: UInt8         // 0 = off, 1 = corners only, 2 = full
    let dynamicRacingLineType: UInt8     // 0 = 2D, 1 = 3D
    let gameMode: UInt8                  // Game mode id - see appendix
    let ruleSet: UInt8                   // Ruleset - see appendix
    let timeOfDay: UInt32                // Local time of day - minutes since midnight
    let sessionLength: UInt8             // 0 = None, 2 = Very Short, 3 = Short, 4 = Medium, 5 = Medium Long, 6 = Long, 7 = Full
    let speedUnitsLeadPlayer: UInt8      // 0 = MPH, 1 = KPH
    let temperatureUnitsLeadPlayer: UInt8 // 0 = Celsius, 1 = Fahrenheit
    let speedUnitsSecondaryPlayer: UInt8 // 0 = MPH, 1 = KPH
    let temperatureUnitsSecondaryPlayer: UInt8 // 0 = Celsius, 1 = Fahrenheit
    let numSafetyCarPeriods: UInt8       // Number of safety cars called during session
    let numVirtualSafetyCarPeriods: UInt8 // Number of virtual safety cars called
    let numRedFlags: UInt8               // Number of red flags called during session
}

// MARK: - Lap Data Packet (ID: 2)
struct LapData {
    let lastLapTimeInMS: UInt32          // Last lap time in milliseconds
    let currentLapTimeInMS: UInt32       // Current time around the lap in milliseconds
    let sector1TimeInMS: UInt16          // Sector 1 time in milliseconds
    let sector1TimeMinutes: UInt8        // Sector 1 whole minute part
    let sector2TimeInMS: UInt16          // Sector 2 time in milliseconds
    let sector2TimeMinutes: UInt8        // Sector 2 whole minute part
    let deltaToCarInFrontInMS: UInt16    // Time delta to car in front in milliseconds
    let deltaToRaceLeaderInMS: UInt16    // Time delta to race leader in milliseconds
    let lapDistance: Float               // Distance vehicle is around current lap in metres – could be negative if line hasn't been crossed yet
    let totalDistance: Float             // Total distance travelled in session in metres – could be negative if line hasn't been crossed yet
    let safetyCarDelta: Float            // Delta in seconds for safety car
    let carPosition: UInt8               // Car race position
    let currentLapNum: UInt8             // Current lap number
    let pitStatus: UInt8                 // 0 = none, 1 = pitting, 2 = in pit area
    let numPitStops: UInt8               // Number of pit stops taken in this race
    let sector: UInt8                    // 0 = sector1, 1 = sector2, 2 = sector3
    let currentLapInvalid: UInt8         // Current lap invalid - 0 = valid, 1 = invalid
    let penalties: UInt8                 // Accumulated time penalties in seconds to be added
    let totalWarnings: UInt8             // Accumulated number of warnings issued
    let cornerCuttingWarnings: UInt8     // Accumulated number of corner cutting warnings issued
    let numUnservedDriveThroughPens: UInt8 // Num drive through pens left to serve
    let numUnservedStopGoPens: UInt8     // Num stop go pens left to serve
    let gridPosition: UInt8              // Grid position the vehicle started the race in
    let driverStatus: UInt8              // Status of driver - 0 = in garage, 1 = flying lap, 2 = in lap, 3 = out lap, 4 = on track
    let resultStatus: UInt8              // Result status - 0 = invalid, 1 = inactive, 2 = active, 3 = finished, 4 = didnotfinish, 5 = disqualified, 6 = not classified, 7 = retired
    let pitLaneTimerActive: UInt8        // Pit lane timing, 0 = inactive, 1 = active
    let pitLaneTimeInLaneInMS: UInt16    // If active, the current time spent in the pit lane in ms
    let pitStopTimerInMS: UInt16         // Time of the actual pit stop in ms
    let pitStopShouldServePen: UInt8     // Whether the car should serve a penalty at this stop
}

struct PacketLapData {
    let header: PacketHeader             // Header
    let lapData: [LapData]               // Lap data for all cars on track
    let timeTrialPBCarIdx: UInt8         // Index of Personal Best car in time trial (255 if invalid)
    let timeTrialRivalCarIdx: UInt8      // Index of Rival car in time trial (255 if invalid)
}

// MARK: - Participants Packet (ID: 4)
struct ParticipantData {
    let aiControlled: UInt8              // Whether the vehicle is AI (1) or Human (0) controlled
    let driverId: UInt8                  // Driver id - see appendix, 255 if network human
    let networkId: UInt8                 // Network id – unique identifier for network players
    let teamId: UInt8                    // Team id - see appendix
    let myTeam: UInt8                    // My team flag – 1 = My Team, 0 = otherwise
    let raceNumber: UInt8                // Race number of the car
    let nationality: UInt8               // Nationality of the driver
    let name: String                     // Name of participant in UTF-8 format – null terminated. Will be truncated with … (U+2026) if too long
    let yourTelemetry: UInt8             // The player's UDP setting, 0 = restricted, 1 = public
}

struct PacketParticipantsData {
    let header: PacketHeader             // Header
    let numActiveCars: UInt8             // Number of active cars in the data – should match number of cars on HUD
    let participants: [ParticipantData]  // Participant data for all cars (22 cars)
}

// MARK: - Car Damage Packet (ID: 10)
struct CarDamageData {
    let tyresDamage: [Float]             // Tyre damage (percentage) [RL, RR, FL, FR]
    let tyresWear: [UInt8]               // Tyre wear (percentage) [RL, RR, FL, FR]
    let engineDamage: UInt8              // Engine damage (percentage)
    let gearBoxDamage: UInt8             // Gearbox damage (percentage)
    let frontLeftWingDamage: Int8        // Front left wing damage (percentage)
    let frontRightWingDamage: Int8       // Front right wing damage (percentage)
    let rearWingDamage: Int8             // Rear wing damage (percentage)
    let floorDamage: Int8                // Floor damage (percentage)
    let diffuserDamage: Int8             // Diffuser damage (percentage)
    let sidepodDamage: Int8              // Sidepod damage (percentage)
    let drsFault: UInt8                  // Indicator for DRS fault, 0 = OK, 1 = fault
    let ersFault: UInt8                  // Indicator for ERS fault, 0 = OK, 1 = fault
    let gearBoxDrivethrough: UInt8       // Gearbox damage drivethrough penalty
    let engineDrivethrough: UInt8        // Engine damage drivethrough penalty
    let wingDrivethrough: UInt8          // Wing damage drivethrough penalty
    let engineWear: UInt8                // Engine wear (percentage)
    let gearBoxWear: UInt8               // Gearbox wear (percentage)
}

struct PacketCarDamageData {
    let header: PacketHeader             // Header
    let carDamageData: [CarDamageData]   // Data for all cars on track (22 cars)
}

// MARK: - Packet Type Identifiers
enum PacketType: UInt8 {
    case motion = 0
    case session = 1
    case lapData = 2
    case event = 3
    case participants = 4
    case carSetups = 5
    case carTelemetry = 6
    case carStatus = 7
    case finalClassification = 8
    case lobbyInfo = 9
    case carDamage = 10
    case sessionHistory = 11
    case tyreSets = 12
    case motionEx = 13
}
