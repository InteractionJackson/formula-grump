import SwiftUI

struct DashboardView: View {
    @StateObject private var telemetryViewModel = TelemetryViewModel()
    @State private var showingConnectionStatus = false
    
    var body: some View {
        TabView {
            dashboardPage
                .tag(0)

            LeaderboardView()
                .environmentObject(telemetryViewModel)
                .tag(1)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .background(AppColors.appBackground)
    }
    
    private var dashboardPage: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ConnectionHeader(
                    isConnected: telemetryViewModel.isConnected,
                    onTapStatus: { showingConnectionStatus = true }
                )

                HStack(spacing: 24) {
                    VStack(spacing: 24) {
                        SpeedTile(viewModel: telemetryViewModel)
                        CarConditionView(
                            engineTemperature: UInt16(telemetryViewModel.engineTemperature),
                            brakesTemperature: telemetryViewModel.brakesTemperature,
                            tyresSurfaceTemperature: telemetryViewModel.tyresSurfaceTemperature
                        )
                        .environmentObject(telemetryViewModel)
                    }

                    VStack(spacing: 24) {
                        SplitsView(
                            currentLapTime: formatTime(telemetryViewModel.currentLapTime),
                            sector1Time: formatSectorTime(telemetryViewModel.sector1Time),
                            sector2Time: formatSectorTime(telemetryViewModel.sector2Time),
                            sector3Time: formatSectorTime(telemetryViewModel.sector3Time),
                            lastLapTime: formatTime(telemetryViewModel.lastLapTime),
                            bestLapTime: formatTime(telemetryViewModel.bestLapTime)
                        )

                        TrackOverviewTile()
                            .environmentObject(telemetryViewModel)
                    }
                }
                .padding(.horizontal, 30)

                Spacer()
            }
            .padding(.top, 20)
        }
        .sheet(isPresented: $showingConnectionStatus) {
            ConnectionStatusView(viewModel: telemetryViewModel)
        }
        .onAppear { telemetryViewModel.connect() }
        .onDisappear { telemetryViewModel.disconnect() }
    }
    
    private func formatTime(_ seconds: Float) -> String {
        guard seconds > 0 else { return "00:00:00" }
        let totalMs = Int(seconds * 1000)
        let minutes = totalMs / 60000
        let secs = (totalMs % 60000) / 1000
        let ms = totalMs % 1000
        return String(format: "%02d:%02d:%02d", minutes, secs, ms / 10)
    }
    
    private func formatSectorTime(_ seconds: Float) -> String {
        guard seconds > 0 else { return "--:--.---" }
        let totalMs = Int(seconds * 1000)
        let minutes = totalMs / 60000
        let secs = (totalMs % 60000) / 1000
        let ms = totalMs % 1000
        return String(format: "%d:%02d.%03d", minutes, secs, ms)
    }
}

struct ConnectionHeader: View {
    let isConnected: Bool
    let onTapStatus: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isConnected ? AppColors.green : AppColors.red)
                    .frame(width: 12, height: 12)
                Text(isConnected ? "Connected" : "Offline")
                    .font(AppTypography.label())
                    .foregroundStyle(AppColors.labelText)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(AppColors.secondaryTileBackground)
            .neutralInfoTile()
            .onTapGesture { onTapStatus() }

            Spacer()

            Text("Formula Grump")
                .font(AppTypography.secondaryData())
                .foregroundStyle(AppColors.primaryData)
        }
        .padding(.horizontal, 30)
    }
}

struct SpeedTile: View {
    @ObservedObject var viewModel: TelemetryViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AppColors.tileTitle)
                    Text("Speed, RPM, DRS & Gear")
                        .font(AppTypography.tileTitle())
                        .foregroundStyle(AppColors.tileTitle)
                    Spacer()
                }
                .padding(.top, AppLayout.tilePadding)

                HStack(alignment: .center) {
                    VStack(spacing: 8) {
                        Text("\(viewModel.speedMPH)")
                            .font(AppTypography.primaryData())
                            .foregroundStyle(AppColors.primaryData)
                        Text("MPH")
                            .font(AppTypography.label())
                            .foregroundStyle(AppColors.labelText)
                    }
                    .frame(maxWidth: .infinity)

                    CircularGaugeView(rpmValue: viewModel.rpmValue, ersValue: viewModel.ersValue)
                        .scaleEffect(0.72)
                        .frame(width: 150, height: 150)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 8) {
                        Text(gearDisplayText(for: viewModel.gear))
                            .font(AppTypography.primaryData())
                            .foregroundStyle(AppColors.primaryData)
                        Text("Gear")
                            .font(AppTypography.label())
                            .foregroundStyle(AppColors.labelText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, AppLayout.tilePadding)
            }
            .padding(.horizontal, AppLayout.tilePadding)
            .primaryRowBackground(cornerRadius: AppLayout.tileCornerRadius, corners: [.topLeft, .topRight])

            HStack(spacing: 16) {
                LabeledBar(title: "Brake", progress: viewModel.brakePercent, activeColor: AppColors.red)
                DRSIndicator(isActive: viewModel.isDRSActive)
                LabeledBar(title: "Throttle", progress: viewModel.throttlePercent, activeColor: AppColors.green)
            }
            .padding(AppLayout.tilePadding)
            .secondaryRowBackground(cornerRadius: AppLayout.tileCornerRadius, corners: [.bottomLeft, .bottomRight])
        }
        .primaryTileBackground()
    }

    private func gearDisplayText(for gear: Int) -> String {
        switch gear {
        case -1: return "R"
        case 0: return "N"
        default: return "\(gear)"
        }
    }
}

private struct LabeledBar: View {
    let title: String
    let progress: Double
    let activeColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index < Int((progress * 10).clamped(to: 0...10)) ? activeColor : activeColor.opacity(0.2))
                        .frame(height: 12)
                }
            }

            Text(title.uppercased())
                .font(AppTypography.label())
                .foregroundStyle(AppColors.labelText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DRSIndicator: View {
    let isActive: Bool

    var body: some View {
        Text("DRS")
            .font(AppTypography.secondaryData())
            .foregroundStyle(isActive ? AppColors.primaryData : AppColors.labelText)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? AppColors.blue.opacity(0.3) : AppColors.secondaryTileBackground)
            )
            .neutralInfoTile(cornerRadius: 10)
            .frame(minWidth: 72)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    DashboardView()
}