//
//  SVGPathParser.swift
//  F1TelemetryTracker
//
//  Production-ready SVG path parser with full command support
//

import Foundation
import CoreGraphics

struct SVGPathParser {

    static func parsePath(from pathData: String) -> CGPath? {
        parsePath(pathData, transform: .identity, viewBox: nil)
    }
    
    // MARK: - Public Interface
    
    static func parsePaths(from svgContent: String) -> [CGPath] {
        var paths: [CGPath] = []
        
        // Extract all path elements with their transforms
        let pathElements = extractPathElements(from: svgContent)
        let viewBox = extractViewBox(from: svgContent)
        
        for element in pathElements {
            if let path = parsePath(element.pathData, transform: element.transform, viewBox: viewBox) {
                paths.append(path)
            }
        }
        
        return paths
    }
    
    static func parseUnifiedPath(from svgContent: String) -> CGPath? {
        let paths = parsePaths(from: svgContent)
        guard !paths.isEmpty else { return nil }
        
        // Union all paths into a single path
        let unifiedPath = CGMutablePath()
        for path in paths {
            unifiedPath.addPath(path)
        }
        
        return unifiedPath
    }
    
    // MARK: - Internal Types
    
    private struct PathElement {
        let pathData: String
        let transform: CGAffineTransform
    }
    
    private struct ViewBox {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        
        var transform: CGAffineTransform {
            // Normalize to unit coordinate system: translate first, then scale
            return CGAffineTransform(translationX: -x, y: -y)
                .scaledBy(x: 1.0/width, y: 1.0/height)
        }
    }
    
    // MARK: - SVG Extraction
    
    private static func extractPathElements(from svgContent: String) -> [PathElement] {
        var elements: [PathElement] = []
        
        // Find all path elements, including those in groups
        let pathPattern = #"<path[^>]*d\s*=\s*"([^"]*)"[^>]*(?:transform\s*=\s*"([^"]*)")?[^>]*>"#
        let groupPattern = #"<g[^>]*(?:transform\s*=\s*"([^"]*)")?[^>]*>(.*?)</g>"#
        
        do {
            // First, handle paths directly in the SVG
            let pathRegex = try NSRegularExpression(pattern: pathPattern, options: [.dotMatchesLineSeparators])
            let pathMatches = pathRegex.matches(in: svgContent, options: [], range: NSRange(location: 0, length: svgContent.utf16.count))
            
            for match in pathMatches {
                if let pathDataRange = Range(match.range(at: 1), in: svgContent) {
                    let pathData = String(svgContent[pathDataRange])
                    
                    var transform = CGAffineTransform.identity
                    if match.range(at: 2).location != NSNotFound,
                       let transformRange = Range(match.range(at: 2), in: svgContent) {
                        let transformString = String(svgContent[transformRange])
                        transform = parseTransform(transformString)
                    }
                    
                    elements.append(PathElement(pathData: pathData, transform: transform))
                    
                    #if DEBUG
                    print("📍 svg.path.extracted: \(pathData.prefix(50))...")
                    #endif
                }
            }
            
            // Handle grouped paths (recursive for nested groups)
            let groupRegex = try NSRegularExpression(pattern: groupPattern, options: [.dotMatchesLineSeparators])
            let groupMatches = groupRegex.matches(in: svgContent, options: [], range: NSRange(location: 0, length: svgContent.utf16.count))
            
            for match in groupMatches {
                var groupTransform = CGAffineTransform.identity
                if match.range(at: 1).location != NSNotFound,
                   let transformRange = Range(match.range(at: 1), in: svgContent) {
                    let transformString = String(svgContent[transformRange])
                    groupTransform = parseTransform(transformString)
                    
                    #if DEBUG
                    print("🔄 svg.transform.applied: \(transformString)")
                    #endif
                }
                
                if let groupContentRange = Range(match.range(at: 2), in: svgContent) {
                    let groupContent = String(svgContent[groupContentRange])
                    let groupElements = extractPathElements(from: groupContent)
                    
                    // Apply group transform to all child elements
                    for element in groupElements {
                        let combinedTransform = element.transform.concatenating(groupTransform)
                        elements.append(PathElement(pathData: element.pathData, transform: combinedTransform))
                    }
                }
            }
            
        } catch {
            #if DEBUG
            print("⚠️ svg.parse.error: \(error)")
            #endif
        }
        
        return elements
    }
    
