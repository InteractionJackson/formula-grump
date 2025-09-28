import Foundation
@testable import F1TelemetryTracker

// MARK: - Mock Telemetry Data for Testing Only
// This file contains mock data that should NEVER be used in runtime code

struct MockTelemetryData {
    
    // MARK: - Mock Car Telemetry
    static let mockCarTelemetry = CarTelemetryData(
        speed: 150,
        throttle: 0.75,
        steer: 0.0,
        brake: 0.0,
        clutch: 0,
        gear: 4,
        engineRPM: 8500,
        drs: 0,
        revLightsPercent: 60,
        revLightsBitValue: 0,
        brakesTemperature: [250, 280, 320, 290],
        tyresSurfaceTemperature: [85, 88, 92, 87],
        tyresInnerTemperature: [80, 83, 87, 82],
        engineTemperature: 95,
        tyresPressure: [2.1, 2.2, 2.0, 2.1],
        surfaceType: [0, 0, 0, 0]
    )
    
    // MARK: - Mock Car Status
    static let mockCarStatus = CarStatusData(
        tractionControl: 1,
        antiLockBrakes: 1,
        fuelMix: 1,
        frontBrakeBias: 50,
        pitLimiterStatus: 0,
        fuelInTank: 45.5,
        fuelCapacity: 110.0,
        fuelRemainingLaps: 25.3,
        maxRPM: 15000,
        idleRPM: 1000,
        maxGears: 8,
        drsAllowed: 1,
        drsActivationDistance: 0,
        actualTyreCompound: 16,
        visualTyreCompound: 16,
        tyresAgeLaps: 12,
        vehicleFiaFlags: 0,
        enginePowerICE: 750.0,
        enginePowerMGUK: 120.0,
        ersStoreEnergy: 2500000.0, // 2.5MJ
        ersDeployMode: 1,
        ersHarvestedThisLapMGUK: 150000.0,
        ersHarvestedThisLapMGUH: 200000.0,
        ersDeployedThisLap: 300000.0,
        networkPaused: 0
    )
    
    // MARK: - Mock Lap Data
    static let mockLapData = LapData(
        lastLapTimeInMS: 83456,
        currentLapTimeInMS: 45123,
        sector1TimeInMS: 28123,
        sector2TimeInMS: 32456,
        sector1TimeMinutes: 0,
        sector2TimeMinutes: 0,
        deltaToCarInFrontMSPart: 432,
        deltaToRaceLeaderMSPart: 1234,
        lapDistance: 2500.0,
        totalDistance: 180000.0,
        safetyCarDelta: 0.0,
        carPosition: 3,
        currentLapNum: 23,
        pitStatus: 0,
        numPitStops: 1,
        sector: 2,
        currentLapInvalid: 0,
        penalties: 0,
        warnings: 0,
        numUnservedDriveThroughPens: 0,
        numUnservedStopGoPens: 0,
        gridPosition: 5,
        driverStatus: 4, // On track
        resultStatus: 2, // Active
        pitLaneTimerActive: 0,
        pitLaneTimeInLaneInMS: 0,
        pitStopTimerInMS: 0,
        pitStopShouldServePen: 0,
        sector3TimeInMS: 22877,
        sector3TimeMinutes: 0,
        sector1TimeMSPart: 123,
        sector2TimeMSPart: 456,
        sector3TimeMSPart: 877
    )
    
    // MARK: - Mock Leaderboard Data
    static let mockLeaderboardData: [DriverData] = [
        DriverData(position: 1, name: "VERSTAPPEN", status: "On track", pitStops: 1, sector1Time: "28.123", sector2Time: "32.456", sector3Time: "22.877", delta: "-", penalty: "-"),
        DriverData(position: 2, name: "HAMILTON", status: "On track", pitStops: 0, sector1Time: "28.234", sector2Time: "32.567", sector3Time: "22.988", delta: "+0.432", penalty: "-"),
        DriverData(position: 3, name: "LECLERC", status: "In pit", pitStops: 1, sector1Time: "28.345", sector2Time: "32.678", sector3Time: "23.099", delta: "+0.876", penalty: "▲"),
        DriverData(position: 4, name: "RUSSELL", status: "On track", pitStops: 0, sector1Time: "28.456", sector2Time: "32.789", sector3Time: "23.210", delta: "+1.234", penalty: "-"),
        DriverData(position: 5, name: "SAINZ", status: "On track", pitStops: 1, sector1Time: "28.567", sector2Time: "32.890", sector3Time: "23.321", delta: "+1.567", penalty: "▲"),
        DriverData(position: 6, name: "PÉREZ", status: "On track", pitStops: 0, sector1Time: "28.678", sector2Time: "32.901", sector3Time: "23.432", delta: "+1.890", penalty: "-"),
        DriverData(position: 7, name: "NORRIS", status: "On track", pitStops: 1, sector1Time: "28.789", sector2Time: "33.012", sector3Time: "23.543", delta: "+2.123", penalty: "▲"),
        DriverData(position: 8, name: "PIASTRI", status: "On track", pitStops: 0, sector1Time: "28.890", sector2Time: "33.123", sector3Time: "23.654", delta: "+2.456", penalty: "-"),
        DriverData(position: 9, name: "ALONSO", status: "On track", pitStops: 1, sector1Time: "28.901", sector2Time: "33.234", sector3Time: "23.765", delta: "+2.789", penalty: "▲"),
        DriverData(position: 10, name: "STROLL", status: "In garage", pitStops: 0, sector1Time: "-:-:-", sector2Time: "-:-:-", sector3Time: "-:-:-", delta: "DNF", penalty: "-")
    ]
    
