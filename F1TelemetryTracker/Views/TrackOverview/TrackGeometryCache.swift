//
//  TrackGeometryCache.swift
//  F1TelemetryTracker
//
//  Production-ready track geometry cache with stable identity
//

import Foundation
import CoreGraphics
import UIKit

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
        
        guard let svgContent = loadSVG(named: filename) else {
            #if DEBUG
            print("⚠️ svg.file.notFound: \(filename)")
            #endif
            return nil
        }
            
        guard let cgPath = SVGPathParser.parseUnifiedPath(from: svgContent) else {
            #if DEBUG
            print("⚠️ svg.parse.failed: \(filename)")
            #endif
            return nil
        }
        
        // Flatten the path with scale-aware tolerance
        let bbox = cgPath.boundingBox
        let maxDim = max(bbox.width, bbox.height)
        let tolerance = maxDim * 0.002   // ~0.2% of size for smooth curves
        let geometry = PolylineGeometry.fromPath(cgPath, tolerance: tolerance)
        
        #if DEBUG
        print("📐 svg.flattening: bbox=\(bbox.width)x\(bbox.height), tolerance=\(tolerance)")
        print("✅ svg.geometry.loaded: \(filename) -> \(geometry.points.count) points")
        #endif
        
        return geometry
    }
    
    /// Asset-catalog friendly SVG loader with multiple fallbacks
    private func loadSVG(named filename: String) -> String? {
        let name = filename.replacingOccurrences(of: ".svg", with: "")
        
        // Try Bundle.main URL first (app target)
        if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            #if DEBUG
            print("📁 svg.loaded.bundle: \(filename)")
            #endif
            return content
        }
        
        // Try NSDataAsset (for asset catalog)
        if let dataAsset = NSDataAsset(name: name),
           let content = String(data: dataAsset.data, encoding: .utf8) {
            #if DEBUG
            print("📁 svg.loaded.dataAsset: \(filename)")
            #endif
            return content
        }
        
        // Development fallback: direct file path
        let devPath = "/Users/mattjackson/Documents/GitHub/formula-grump/F1TelemetryTracker/Assets.xcassets/track outlines/\(filename)"
        if let content = try? String(contentsOfFile: devPath, encoding: .utf8) {
            #if DEBUG
            print("📁 svg.loaded.devPath: \(filename)")
            #endif
            return content
        }
        
        return nil
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