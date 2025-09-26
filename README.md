# F1 Telemetry Tracker

A comprehensive iPad application that provides real-time racing telemetry and tracking for F1 24. The app ingests live UDP telemetry data from the F1 24 game and presents it through interactive dashboards, track maps, and historical analysis views.

## Features

### 🏁 Real-Time Dashboard
- **Live Telemetry Data**: Speed, RPM, gear, throttle, brake, and steering inputs
- **Lap Information**: Current lap time, last lap time, best lap time, and position
- **Car Status**: Fuel levels, tyre compound and age, ERS energy and deployment mode
- **Temperature Monitoring**: Engine, brake, and tyre temperatures with color-coded warnings
- **Session Information**: Track name, weather conditions, session type, and time remaining

### 🗺️ Interactive Track Map
- **Live Driver Positions**: Real-time visualization of all cars on track
- **Track Selection**: Support for all F1 circuits with simplified track layouts
- **Position Indicators**: Player car highlighted with position numbers for all drivers
- **Live Leaderboard**: Real-time standings with gaps to leader
- **Track Information**: Current session details and weather conditions

### 📊 Historical Analysis
- **Lap Times**: Detailed lap time analysis with sector breakdowns
- **Performance Charts**: Speed progression, throttle/brake inputs, RPM analysis
- **Temperature History**: Engine, brake, and tyre temperature trends
- **Fuel Management**: Fuel consumption tracking and remaining laps calculation
- **ERS Analysis**: Energy deployment and harvesting visualization
- **Data Export**: Export telemetry data for external analysis

### 📈 Performance Charts
- **Real-Time Graphs**: Live updating charts for speed, inputs, and RPM
- **Temperature Monitoring**: Visual temperature gauges with status indicators
- **Fuel Gauge**: Visual fuel level with consumption rate
- **ERS Energy**: Energy store level and deployment mode visualization
- **Performance Metrics**: Key performance indicators and statistics

## Requirements

- **iPad** running iOS 17.0 or later
- **F1 24** game with UDP telemetry enabled
- **Network Connection**: iPad and gaming device must be on the same network

## Setup Instructions

### 1. F1 24 Game Configuration

1. Launch F1 24 and go to **Settings**
2. Navigate to **Telemetry Settings**
3. Configure these **EXACT** settings (based on working implementations):
   - **UDP Telemetry Output**: ✅ **ON**
   - **UDP Broadcast Mode**: ❌ **OFF** (critical!)
   - **IP Address**: Your iPad's IP address (check in iPad Settings > Wi-Fi)
   - **Port**: `20777` (default)
   - **Send Rate**: `20Hz` (try this first, then 60Hz if needed)
   - **UDP Format**: `2024` (should be automatic)

### 2. iPad App Configuration

1. Open the F1 Telemetry Tracker app
2. Go to the **Settings** tab
3. Configure connection settings:
   - **UDP Host**: Set to `0.0.0.0` to listen on all interfaces
   - **UDP Port**: `20777` (must match F1 24 settings)
4. Tap **Connect** to start receiving telemetry data

### 3. Network Setup

Ensure both devices are connected to the same network:
- **Gaming PC/Console**: Connected via Ethernet or Wi-Fi
- **iPad**: Connected to the same Wi-Fi network
- **Firewall**: Ensure UDP port 20777 is not blocked

## Usage Guide

### Dashboard View
The main dashboard provides a comprehensive overview of your car's performance:
- **Speed & RPM**: Large, easy-to-read displays with gear indicator
- **Lap Information**: Current, last, and best lap times
- **Driver Inputs**: Real-time throttle, brake, and steering visualization
- **Car Status**: Fuel, tyres, and ERS information
- **Temperatures**: Engine, brake, and tyre temperature monitoring

### Track Map View
Visualize your position and that of other drivers:
- **Track Selection**: Choose the correct circuit layout
- **Live Positions**: See all cars moving in real-time
- **Leaderboard**: Current standings with time gaps
- **Track Info**: Session details and conditions

