import Foundation
import CoreGraphics

// MARK: - Track Geometry Cache
/// Singleton cache to prevent track geometry recreation and flicker
final class TrackGeometryCache {
    static let shared = TrackGeometryCache()
    
    private var cache: [TrackId: TrackProfile] = [:]
    private let cacheQueue = DispatchQueue(label: "track.geometry.cache", qos: .userInitiated)
    
    private init() {}
    
    /// Thread-safe geometry retrieval with caching
    func geometry(for trackId: TrackId) -> TrackProfile {
        return cacheQueue.sync {
            #if DEBUG
            print("🏁 TRACK CACHE REQUEST: \(trackId.displayName) (raw: \(trackId.rawValue))")
            #endif
            
            if let cached = cache[trackId] {
                #if DEBUG
                print("🏁 TRACK CACHE HIT: \(trackId.displayName)")
                #endif
                return cached
            }
            
            #if DEBUG
            print("🏁 TRACK CACHE MISS: Loading \(trackId.displayName)")
            #endif
            
            let profile = TrackLibrary.loadTrackProfile(for: trackId)
            cache[trackId] = profile
            
            #if DEBUG
            print("🏁 TRACK CACHED: \(trackId.displayName) (\(cache.count) total)")
            #endif
            
            return profile
        }
    }
    
    /// Preload common tracks for better performance
    func preloadCommonTracks() {
        cacheQueue.async {
            let commonTracks: [TrackId] = [.bahrain, .monaco, .britain, .belgium, .unknown]
            for trackId in commonTracks {
                if self.cache[trackId] == nil {
                    let profile = TrackLibrary.loadTrackProfile(for: trackId)
                    self.cache[trackId] = profile
                    #if DEBUG
                    print("🏁 PRELOADED: \(trackId.displayName)")
                    #endif
                }
            }
        }
    }
    
    /// Clear cache (for memory management)
    func clearCache() {
        cacheQueue.sync {
            cache.removeAll()
            #if DEBUG
            print("🏁 TRACK CACHE CLEARED")
            #endif
        }
    }
}
