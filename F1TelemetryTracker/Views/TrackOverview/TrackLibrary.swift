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
struct TrackProfile: Equatable {
    let id: TrackId
    let geometry: TrackGeometryImpl
    let displayName: String
    
    init(id: TrackId, geometry: TrackGeometryImpl) {
        self.id = id
        self.geometry = geometry
        self.displayName = id.displayName
    }
    
    static func == (lhs: TrackProfile, rhs: TrackProfile) -> Bool {
        return lhs.id == rhs.id && lhs.geometry == rhs.geometry
    }
}

// MARK: - Track Library
class TrackLibrary {
    
    static func loadTrackProfile(for id: TrackId) -> TrackProfile {
        let geometry = TrackGeometryCache.shared.geometry(for: id)
        return TrackProfile(id: id, geometry: TrackGeometryImpl(geometry: geometry))
    }
    
    static func loadTrackProfile(for rawId: Int8) -> TrackProfile {
        let trackId = TrackId(rawValue: rawId) ?? .unknown
        return loadTrackProfile(for: trackId)
    }
}