### Lap History View
Analyze your performance over time:
- **Lap Times Table**: Detailed breakdown of each lap
- **Sector Analysis**: Compare sector times and identify improvements
- **Statistics**: Best times, averages, and consistency metrics
- **Charts**: Visual representation of lap time progression

### Performance Charts
Deep dive into telemetry data:
- **Speed Analysis**: Top speed, average speed, and speed traces
- **Input Analysis**: Throttle and brake application patterns
- **RPM Monitoring**: Engine RPM with rev limiter warnings
- **Temperature Trends**: Heat management analysis
- **Fuel Management**: Consumption rates and strategy planning
- **ERS Deployment**: Energy usage and harvesting patterns

## Troubleshooting

### Getting Type 10 (Car Damage) but NOT Type 6 (Car Telemetry) - SOLVED!

If your debug output shows packets like:
```
📦 Received UDP packet: 953 bytes
📋 F1 24 packet received: Type=10, Size=953 bytes
🚨 NO TYPE 6 PACKETS! 
```

**This means F1 24 is sending SOME telemetry but not Car Performance data. Try these fixes:**

1. **Check UDP Broadcast Mode**: Must be **OFF** (this is critical!)
2. **Try Different Session Types**: 
   - Use **Practice Session** instead of **Time Trial**
   - Try **Grand Prix** mode
   - Avoid **Career Mode** initially
3. **Change Send Rate**: Try **20Hz** instead of 60Hz
4. **Restart F1 24** after changing any telemetry settings
5. **Drive More Actively**: Accelerate, brake, change gears, use DRS/ERS
6. **Check Game Mode**: Some modes send limited telemetry

### Connection Issues
- **No Data Received**: Check network connection and F1 24 telemetry settings
- **Intermittent Connection**: Verify firewall settings and network stability  
- **Wrong IP Address**: Ensure F1 24 is configured with correct iPad IP address
- **Getting Only Event Packets**: F1 24 telemetry settings need adjustment (see above)

### Performance Issues
- **Lag or Stuttering**: Reduce telemetry send rate in F1 24 settings
- **Memory Usage**: Clear history data periodically in Settings
- **Battery Drain**: Use while iPad is charging for extended sessions

### Data Issues
- **Missing Lap Times**: Ensure you complete valid laps in F1 24
- **Incorrect Track**: Manually select correct track in Track Map view
- **Temperature Readings**: Data accuracy depends on F1 24 simulation settings

## Technical Details

### Supported Packet Types
- **Car Telemetry**: Speed, throttle, brake, steering, temperatures, etc.
- **Lap Data**: Lap times, sectors, positions, penalties
- **Session Data**: Track info, weather, session type, time remaining
- **Participants**: Driver names, team information, car numbers
- **Car Status**: Fuel, tyres, ERS, damage, flags

### Data Processing
- **Real-Time Updates**: 60Hz telemetry processing for smooth visualization
- **Data Validation**: Invalid laps and corrupted packets are filtered out
- **History Management**: Configurable data retention with automatic cleanup
- **Export Formats**: CSV and JSON export for external analysis tools

### Network Protocol
- **UDP Protocol**: Connectionless protocol for low-latency data transmission
- **Packet Format**: F1 24 telemetry specification compliance
- **Error Handling**: Robust packet parsing with graceful error recovery
- **Connection Management**: Automatic reconnection and status monitoring

## Privacy & Data

- **Local Processing**: All telemetry data is processed locally on your iPad
- **No Cloud Storage**: No data is transmitted to external servers
- **Data Retention**: Historical data is stored locally and can be cleared anytime
- **Network Security**: Only receives data, never sends personal information

## Support

For issues, questions, or feature requests:
1. Check the troubleshooting section above
2. Verify your F1 24 and network configuration
3. Ensure your iPad meets the minimum requirements

## Acknowledgments

- **Codemasters/EA Sports**: For F1 24 and the telemetry API
- **F1 Community**: For telemetry format documentation and testing
- **SwiftUI**: For the modern iOS development framework

---

**Note**: This application is not officially affiliated with Formula 1, Codemasters, or EA Sports. F1 24 is required to use this application.
