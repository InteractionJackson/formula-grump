import SwiftUI
import UIKit

@main
struct F1TelemetryTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Prevent the device from going to sleep while the app is active
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                .onDisappear {
                    // Re-enable sleep when the app is no longer active
                    UIApplication.shared.isIdleTimerDisabled = false
                }
        }
    }
}
