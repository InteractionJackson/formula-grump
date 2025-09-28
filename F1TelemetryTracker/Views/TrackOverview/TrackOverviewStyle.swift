import SwiftUI

// MARK: - Track Overview Design Tokens
struct TrackOverviewStyle {
    
    // MARK: - Colors
    static let canvas = Color(hex: "#F6F8FA")
    static let cardBackground = Color(hex: "#FFFFFF")
    static let titleText = Color(hex: "#0B0F14")
    static let subtitleText = Color(hex: "#6D7A88")
    static let trackPath = Color(hex: "#E6EDF2")
    static let focusDriverBackground = Color(hex: "#0B0F14")
    static let focusDriverText = Color.white
    static let pillBackground = Color(hex: "#F7FBFE")
    static let pillStroke = Color(hex: "#EAF2F7")
    
    // MARK: - Dimensions
    static let cardRadius: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let spacing: CGFloat = 12
    static let trackStrokeWidth: CGFloat = 2
    static let carDotSize: CGFloat = 8
    static let focusLabelPadding: CGFloat = 6
    static let focusLabelRadius: CGFloat = 8
    static let pillHeight: CGFloat = 32
    static let pillRadius: CGFloat = 16
    
    // MARK: - Team Colors (F1 2024 Season)
    static func teamColor(for teamId: Int) -> Color {
        switch teamId {
        case 0: return Color(hex: "#00D2BE") // Mercedes - Teal
        case 1: return Color(hex: "#0600EF") // Red Bull - Blue
        case 2: return Color(hex: "#FF6800") // McLaren - Orange
        case 3: return Color(hex: "#006F62") // Aston Martin - Green
        case 4: return Color(hex: "#C92D4B") // Ferrari - Red
        case 5: return Color(hex: "#358C75") // Alpine - Blue/Green
        case 6: return Color(hex: "#2B4562") // AlphaTauri - Navy
        case 7: return Color(hex: "#900000") // Alfa Romeo - Maroon
        case 8: return Color(hex: "#005AFF") // Williams - Blue
        case 9: return Color(hex: "#FFFF00") // Haas - Yellow
        default: return Color(hex: "#808080") // Default gray
        }
    }
    
    // MARK: - Weather Icon Mapping
    static func weatherIcon(for weather: UInt8) -> String {
        switch weather {
        case 0: return "sun.max"           // Clear
        case 1: return "cloud.sun"         // Light cloud
        case 2: return "cloud"             // Overcast
        case 3: return "cloud.drizzle"     // Light rain
        case 4: return "cloud.rain"        // Heavy rain
        case 5: return "cloud.bolt.rain"   // Storm
        default: return "questionmark.circle" // Unknown
        }
    }
    
    // MARK: - Driver Status Colors
    static func driverStatusColor(for status: UInt8) -> Color {
        switch status {
        case 0: return Color(hex: "#808080") // In garage - Gray
        case 1, 2, 3: return Color(hex: "#FFA500") // Flying/In/Out lap - Orange
        case 4: return Color(hex: "#00FF00") // On track - Green
        default: return Color(hex: "#808080") // Default gray
        }
    }
}