    // MARK: - Mock Car Damage Data
    static let mockCarDamage = CarDamageData(
        tyresDamage: [5.0, 8.0, 12.0, 7.0], // RL, RR, FL, FR
        tyresWear: [15, 18, 22, 16],
        engineDamage: 5,
        gearBoxDamage: 0,
        frontLeftWingDamage: -2,
        frontRightWingDamage: 0,
        rearWingDamage: 0,
        floorDamage: 3,
        diffuserDamage: 0,
        sidepodDamage: 0,
        drsFault: 0,
        ersFault: 0,
        gearBoxDrivethrough: 0,
        engineDrivethrough: 0,
        wingDrivethrough: 0,
        engineWear: 25,
        gearBoxWear: 18
    )
    
    // MARK: - Mock Session Data
    static let mockSessionData = PacketSessionData(
        weather: 0,
        trackTemperature: 35,
        airTemperature: 28,
        totalLaps: 72,
        trackLength: 5412,
        sessionType: 10, // Race
        trackId: 0, // Bahrain
        formula: 0, // F1 Modern
        sessionTimeLeft: 3600,
        sessionDuration: 5400,
        pitSpeedLimit: 80,
        gamePaused: 0,
        isSpectating: 0,
        spectatorCarIndex: 255,
        sliProNativeSupport: 1,
        numMarshalZones: 0,
        marshalZones: [],
        safetyCarStatus: 0,
        networkGame: 0,
        numWeatherForecastSamples: 0,
        weatherForecastSamples: [],
        forecastAccuracy: 1,
        aiDifficulty: 100,
        seasonLinkIdentifier: 0,
        weekendLinkIdentifier: 0,
        sessionLinkIdentifier: 0,
        pitStopWindowIdealLap: 25,
        pitStopWindowLatestLap: 35,
        pitStopRejoinPosition: 10,
        steeringAssist: 0,
        brakingAssist: 0,
        gearboxAssist: 1,
        pitAssist: 0,
        pitReleaseAssist: 0,
        ersAssist: 0,
        drsAssist: 0,
        dynamicRacingLine: 0,
        dynamicRacingLineType: 0,
        gameMode: 3,
        ruleSet: 0,
        timeOfDay: 720,
        sessionLength: 1,
        speedUnitsLeadPlayer: 0,
        temperatureUnitsLeadPlayer: 0,
        speedUnitsSecondaryPlayer: 0,
        temperatureUnitsSecondaryPlayer: 0,
        numSafetyCarPeriods: 0,
        numVirtualSafetyCarPeriods: 0,
        numRedFlagPeriods: 0
    )
}

// MARK: - Mock Preview Data for SwiftUI Previews
extension MockTelemetryData {
    
    static let previewViewModel: TelemetryViewModel = {
        let viewModel = TelemetryViewModel()
        
        // Set mock values for preview
        viewModel.speed = 150
        viewModel.rpm = 8500
        viewModel.gear = 4
        viewModel.throttlePercent = 0.75
        viewModel.brakePercent = 0.0
        viewModel.ersCharge = 2500000.0
        viewModel.currentLapTime = 83.456
        viewModel.sector1Time = 28.123
        viewModel.sector2Time = 32.456
        viewModel.sector3Time = 22.877
        viewModel.lastLapTime = 83.456
        viewModel.bestLapTime = 81.234
        viewModel.engineTemperature = 95
        viewModel.brakesTemperature = [250, 280, 320, 290]
        viewModel.tyresSurfaceTemperature = [85, 88, 92, 87]
        viewModel.tyreCompound = "C3 (Medium)"
        viewModel.tyreAge = 12
        viewModel.currentLap = 23
        viewModel.totalLaps = 72
        viewModel.safetyCarStatus = "Clear"
        viewModel.leaderboardData = mockLeaderboardData
        
        return viewModel
    }()
}
