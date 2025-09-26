import SwiftUI
import WebKit

struct CarConditionView: View {
    @EnvironmentObject var telemetryViewModel: TelemetryViewModel
    
    let engineTemperature: UInt16
    let brakesTemperature: [UInt16] // [RL, RR, FL, FR]
    let tyresSurfaceTemperature: [UInt8] // [RL, RR, FL, FR]
    
    // Design tokens - matching dashboard design system
    struct T {
        static let topCard     = Color(hex: "#FFFFFF")
        static let text        = Color(hex: "#0B0F14")
        static let textSub     = Color(hex: "#6D7A88")
        
        static let rCard: CGFloat = 24
        static let padCard: CGFloat = 16
        static let gap: CGFloat = 12
        
        // Condition colors
        static let goodColor = Color(hex: "#30DB47")
        static let warningColor = Color(hex: "#FFA500")
        static let criticalColor = Color(hex: "#FF4444")
    }
    
    var body: some View {
        // SINGLE TILE with white top and darker bottom section
        VStack(spacing: 0) {
            // TOP SECTION: White background with title and car diagram
            VStack(alignment: .leading, spacing: T.gap) {
                // Title row
                HStack(spacing: 10) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(T.text)
                    Text("Car Condition")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(T.text)
                    Spacer()
                }
                
                // Car diagram with dynamic SVG styling
                DynamicCarSVG(
                    engineCondition: engineCondition,
                    brakeConditions: brakeConditions,
                    tyreConditions: tyreConditions
                )
                .frame(maxWidth: .infinity, maxHeight: 200)
            }
            .padding(T.padCard)
            .background(T.topCard)
            
            // BOTTOM SECTION: Darker background with tyre information tiles
            HStack(spacing: T.gap) {
                TyreTile(title: "TYRES", value: telemetryViewModel.tyreCompound)
                TyreTile(title: "LIFESPAN", value: "\(telemetryViewModel.tyreAge) laps")
            }
            .padding(T.padCard)
            .background(Color(hex: "#F6F8F9"))
        }
        .clipShape(RoundedRectangle(cornerRadius: T.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: T.rCard, style: .continuous)
                .stroke(Color(hex: "#EFEFEF"), lineWidth: 1)
        )
    }
    
    // MARK: - Computed Properties for Condition Assessment
    
    private var engineCondition: ComponentCondition {
        let temp = Int(engineTemperature)
        if temp < 90 { return .good }
        else if temp < 110 { return .warning }
        else { return .critical }
    }
    
    private var brakeConditions: [ComponentCondition] {
        return brakesTemperature.map { temp in
            let tempInt = Int(temp)
            if tempInt < 300 { return .good }
            else if tempInt < 500 { return .warning }
            else { return .critical }
        }
    }
    
    private var tyreConditions: [ComponentCondition] {
        return tyresSurfaceTemperature.map { temp in
            let tempInt = Int(temp)
            if tempInt < 80 { return .good }
            else if tempInt < 100 { return .warning }
            else { return .critical }
        }
    }
}

// MARK: - Supporting Views

struct DynamicCarSVG: View {
    let engineCondition: ComponentCondition
    let brakeConditions: [ComponentCondition]
    let tyreConditions: [ComponentCondition]
    
    var body: some View {
        DynamicSVGWebView(
            engineCondition: engineCondition,
            brakeConditions: brakeConditions,
            tyreConditions: tyreConditions
        )
        .aspectRatio(117/291, contentMode: .fit)
    }
}

