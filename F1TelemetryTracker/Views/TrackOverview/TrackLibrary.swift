//
//  TrackLibrary.swift
//  F1TelemetryTracker
//
//  Created by Assistant on 2024-09-28.
//

import Foundation
import CoreGraphics

// MARK: - Track ID Enum
enum TrackId: Int8, CaseIterable {
    case melbourne = 0
    case paulRicard = 1
    case shanghai = 2
    case bahrain = 3
    case barcelona = 4
    case monaco = 5
    case azerbaijan = 6
    case britain = 7
    case hungary = 8
    case belgium = 9
    case italy = 10
    case singapore = 11
    case japan = 12
    case abuDhabi = 13
    case usa = 14
    case brazil = 15
    case austria = 16
    case russia = 17
    case mexico = 18
    case vietnam = 19
    case saudi = 20
    case imola = 21
    case portimao = 22
    case jeddah = 23
    case miami = 24
    case lasVegas = 25
    case qatar = 26
    case canada = 27
    case spain = 28
    case china = 29
    case unknown = -1
    
    var displayName: String {
        switch self {
        case .melbourne: return "Melbourne"
        case .paulRicard: return "Paul Ricard"
        case .shanghai: return "Shanghai"
        case .bahrain: return "Bahrain"
        case .barcelona: return "Barcelona"
        case .monaco: return "Monaco"
        case .azerbaijan: return "Azerbaijan"
        case .britain: return "Britain"
        case .hungary: return "Hungary"
        case .belgium: return "Belgium"
        case .italy: return "Italy"
        case .singapore: return "Singapore"
        case .japan: return "Japan"
        case .abuDhabi: return "Abu Dhabi"
        case .usa: return "USA"
        case .brazil: return "Brazil"
        case .austria: return "Austria"
        case .russia: return "Russia"
        case .mexico: return "Mexico"
        case .vietnam: return "Vietnam"
        case .saudi: return "Saudi Arabia"
        case .imola: return "Imola"
        case .portimao: return "Portimao"
        case .jeddah: return "Jeddah"
        case .miami: return "Miami"
        case .lasVegas: return "Las Vegas"
        case .qatar: return "Qatar"
        case .canada: return "Canada"
        case .spain: return "Spain"
        case .china: return "China"
        case .unknown: return "Unknown Circuit"
        }
    }
}

// MARK: - Track Profile
struct TrackProfile {
    let id: TrackId
    let geometry: TrackGeometry
    let displayName: String
    
    init(id: TrackId, geometry: TrackGeometry) {
        self.id = id
        self.geometry = geometry
        self.displayName = id.displayName
    }
}

// MARK: - Track Library
class TrackLibrary {
    private static let trackProfiles: [TrackId: TrackProfile] = {
        var profiles: [TrackId: TrackProfile] = [:]
        
        // Load all SVG track geometries
        profiles = loadAllSVGTracks()
        
        return profiles
    }()
    
    // MARK: - SVG Track Loading
    private static func loadAllSVGTracks() -> [TrackId: TrackProfile] {
        var profiles: [TrackId: TrackProfile] = [:]
        
        // Mapping of SVG filenames to TrackId enum cases
        let trackMappings: [(filename: String, trackId: TrackId)] = [
            ("Albert Park.svg", .melbourne),
            ("Bahrain.svg", .bahrain),
            ("Baku City.svg", .azerbaijan),
            ("Barcelona-Catalunya.svg", .spain),
            ("Circuit of the Americas.svg", .usa),
            ("Gilles Villeneuve.svg", .canada),
            ("Hungaroring.svg", .hungary),
            ("Imola.svg", .imola),
            ("Interlagos.svg", .brazil),
            ("Jeddah Corniche.svg", .jeddah),
            ("Jeddah.svg", .saudi),
            ("Las Vegas.svg", .lasVegas),
            ("Lusail.svg", .qatar),
            ("Marina Bay.svg", .singapore),
            ("Mexico.svg", .mexico),
            ("Miami.svg", .miami),
            ("Monaco.svg", .monaco),
            ("Monza.svg", .italy),
            ("Red Bull Ring.svg", .austria),
            ("Shanghai.svg", .china),
            ("Silverstone.svg", .britain),
            ("Spa-Francorchamps.svg", .belgium),
            ("Suzuka.svg", .japan),
            ("Yas Marina.svg", .abuDhabi),
            ("Zandvoort.svg", .unknown) // No enum case for Zandvoort, using unknown
        ]
        
        // Load each track's SVG data
        for (filename, trackId) in trackMappings {
            if let svgPath = loadSVGPathData(filename: filename) {
                profiles[trackId] = TrackProfile(
                    id: trackId,
                    geometry: SVGTrackGeometry(
                        svgPathData: svgPath,
                        coordinateScale: 1.0,  // Will be adjusted per track as needed
                        coordinateOffset: CGPoint.zero  // Will be adjusted per track as needed
                    )
                )
                print("✅ Loaded SVG track: \(trackId.displayName)")
            } else {
                print("⚠️ Failed to load SVG for: \(trackId.displayName) (\(filename))")
            }
        }
        
        // Add fallback for unknown tracks
        profiles[.unknown] = TrackProfile(
            id: .unknown,
            geometry: PolylineTrackGeometry(points: [
                CGPoint(x: 150, y: 100),  // Start
                CGPoint(x: 250, y: 100),  // Turn 1
                CGPoint(x: 300, y: 150),  // Turn 2
                CGPoint(x: 250, y: 200),  // Turn 3
                CGPoint(x: 150, y: 200),  // Turn 4
                CGPoint(x: 100, y: 150),  // Turn 5
                CGPoint(x: 150, y: 100)   // Back to start
            ])
        )
        
        return profiles
    }
    
    private static func loadSVGPathData(filename: String) -> String? {
        // Construct the path to the SVG file
        let svgPath = "/Users/mattjackson/Documents/GitHub/formula-grump/F1TelemetryTracker/Assets.xcassets/track outlines/\(filename)"
        
        do {
            let svgContent = try String(contentsOfFile: svgPath, encoding: .utf8)
            
            // Extract the path data from the SVG
            if let pathData = extractPathDataFromSVG(svgContent) {
                return pathData
            } else {
                print("⚠️ Could not extract path data from \(filename)")
                return nil
            }
        } catch {
            print("⚠️ Error reading SVG file \(filename): \(error)")
            return nil
        }
    }
    
    private static func extractPathDataFromSVG(_ svgContent: String) -> String? {
        // Use regex to find the path data
        let pattern = #"<path[^>]*d="([^"]*)"[^>]*>"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: svgContent.utf16.count)
            
            if let match = regex.firstMatch(in: svgContent, options: [], range: range) {
                let pathDataRange = match.range(at: 1)
                if let swiftRange = Range(pathDataRange, in: svgContent) {
                    return String(svgContent[swiftRange])
                }
            }
        } catch {
            print("⚠️ Regex error: \(error)")
        }
        
        return nil
    }
    
    static func loadTrackProfile(for id: TrackId) -> TrackProfile {
        if let profile = trackProfiles[id] {
            return profile
        } else {
            print("⚠️ Track profile not found for ID \(id.rawValue), using generic oval")
            return trackProfiles[.unknown]!
        }
    }
    
    static func loadTrackProfile(for rawId: Int8) -> TrackProfile {
        let trackId = TrackId(rawValue: rawId) ?? .unknown
        return loadTrackProfile(for: trackId)
    }
}