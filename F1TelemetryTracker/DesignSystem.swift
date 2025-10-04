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

enum AppUIColors {
    static let primaryRowInnerGlow = UIColor(red: 0x36/255, green: 0x52/255, blue: 0x58/255, alpha: 1)
    static let primaryRowBackground = UIColor(red: 0x36/255, green: 0x52/255, blue: 0x58/255, alpha: 1)
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

    func innerShadow(cornerRadius: CGFloat = AppLayout.tileCornerRadius,
                     color: UIColor = AppUIColors.primaryRowInnerGlow,
                     radius: CGFloat = 73,
                     corners: UIRectCorner = .allCorners) -> some View {
        overlay(
            InnerShadowHostView(
                cornerRadius: cornerRadius,
                color: color,
                radius: radius,
                corners: corners
            )
            .allowsHitTesting(false)
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
                    .innerShadow(
                        cornerRadius: cornerRadius,
                        color: AppUIColors.primaryRowInnerGlow,
                        radius: 73,
                        corners: corners
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

struct InnerShadowHostView: UIViewRepresentable {
    let cornerRadius: CGFloat
    let color: UIColor
    let radius: CGFloat
    let corners: UIRectCorner

    func makeUIView(context: Context) -> InnerShadowContainerView {
        let view = InnerShadowContainerView()
        view.configure(cornerRadius: cornerRadius,
                       color: color,
                       radius: radius,
                       corners: corners)
        return view
    }

    func updateUIView(_ uiView: InnerShadowContainerView, context: Context) {
        uiView.configure(cornerRadius: cornerRadius,
                         color: color,
                         radius: radius,
                         corners: corners)
    }
}

final class InnerShadowContainerView: UIView {
    private let shadowLayer = CALayer()
    private let shapeLayer = CAShapeLayer()
    private var currentCornerRadius: CGFloat = 0
    private var currentColor: UIColor = .clear
    private var currentRadius: CGFloat = 0
    private var currentCorners: UIRectCorner = .allCorners

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        shadowLayer.backgroundColor = UIColor.clear.cgColor
        shadowLayer.masksToBounds = false
        shapeLayer.fillRule = .evenOdd
        shapeLayer.masksToBounds = true
        shadowLayer.addSublayer(shapeLayer)
        layer.addSublayer(shadowLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPath()
    }

    func configure(cornerRadius: CGFloat,
                   color: UIColor,
                   radius: CGFloat,
                   corners: UIRectCorner) {
        currentCornerRadius = cornerRadius
        currentColor = color
        currentRadius = radius
        currentCorners = corners
        setNeedsLayout()
    }

    private func updateShadowPath() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        shadowLayer.frame = bounds
        shadowLayer.cornerRadius = currentCornerRadius
        shapeLayer.frame = shadowLayer.bounds

        let insetRect = bounds.insetBy(dx: -currentRadius, dy: -currentRadius)

        let outerPath: UIBezierPath
        let innerPath: UIBezierPath

        if currentCorners == .allCorners {
            outerPath = UIBezierPath(roundedRect: insetRect, cornerRadius: currentCornerRadius)
            innerPath = UIBezierPath(roundedRect: bounds, cornerRadius: currentCornerRadius).reversing()
        } else {
            outerPath = UIBezierPath(roundedRect: insetRect,
                                     byRoundingCorners: currentCorners,
                                     cornerRadii: CGSize(width: currentCornerRadius, height: currentCornerRadius))
            innerPath = UIBezierPath(roundedRect: bounds,
                                     byRoundingCorners: currentCorners,
                                     cornerRadii: CGSize(width: currentCornerRadius, height: currentCornerRadius)).reversing()
        }

        outerPath.append(innerPath)

        shapeLayer.path = outerPath.cgPath
        shapeLayer.shadowColor = currentColor.cgColor
        shapeLayer.shadowOffset = .zero
        shapeLayer.shadowOpacity = 1
        shapeLayer.shadowRadius = currentRadius
    }
}


