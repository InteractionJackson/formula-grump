import SwiftUI

struct ConnectionStatusView: View {
    @ObservedObject var viewModel: TelemetryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                VStack(spacing: 16) {
                    // Status indicator
                    HStack {
                        Circle()
                            .fill(viewModel.isConnected ? Color.green : Color.red)
                            .frame(width: 20, height: 20)
                        
                        Text(viewModel.connectionStatus)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    // Connection details
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("UDP Port:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("20777")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Packets Received:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(viewModel.packetsReceived)")
                                .foregroundColor(.secondary)
                        }
                        
                        if let lastUpdate = viewModel.lastUpdate {
                            HStack {
                                Text("Last Update:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(lastUpdate, style: .time)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Telemetry Data Preview
                if viewModel.isConnected {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Live Telemetry Data")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            DataTile(title: "Speed", value: "\(viewModel.speedMPH) MPH")
                            DataTile(title: "RPM", value: "\(Int(viewModel.rpm))")
                            DataTile(title: "Gear", value: gearText)
                            DataTile(title: "ERS", value: "\(Int(viewModel.ersCharge / 1000)) kJ")
                            DataTile(title: "Throttle", value: "\(max(0, min(100, Int((viewModel.throttlePercent * 100).isFinite ? viewModel.throttlePercent * 100 : 0))))%")
                            DataTile(title: "Brake", value: "\(max(0, min(100, Int((viewModel.brakePercent * 100).isFinite ? viewModel.brakePercent * 100 : 0))))%")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Setup Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("F1 24 Setup Instructions")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Open F1 24 and go to Settings")
                        Text("2. Navigate to Telemetry Settings")
                        Text("3. Enable UDP Telemetry Output")
                        Text("4. Set IP Address to your iPad's IP")
                        Text("5. Set Port to 20777")
                        Text("6. Set Send Rate to 60Hz")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                // Connection controls
                HStack(spacing: 20) {
                    if viewModel.isConnected {
                        Button("Disconnect") {
                            viewModel.disconnect()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    } else {
                        Button("Connect") {
                            viewModel.connect()
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                    
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Connection Status")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
    
    private var gearText: String {
        switch viewModel.gear {
        case -1: return "R"
        case 0: return "N"
        default: return "\(viewModel.gear)"
        }
    }
}

struct DataTile: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    ConnectionStatusView(viewModel: TelemetryViewModel())
}
