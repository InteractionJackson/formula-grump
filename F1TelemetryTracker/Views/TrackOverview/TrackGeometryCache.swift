//
//  TrackGeometryCache.swift
//  F1TelemetryTracker
//
//  Production-ready track geometry cache with stable identity
//

import Foundation
import CoreGraphics

// MARK: - Track Geometry Cache
final class TrackGeometryCache {
    static let shared = TrackGeometryCache()
    
    private var cache: [TrackId: PolylineGeometry] = [:]
    private let queue = DispatchQueue(label: "track.geometry.cache", qos: .userInitiated)
    
    private init() {
        preloadCommonTracks()
    }
    
    /// Get geometry for track ID with memoization
    func geometry(for trackId: TrackId) -> PolylineGeometry {
        return queue.sync {
            if let cached = cache[trackId] {
                #if DEBUG
                print("🏁 track.geometry.cache.hit: \(trackId.displayName)")
                #endif
                return cached
            }
            
            #if DEBUG
            print("🏁 track.geometry.cache.miss: Loading \(trackId.displayName)")
            #endif
            
            let geometry = loadGeometry(for: trackId)
            cache[trackId] = geometry
            
            #if DEBUG
            print("🏁 track.geometry.cached: \(trackId.displayName) (\(cache.count) total)")
            #endif
            
            return geometry
        }
    }
    
