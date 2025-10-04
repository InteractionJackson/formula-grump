import SwiftUI
import UIKit

// MARK: - Track Overview Design Tokens
struct TrackOverviewStyle {
    static let cardRadius: CGFloat = AppLayout.tileCornerRadius
    static let cardPadding: CGFloat = AppLayout.tilePadding
    static let spacing: CGFloat = AppLayout.tileSpacing
    static let titleText = AppColors.tileTitle
    static let subtitleText = AppColors.labelText
    static let trackStrokeWidth: CGFloat = 2
    static let carDotSize: CGFloat = 8
    static let focusLabelPadding: CGFloat = 6
    static let focusLabelRadius: CGFloat = 8
    static let pillHeight: CGFloat = 32
    static let pillRadius: CGFloat = 16
    static let trackPath = Color.white.opacity(0.08)
    static let focusDriverBackground = AppColors.blue.opacity(0.25)
    static let focusDriverText = AppColors.primaryData

    static func teamColor(for teamId: Int) -> Color {
        switch teamId {
        case 0: return AppColors.blue
        case 1: return AppColors.purple
        case 2: return AppColors.red
        case 3: return AppColors.green
        case 4: return AppColors.red
        case 5: return AppColors.blue.opacity(0.8)
        case 6: return AppColors.blue.opacity(0.6)
        case 7: return AppColors.red.opacity(0.7)
        case 8: return AppColors.blue
        case 9: return AppColors.amber
        default: return AppColors.neutralInfoBorder
        }
    }

    static func weatherIcon(for weather: UInt8) -> String {
        switch weather {
        case 0: return "sun.max"
        case 1: return "cloud.sun"
        case 2: return "cloud"
        case 3: return "cloud.drizzle"
        case 4: return "cloud.rain"
        case 5: return "cloud.bolt.rain"
        default: return "questionmark.circle"
        }
    }

    static func driverStatusColor(for status: UInt8) -> Color {
        switch status {
        case 0: return AppColors.neutralInfoBorder
        case 1, 2, 3: return AppColors.amber
        case 4: return AppColors.green
        default: return AppColors.neutralInfoBorder
        }
    }
}

