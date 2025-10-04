import SwiftUI
import UIKit

enum AppColors {
    static let appBackground = Color(hex: "#163034")
    static let tileBackground = Color(hex: "#25383C")
    static let tileBorder = Color(hex: "#42646B")
    static let tileShadow = Color.black.opacity(0.05)

    static let primaryRowBackground = Color(hex: "#365258")
    static let primaryRowBorder = Color(hex: "#527C84")
    static let primaryRowInnerGlow = Color(hex: "#365258")

    static let secondaryRowBackground = Color(hex: "#365258")
    static let secondaryTileBackground = Color(hex: "#365258")

    static let labelText = Color.white.opacity(0.7)
    static let tileTitle = Color.white
    static let primaryData = Color.white
    static let secondaryData = Color.white

    static let red = Color(hex: "#FF0F3C")
    static let amber = Color(hex: "#F4E539")
    static let green = Color(hex: "#30DB47")
    static let purple = Color(hex: "#E961FF")
    static let blue = Color(hex: "#24BFBA")

    static let sessionBestBackground = Color(red: 233/255, green: 97/255, blue: 255/255, opacity: 0.1)
    static let sessionBestBorder = Color(red: 233/255, green: 97/255, blue: 255/255, opacity: 0.5)

    static let personalBestBackground = Color(red: 48/255, green: 219/255, blue: 71/255, opacity: 0.05)
    static let personalBestBorder = Color(red: 48/255, green: 219/255, blue: 71/255, opacity: 0.5)

    static let neutralInfoBorder = Color.white.opacity(0.08)
}

enum AppTypography {
    static func label() -> Font {
        Font.custom("SF Pro Display", size: 10).weight(.semibold)
    }

    static func tileTitle() -> Font {
        Font.custom("SF Pro Display", size: 12).weight(.semibold)
    }

    static func primaryData() -> Font {
        Font.custom("SF Pro Display", size: 32).weight(.semibold)
    }

    static func secondaryData() -> Font {
        Font.custom("SF Pro Display", size: 12).weight(.semibold)
    }
}

enum AppLayout {
    static let tileCornerRadius: CGFloat = 24
    static let tilePadding: CGFloat = 16
    static let tileSpacing: CGFloat = 12
    static let chipCornerRadius: CGFloat = 8
}

extension View {
    func primaryTileBackground() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppLayout.tileCornerRadius, style: .continuous)
                    .fill(AppColors.tileBackground)
                    .shadow(color: AppColors.tileShadow, radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.tileCornerRadius, style: .continuous)
                    .stroke(AppColors.tileBorder, lineWidth: 1)
            )
    }

    func primaryRowBackground(cornerRadius: CGFloat = AppLayout.tileCornerRadius, corners: UIRectCorner = .allCorners) -> some View {
        self
            .background(
                RoundedCorners(radius: cornerRadius, corners: corners)
                    .fill(AppColors.primaryRowBackground)
                    .overlay(
                        RoundedCorners(radius: cornerRadius, corners: corners)
                            .stroke(AppColors.primaryRowBorder, lineWidth: 1)
                    )
                    .overlay(
                        RoundedCorners(radius: cornerRadius, corners: corners)
                            .fill(AppColors.primaryRowInnerGlow.opacity(0.35))
                            .blur(radius: 50)
                            .blendMode(.plusLighter)
                    )
            )
    }

    func secondaryRowBackground(cornerRadius: CGFloat = AppLayout.tileCornerRadius, corners: UIRectCorner = .allCorners) -> some View {
        self
            .background(
                RoundedCorners(radius: cornerRadius, corners: corners)
                    .fill(AppColors.secondaryRowBackground)
                    .overlay(
                        RoundedCorners(radius: cornerRadius, corners: corners)
                            .stroke(AppColors.primaryRowBorder.opacity(0.6), lineWidth: 1)
                    )
            )
    }

    func neutralInfoTile(cornerRadius: CGFloat = AppLayout.chipCornerRadius) -> some View {
        self
            .overlay(
                RoundedCorners(radius: cornerRadius, corners: .allCorners)
                    .stroke(AppColors.neutralInfoBorder, lineWidth: 1)
            )
    }
}

extension Color {
    init(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}