    /// Preload common tracks to prevent UI delays
    func preloadCommonTracks() {
        let commonTracks: [TrackId] = [.bahrain, .monaco, .britain, .italy, .usa, .unknown]
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            for trackId in commonTracks {
                _ = self?.geometry(for: trackId)
            }
        }
    }
    
    /// Clear cache (for memory pressure)
    func clearCache() {
        queue.sync {
            cache.removeAll()
            #if DEBUG
            print("🏁 track.geometry.cache.cleared")
            #endif
        }
    }
    
    // MARK: - Private Loading
    
    private func loadGeometry(for trackId: TrackId) -> PolylineGeometry {
        // Try to load from SVG first
        if let svgGeometry = loadSVGGeometry(for: trackId) {
            return svgGeometry
        }
        
        // Fallback to simple geometry
        #if DEBUG
        print("⚠️ track.geometry.fallbackUsed: \(trackId.displayName)")
        #endif
        
        return createFallbackGeometry(for: trackId)
    }
    
    private func loadSVGGeometry(for trackId: TrackId) -> PolylineGeometry? {
        guard let filename = svgFilename(for: trackId) else { return nil }
        
        // Try Bundle.main first (app target)
        var svgPath = Bundle.main.path(forResource: filename.replacingOccurrences(of: ".svg", with: ""), ofType: "svg")
        
        // Fallback to direct file path for development
        if svgPath == nil {
            svgPath = "/Users/mattjackson/Documents/GitHub/formula-grump/F1TelemetryTracker/Assets.xcassets/track outlines/\(filename)"
        }
        
        guard let path = svgPath else {
            #if DEBUG
            print("⚠️ svg.file.notFound: \(filename)")
            #endif
            return nil
        }
        
        do {
            let svgContent = try String(contentsOfFile: path, encoding: .utf8)
            
            guard let cgPath = SVGPathParser.parseUnifiedPath(from: svgContent) else {
                #if DEBUG
                print("⚠️ svg.parse.failed: \(filename)")
                #endif
                return nil
            }
            
            // Flatten the path with appropriate tolerance
            let tolerance: CGFloat = 2.0 // 2 points tolerance for smooth curves
            let geometry = PolylineGeometry.fromPath(cgPath, tolerance: tolerance)
            
            #if DEBUG
            print("✅ svg.geometry.loaded: \(filename) -> \(geometry.points.count) points")
            #endif
            
            return geometry
            
        } catch {
            #if DEBUG
            print("⚠️ svg.file.readError: \(filename) - \(error)")
            #endif
            return nil
        }
    }
    
    private func createFallbackGeometry(for trackId: TrackId) -> PolylineGeometry {
        // Create appropriate fallback based on track type
        switch trackId {
        case .monaco:
            return PolylineGeometry(points: monacoFallbackPoints())
        case .unknown:
            return PolylineGeometry(points: genericOvalPoints())
        default:
            return PolylineGeometry(points: genericCircuitPoints())
        }
    }
    
    // MARK: - SVG Filename Mapping
    
    private func svgFilename(for trackId: TrackId) -> String? {
        switch trackId {
        case .melbourne: return "Albert Park.svg"
        case .bahrain: return "Bahrain.svg"
        case .azerbaijan: return "Baku City.svg"
        case .spain: return "Barcelona-Catalunya.svg"
        case .usa: return "Circuit of the Americas.svg"
        case .canada: return "Gilles Villeneuve.svg"
        case .hungary: return "Hungaroring.svg"
        case .imola: return "Imola.svg"
        case .brazil: return "Interlagos.svg"
        case .jeddah: return "Jeddah Corniche.svg"
        case .saudi: return "Jeddah.svg"
        case .lasVegas: return "Las Vegas.svg"
        case .qatar: return "Lusail.svg"
        case .singapore: return "Marina Bay.svg"
        case .mexico: return "Mexico.svg"
        case .miami: return "Miami.svg"
        case .monaco: return "Monaco.svg"
        case .italy: return "Monza.svg"
        case .austria: return "Red Bull Ring.svg"
        case .china: return "Shanghai.svg"
        case .britain: return "Silverstone.svg"
        case .belgium: return "Spa-Francorchamps.svg"
        case .japan: return "Suzuka.svg"
        case .abuDhabi: return "Yas Marina.svg"
        default: return nil
        }
    }
    
    // MARK: - Fallback Geometries
    
    private func genericOvalPoints() -> [CGPoint] {
        return [
            CGPoint(x: 150, y: 100),  // Start
            CGPoint(x: 250, y: 100),  // Turn 1
            CGPoint(x: 300, y: 150),  // Turn 2
            CGPoint(x: 250, y: 200),  // Turn 3
            CGPoint(x: 150, y: 200),  // Turn 4
            CGPoint(x: 100, y: 150),  // Turn 5
            CGPoint(x: 150, y: 100)   // Back to start
        ]
    }
    
    private func genericCircuitPoints() -> [CGPoint] {
        // More complex circuit shape for most tracks
        return [
            CGPoint(x: 100, y: 150),  // Start/finish
            CGPoint(x: 150, y: 130),  // Turn 1
            CGPoint(x: 200, y: 100),  // Turn 2
            CGPoint(x: 280, y: 80),   // Long straight
            CGPoint(x: 350, y: 100),  // Turn 3
            CGPoint(x: 380, y: 140),  // Turn 4
            CGPoint(x: 350, y: 180),  // Turn 5
            CGPoint(x: 300, y: 200),  // Turn 6
            CGPoint(x: 220, y: 210),  // Turn 7
            CGPoint(x: 150, y: 200),  // Turn 8
            CGPoint(x: 80, y: 180),   // Turn 9
            CGPoint(x: 60, y: 150),   // Final turn
            CGPoint(x: 100, y: 150)   // Back to start
        ]
    }
    
    private func monacoFallbackPoints() -> [CGPoint] {
        // Monaco-specific street circuit shape
        return [
            CGPoint(x: 50, y: 100),   // Start/finish
            CGPoint(x: 80, y: 90),    // Sainte Devote
            CGPoint(x: 120, y: 70),   // Uphill to Casino
            CGPoint(x: 180, y: 50),   // Casino Square
            CGPoint(x: 220, y: 60),   // Mirabeau
            CGPoint(x: 250, y: 80),   // Hairpin approach
            CGPoint(x: 240, y: 120),  // Hairpin
            CGPoint(x: 200, y: 140),  // Portier
            CGPoint(x: 150, y: 150),  // Tunnel
            CGPoint(x: 100, y: 140),  // Chicane
            CGPoint(x: 70, y: 120),   // Tabac
            CGPoint(x: 50, y: 100)    // Back to start
        ]
    }
}