struct DynamicSVGWebView: UIViewRepresentable {
    let engineCondition: ComponentCondition
    let brakeConditions: [ComponentCondition]
    let tyreConditions: [ComponentCondition]
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let htmlContent = generateDynamicSVGHTML()
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    private func generateDynamicSVGHTML() -> String {
        let rlTyreColor = tyreConditions.count > 0 ? tyreConditions[0].hexColor : ComponentCondition.good.hexColor
        let rrTyreColor = tyreConditions.count > 1 ? tyreConditions[1].hexColor : ComponentCondition.good.hexColor
        let flTyreColor = tyreConditions.count > 2 ? tyreConditions[2].hexColor : ComponentCondition.good.hexColor
        let frTyreColor = tyreConditions.count > 3 ? tyreConditions[3].hexColor : ComponentCondition.good.hexColor
        
        let rlBrakeColor = brakeConditions.count > 0 ? brakeConditions[0].hexColor : ComponentCondition.good.hexColor
        let rrBrakeColor = brakeConditions.count > 1 ? brakeConditions[1].hexColor : ComponentCondition.good.hexColor
        let flBrakeColor = brakeConditions.count > 2 ? brakeConditions[2].hexColor : ComponentCondition.good.hexColor
        let frBrakeColor = brakeConditions.count > 3 ? brakeConditions[3].hexColor : ComponentCondition.good.hexColor
        
        let engineColor = engineCondition.hexColor
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { 
                    margin: 0; 
                    padding: 0; 
                    background: transparent;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                }
                svg {
                    width: 100%;
                    height: 100%;
                    max-width: 100vw;
                    max-height: 100vh;
                }
            </style>
        </head>
        <body>
            <svg width="117" height="291" viewBox="0 0 117 291" fill="none" xmlns="http://www.w3.org/2000/svg">
                <g id="car_overlay" clip-path="url(#clip0_14_12)">
                    <rect id="rl_tyre" y="240" width="25" height="42" rx="7" fill="\(rlTyreColor)" fill-opacity="0.3" stroke="\(rlTyreColor)" stroke-width="1"/>
                    <rect id="rr_tyre" x="92" y="240" width="25" height="42" rx="7" fill="\(rrTyreColor)" fill-opacity="0.3" stroke="\(rrTyreColor)" stroke-width="1"/>
                    <rect id="fl_tyre" x="1" y="51" width="24" height="40" rx="7" fill="\(flTyreColor)" fill-opacity="0.3" stroke="\(flTyreColor)" stroke-width="1"/>
                    <rect id="fr_tyre" x="92" y="51" width="24" height="40" rx="7" fill="\(frTyreColor)" fill-opacity="0.3" stroke="\(frTyreColor)" stroke-width="1"/>
                    <rect id="fr_brake" x="84" y="62" width="6" height="18" rx="3" fill="\(frBrakeColor)" fill-opacity="0.3" stroke="\(frBrakeColor)" stroke-width="1"/>
                    <rect id="rr_brake" x="83" y="254" width="6" height="15" rx="3" fill="\(rrBrakeColor)" fill-opacity="0.3" stroke="\(rrBrakeColor)" stroke-width="1"/>
                    <rect id="fl_brake" x="27" y="62" width="6" height="18" rx="3" fill="\(flBrakeColor)" fill-opacity="0.3" stroke="\(flBrakeColor)" stroke-width="1"/>
                    <rect id="rl_brake" x="28" y="254" width="6" height="15" rx="3" fill="\(rlBrakeColor)" fill-opacity="0.3" stroke="\(rlBrakeColor)" stroke-width="1"/>
                    <path id="front_wing_left" d="M4.5 19.8925C4.5 19.0556 5.02108 18.3072 5.80598 18.0168L51.806 0.996786C53.1121 0.513512 54.5 1.47983 54.5 2.87251V6.26393C54.5 7.02148 54.072 7.714 53.3944 8.05279L47.6056 10.9472C46.928 11.286 46.5 11.9785 46.5 12.7361V29.0846C46.5 29.6659 46.2471 30.2184 45.8072 30.5983L35.8911 39.1623C35.6346 39.3838 35.326 39.5365 34.9943 39.606L6.91043 45.4946C5.66777 45.7551 4.5 44.8068 4.5 43.5372V19.8925Z" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <path id="front_wing_right" d="M112 19.8925C112 19.0556 111.479 18.3072 110.694 18.0168L64.694 0.996786C63.3879 0.513512 62 1.47983 62 2.87251V6.26393C62 7.02148 62.428 7.714 63.1056 8.05279L68.8944 10.9472C69.572 11.286 70 11.9785 70 12.7361V29.0846C70 29.6659 70.2529 30.2184 70.6928 30.5983L80.6089 39.1623C80.8654 39.3838 81.174 39.5365 81.5057 39.606L109.59 45.4946C110.832 45.7551 112 44.8068 112 43.5372V19.8925Z" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <path id="left_intake" d="M23.36 123.346C23.4503 123.123 23.6179 122.94 23.8322 122.83L45.5452 111.743C46.2106 111.403 47 111.886 47 112.633V125.032C47 125.328 46.8682 125.61 46.6402 125.8L35.1133 135.406C35.0382 135.468 34.9543 135.519 34.8643 135.558L17.2253 143.054C16.4049 143.403 15.5727 142.585 15.9072 141.759L23.36 123.346Z" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <path id="right_intake" d="M94.64 123.346C94.5497 123.123 94.3821 122.94 94.1678 122.83L72.4548 111.743C71.7894 111.403 71 111.886 71 112.633V125.032C71 125.328 71.1318 125.61 71.3598 125.8L82.8867 135.406C82.9618 135.468 83.0457 135.519 83.1357 135.558L100.775 143.054C101.595 143.403 102.427 142.585 102.093 141.759L94.64 123.346Z" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <path id="underfloor" d="M14.5594 157.534C14.5248 156.409 15.4281 155.5 16.5533 155.5H16.6056C17.6681 155.5 18.547 156.32 18.6224 157.38C19.0602 163.537 20.7823 183.615 25.5 199.5C30.7172 217.067 36.9725 229.932 37.8864 231.773C37.9643 231.93 38.0183 232.087 38.0544 232.258L41.4922 248.588C41.7539 249.831 40.8055 251 39.5351 251H36.4928C35.6073 251 34.8273 250.418 34.5754 249.569L31.5675 239.431C31.3156 238.582 30.5375 238 29.6521 238C28.074 238 25.5747 238 23.8275 238C23.2971 238 22.7885 237.811 22.5064 237.362C17.0097 228.607 14.9222 169.316 14.5594 157.534Z" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <path id="underfloor_2" d="M102.441 157.534C102.475 156.409 101.572 155.5 100.447 155.5H100.394C99.3319 155.5 98.453 156.32 98.3776 157.38C97.9398 163.537 96.2177 183.615 91.5 199.5C86.2828 217.067 80.0275 229.932 79.1136 231.773C79.0357 231.93 78.9817 232.087 78.9456 232.258L75.5078 248.588C75.2461 249.831 76.1945 251 77.4649 251H80.5072C81.3927 251 82.1727 250.418 82.4246 249.569L85.4325 239.431C85.6844 238.582 86.4625 238 87.3479 238C88.926 238 91.4253 238 93.1725 238C93.7029 238 94.2115 237.811 94.4936 237.362C99.9903 228.607 102.078 169.316 102.441 157.534Z" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <path id="sidepod_left" d="M21 155C27.5 155 38.5 155 38.5 155L46.5 167L43.3984 173.5H34.5C34.5 173.5 33.6016 190 38.5 200.5C43.3984 211 50 216.5 50 216.5V250H46.5C46.5 250 45 235 41.5 227C38 219 21 185.5 21 155Z" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <path id="sidepod_right" d="M95 155C88.5 155 77.5 155 77.5 155L69.5 167L72.6016 173.5H81.5C81.5 173.5 82.3984 190 77.5 200.5C72.6016 211 66 216.5 66 216.5V250H69.5C69.5 250 71 235 74.5 227C78 219 95 185.5 95 155Z" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <rect id="Rectangle 18" x="55" y="218" width="7" height="32" rx="2" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <rect id="drs" x="38" y="256" width="42" height="12" rx="2" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <path id="rear_wing" d="M27.4319 275.272C27.7658 273.937 28.9657 273 30.3423 273H86.5935C87.9996 273 89.217 273.977 89.522 275.349L92.1887 287.349C92.6051 289.223 91.1794 291 89.2602 291H27.3423C25.3906 291 23.9585 289.166 24.4319 287.272L27.4319 275.272Z" fill="#30DB47" fill-opacity="0.3" stroke="#30DB47" stroke-width="1"/>
                    <path id="engine" d="M50.5847 168.449C50.8305 167.591 51.6149 167 52.5072 167H65.4582C66.3668 167 67.1612 167.612 67.3924 168.491L69.1623 175.217C69.367 175.994 70.0175 176.574 70.8136 176.688L74.7828 177.255C75.7681 177.395 76.5 178.239 76.5 179.235V195.982C76.5 196.621 76.1938 197.223 75.6763 197.599L71.1269 200.908C71.0424 200.969 70.9629 201.037 70.889 201.111L66.9023 205.098C66.6393 205.361 66.4549 205.692 66.3697 206.054L64.8628 212.458C64.6502 213.362 63.8441 214 62.916 214H54.5366C53.6305 214 52.8376 213.391 52.6041 212.515L51.1223 206.959C51.0419 206.657 50.892 206.379 50.6847 206.145L47 202L41.0344 195.576C40.6909 195.206 40.5 194.719 40.5 194.215V179.259C40.5 178.253 41.2472 177.404 42.2449 177.276L46.9717 176.668C47.7636 176.566 48.4191 176.003 48.6392 175.235L50.5847 168.449Z" fill="\(engineColor)" fill-opacity="0.3" stroke="\(engineColor)" stroke-width="1"/>
                </g>
                <defs>
                    <clipPath id="clip0_14_12">
                        <rect width="117" height="291" fill="white"/>
                    </clipPath>
                </defs>
            </svg>
        </body>
        </html>
        """
    }
}


struct TyreTile: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CarConditionView.T.textSub)
                .tracking(0.5)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(CarConditionView.T.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: "#DBE5E6"), lineWidth: 1)
        )
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.3))
                .stroke(color, lineWidth: 1)
                .frame(width: 12, height: 12)
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CarConditionView.T.textSub)
        }
    }
}

// MARK: - Supporting Types

enum ComponentCondition {
    case good
    case warning
    case critical
    
    var color: Color {
        switch self {
        case .good: return CarConditionView.T.goodColor
        case .warning: return CarConditionView.T.warningColor
        case .critical: return CarConditionView.T.criticalColor
        }
    }
    
    var hexColor: String {
        switch self {
        case .good: return "#30DB47"
        case .warning: return "#FFA500"
        case .critical: return "#FF4444"
        }
    }
}

// MARK: - Helpers
// Color extension is already defined in DashboardView.swift

// MARK: - Preview

struct CarConditionView_Previews: PreviewProvider {
    static var previews: some View {
        CarConditionView(
            engineTemperature: 95,
            brakesTemperature: [250, 280, 320, 290],
            tyresSurfaceTemperature: [85, 88, 92, 87]
        )
        .padding()
        .background(Color(hex: "#F6F8FA"))
    }
}