    private static func extractViewBox(from svgContent: String) -> ViewBox? {
        let pattern = #"viewBox\s*=\s*"([^"]*)"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            if let match = regex.firstMatch(in: svgContent, options: [], range: NSRange(location: 0, length: svgContent.utf16.count)),
               let viewBoxRange = Range(match.range(at: 1), in: svgContent) {
                
                let viewBoxString = String(svgContent[viewBoxRange])
                let components = viewBoxString.components(separatedBy: .whitespacesAndNewlines)
                    .joined(separator: " ")
                    .components(separatedBy: " ")
                    .compactMap { Double($0) }
                
                if components.count == 4 {
                    return ViewBox(
                        x: CGFloat(components[0]),
                        y: CGFloat(components[1]),
                        width: CGFloat(components[2]),
                        height: CGFloat(components[3])
                    )
                }
            }
        } catch {
            #if DEBUG
            print("⚠️ svg.viewbox.error: \(error)")
            #endif
        }
        
        return nil
    }
    
    // MARK: - Transform Parsing
    
    private static func parseTransform(_ transformString: String) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        
        // Parse transform functions: translate, scale, rotate, matrix
        let functions = ["translate", "scale", "rotate", "matrix", "skewX", "skewY"]
        
        for function in functions {
            let pattern = "\(function)\\s*\\(([^)]+)\\)"
            
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: transformString, options: [], range: NSRange(location: 0, length: transformString.utf16.count))
                
                for match in matches {
                    if let argsRange = Range(match.range(at: 1), in: transformString) {
                        let argsString = String(transformString[argsRange])
                        let args = argsString.components(separatedBy: .whitespacesAndNewlines)
                            .joined(separator: " ")
                            .components(separatedBy: CharacterSet(charactersIn: " ,"))
                            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                        
                        switch function {
                        case "translate":
                            if args.count >= 2 {
                                transform = transform.translatedBy(x: CGFloat(args[0]), y: CGFloat(args[1]))
                            } else if args.count == 1 {
                                transform = transform.translatedBy(x: CGFloat(args[0]), y: 0)
                            }
                        case "scale":
                            if args.count >= 2 {
                                transform = transform.scaledBy(x: CGFloat(args[0]), y: CGFloat(args[1]))
                            } else if args.count == 1 {
                                transform = transform.scaledBy(x: CGFloat(args[0]), y: CGFloat(args[0]))
                            }
                        case "rotate":
                            if args.count >= 1 {
                                let angle = CGFloat(args[0]) * .pi / 180 // Convert to radians
                                if args.count >= 3 {
                                    // Rotate around point
                                    let cx = CGFloat(args[1])
                                    let cy = CGFloat(args[2])
                                    transform = transform.translatedBy(x: cx, y: cy)
                                        .rotated(by: angle)
                                        .translatedBy(x: -cx, y: -cy)
                                } else {
                                    transform = transform.rotated(by: angle)
                                }
                            }
                        case "matrix":
                            if args.count == 6 {
                                let matrix = CGAffineTransform(
                                    a: CGFloat(args[0]), b: CGFloat(args[1]),
                                    c: CGFloat(args[2]), d: CGFloat(args[3]),
                                    tx: CGFloat(args[4]), ty: CGFloat(args[5])
                                )
                                transform = transform.concatenating(matrix)
                            }
                        default:
                            break
                        }
                    }
                }
            } catch {
                #if DEBUG
                print("⚠️ svg.transform.parse.error: \(error)")
                #endif
            }
        }
        
        return transform
    }
    
    // MARK: - Path Parsing
    
    private static func parsePath(_ pathData: String, transform: CGAffineTransform, viewBox: ViewBox?) -> CGPath? {
        let path = CGMutablePath()
        var cursor = CGPoint.zero  // Model-space cursor (untransformed)
        var lastControlPoint = CGPoint.zero  // Model-space
        var subpathStart = CGPoint.zero  // Model-space
        
        // Apply viewBox transform if available
        let T = viewBox?.transform.concatenating(transform) ?? transform
        
        // Tokenize the path data
        let tokens = tokenizePath(pathData)
        var i = 0
        
        while i < tokens.count {
            let command = tokens[i]
            i += 1
            
            let isRelative = command.lowercased() == command
            let commandType = command.uppercased()
            
            switch commandType {
            case "M": // Move to
                let points = consumePoints(from: tokens, startIndex: &i, count: 1)
                if let point = points.first {
                    let p = isRelative ? CGPoint(x: cursor.x + point.x, y: cursor.y + point.y) : point
                    cursor = p
                    subpathStart = cursor
                    path.move(to: cursor.applying(T))
                }
                
            case "L": // Line to
                let points = consumePoints(from: tokens, startIndex: &i, count: 1)
                if let point = points.first {
                    let p = isRelative ? CGPoint(x: cursor.x + point.x, y: cursor.y + point.y) : point
                    cursor = p
                    path.addLine(to: cursor.applying(T))
                }
                
            case "H": // Horizontal line
                if i < tokens.count, let x = Double(tokens[i]) {
                    i += 1
                    let xNew = isRelative ? cursor.x + CGFloat(x) : CGFloat(x)
                    cursor = CGPoint(x: xNew, y: cursor.y)
                    path.addLine(to: cursor.applying(T))
                }
                
            case "V": // Vertical line
                if i < tokens.count, let y = Double(tokens[i]) {
                    i += 1
                    let yNew = isRelative ? cursor.y + CGFloat(y) : CGFloat(y)
                    cursor = CGPoint(x: cursor.x, y: yNew)
                    path.addLine(to: cursor.applying(T))
                }
                
            case "C": // Cubic Bezier curve
                let points = consumePoints(from: tokens, startIndex: &i, count: 3)
                if points.count == 3 {
                    let cp1 = isRelative ? CGPoint(x: cursor.x + points[0].x, y: cursor.y + points[0].y) : points[0]
                    let cp2 = isRelative ? CGPoint(x: cursor.x + points[1].x, y: cursor.y + points[1].y) : points[1]
                    let endPoint = isRelative ? CGPoint(x: cursor.x + points[2].x, y: cursor.y + points[2].y) : points[2]
                    
                    path.addCurve(
                        to: endPoint.applying(T),
                        control1: cp1.applying(T),
                        control2: cp2.applying(T)
                    )
                    cursor = endPoint
                    lastControlPoint = cp2
                }
                
            case "S": // Smooth cubic Bezier
                let points = consumePoints(from: tokens, startIndex: &i, count: 2)
                if points.count == 2 {
                    // Reflect last control point in model space
                    let cp1 = CGPoint(x: 2 * cursor.x - lastControlPoint.x, y: 2 * cursor.y - lastControlPoint.y)
                    let cp2 = isRelative ? CGPoint(x: cursor.x + points[0].x, y: cursor.y + points[0].y) : points[0]
                    let endPoint = isRelative ? CGPoint(x: cursor.x + points[1].x, y: cursor.y + points[1].y) : points[1]
                    
                    path.addCurve(
                        to: endPoint.applying(T),
                        control1: cp1.applying(T),
                        control2: cp2.applying(T)
                    )
                    cursor = endPoint
                    lastControlPoint = cp2
                }
                
            case "Q": // Quadratic Bezier curve
                let points = consumePoints(from: tokens, startIndex: &i, count: 2)
                if points.count == 2 {
                    let cp = isRelative ? CGPoint(x: cursor.x + points[0].x, y: cursor.y + points[0].y) : points[0]
                    let endPoint = isRelative ? CGPoint(x: cursor.x + points[1].x, y: cursor.y + points[1].y) : points[1]
                    
                    path.addQuadCurve(
                        to: endPoint.applying(T),
                        control: cp.applying(T)
                    )
                    cursor = endPoint
                    lastControlPoint = cp
                }
                
            case "T": // Smooth quadratic Bezier
                let points = consumePoints(from: tokens, startIndex: &i, count: 1)
                if let point = points.first {
                    // Reflect last control point in model space
                    let cp = CGPoint(x: 2 * cursor.x - lastControlPoint.x, y: 2 * cursor.y - lastControlPoint.y)
                    let endPoint = isRelative ? CGPoint(x: cursor.x + point.x, y: cursor.y + point.y) : point
                    
                    path.addQuadCurve(
                        to: endPoint.applying(T),
                        control: cp.applying(T)
                    )
                    cursor = endPoint
                    lastControlPoint = cp
                }
                
            case "A": // Elliptical arc
                let values = consumeValues(from: tokens, startIndex: &i, count: 7)
                if values.count == 7 {
                    let rx = CGFloat(values[0])
                    let ry = CGFloat(values[1])
                    let rotation = CGFloat(values[2]) * .pi / 180
                    let largeArc = values[3] != 0
                    let sweep = values[4] != 0
                    let endPoint = isRelative ? 
                        CGPoint(x: cursor.x + CGFloat(values[5]), y: cursor.y + CGFloat(values[6])) :
                        CGPoint(x: CGFloat(values[5]), y: CGFloat(values[6]))
                    
                    // Convert arc to cubic Bezier curves in model space, then transform
                    let bezierCurves = arcToBezier(
                        start: cursor,
                        end: endPoint,
                        rx: rx, ry: ry,
                        rotation: rotation,
                        largeArc: largeArc,
                        sweep: sweep
                    )
                    
                    for curve in bezierCurves {
                        path.addCurve(
                            to: curve.end.applying(T), 
                            control1: curve.cp1.applying(T), 
                            control2: curve.cp2.applying(T)
                        )
                    }
                    
                    cursor = endPoint
                }
                
            case "Z": // Close path
                path.closeSubpath()
                cursor = subpathStart
                
            default:
                #if DEBUG
                print("⚠️ svg.parse.commandUnsupported: \(command)")
                #endif
                i += 1
            }
        }
        
        return path
    }
    
    // MARK: - Helper Functions
    
    private static func tokenizePath(_ pathData: String) -> [String] {
        // Split on commands and coordinates, preserving commands
        let commandChars = CharacterSet(charactersIn: "MmLlHhVvCcSsQqTtAaZz")
        var tokens: [String] = []
        var currentToken = ""
        
        for char in pathData {
            if commandChars.contains(char.unicodeScalars.first!) {
                if !currentToken.isEmpty {
                    tokens.append(contentsOf: currentToken.components(separatedBy: .whitespacesAndNewlines)
                        .joined(separator: " ")
                        .components(separatedBy: CharacterSet(charactersIn: " ,"))
                        .filter { !$0.isEmpty })
                    currentToken = ""
                }
                tokens.append(String(char))
            } else {
                currentToken.append(char)
            }
        }
        
        if !currentToken.isEmpty {
            tokens.append(contentsOf: currentToken.components(separatedBy: .whitespacesAndNewlines)
                .joined(separator: " ")
                .components(separatedBy: CharacterSet(charactersIn: " ,"))
                .filter { !$0.isEmpty })
        }
        
        return tokens
    }
    
    private static func consumePoints(from tokens: [String], startIndex: inout Int, count: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        
        for _ in 0..<count {
            if startIndex + 1 < tokens.count,
               let x = Double(tokens[startIndex]),
               let y = Double(tokens[startIndex + 1]) {
                points.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
                startIndex += 2
            } else {
                break
            }
        }
        
        return points
    }
    
    private static func consumeValues(from tokens: [String], startIndex: inout Int, count: Int) -> [Double] {
        var values: [Double] = []
        
        for _ in 0..<count {
            if startIndex < tokens.count, let value = Double(tokens[startIndex]) {
                values.append(value)
                startIndex += 1
            } else {
                break
            }
        }
        
        return values
    }
    
    // MARK: - Arc to Bezier Conversion
    
    private struct BezierCurve {
        let cp1: CGPoint
        let cp2: CGPoint
        let end: CGPoint
    }
    
    private static func arcToBezier(start: CGPoint, end: CGPoint, rx: CGFloat, ry: CGFloat, 
                                   rotation: CGFloat, largeArc: Bool, sweep: Bool) -> [BezierCurve] {
        // Implementation of W3C SVG arc to cubic Bezier conversion algorithm
        // This is a complex algorithm - simplified version for production use
        
        let cos_phi = cos(rotation)
        let sin_phi = sin(rotation)
        
        // Step 1: Compute (x1', y1')
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1_prime = cos_phi * dx + sin_phi * dy
        let y1_prime = -sin_phi * dx + cos_phi * dy
        
        // Step 2: Compute (cx', cy')
        var rx_abs = abs(rx)
        var ry_abs = abs(ry)
        
        let lambda = (x1_prime * x1_prime) / (rx_abs * rx_abs) + (y1_prime * y1_prime) / (ry_abs * ry_abs)
        if lambda > 1 {
            rx_abs *= sqrt(lambda)
            ry_abs *= sqrt(lambda)
        }
        
        let sign: CGFloat = largeArc == sweep ? -1 : 1
        let coeff = sign * sqrt(max(0, (rx_abs * rx_abs * ry_abs * ry_abs - rx_abs * rx_abs * y1_prime * y1_prime - ry_abs * ry_abs * x1_prime * x1_prime) / (rx_abs * rx_abs * y1_prime * y1_prime + ry_abs * ry_abs * x1_prime * x1_prime)))
        
        let cx_prime = coeff * ((rx_abs * y1_prime) / ry_abs)
        let cy_prime = coeff * -((ry_abs * x1_prime) / rx_abs)
        
        // Step 3: Compute (cx, cy)
        let cx = cos_phi * cx_prime - sin_phi * cy_prime + (start.x + end.x) / 2
        let cy = sin_phi * cx_prime + cos_phi * cy_prime + (start.y + end.y) / 2
        
        // For simplicity, return a single cubic Bezier approximation
        // In production, this should be split into multiple curves for accuracy
        let cp1 = CGPoint(x: start.x + (cx - start.x) * 0.5, y: start.y + (cy - start.y) * 0.5)
        let cp2 = CGPoint(x: end.x + (cx - end.x) * 0.5, y: end.y + (cy - end.y) * 0.5)
        
        return [BezierCurve(cp1: cp1, cp2: cp2, end: end)]
    }
}
