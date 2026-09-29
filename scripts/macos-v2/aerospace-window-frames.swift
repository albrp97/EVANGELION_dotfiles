import CoreGraphics
import Darwin
import Foundation

struct WindowFrame {
    let windowId: Int
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
    fputs("Could not query visible macOS windows.\n", stderr)
    exit(1)
}

let frames: [WindowFrame] = windows.compactMap { window in
    guard
        let windowNumber = window[kCGWindowNumber as String] as? NSNumber,
        let bounds = window[kCGWindowBounds as String] as? [String: Any],
        let x = (bounds["X"] as? NSNumber)?.doubleValue,
        let y = (bounds["Y"] as? NSNumber)?.doubleValue,
        let width = (bounds["Width"] as? NSNumber)?.doubleValue,
        let height = (bounds["Height"] as? NSNumber)?.doubleValue
    else {
        return nil
    }

    return WindowFrame(
        windowId: windowNumber.intValue,
        x: x,
        y: y,
        width: width,
        height: height
    )
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "--window-order" {
    let requestedArguments = arguments.dropFirst()
    let requestedIds = requestedArguments.compactMap { Int($0) }
    guard !requestedIds.isEmpty, requestedIds.count == requestedArguments.count else {
        fputs("Usage: rice-v2-window-frames --window-order <window-id> [...]\n", stderr)
        exit(2)
    }

    let requestedSet = Set(requestedIds)
    let visibleFrames = frames.filter { requestedSet.contains($0.windowId) }
    if visibleFrames.count != requestedSet.count {
        let visibleIds = Set(visibleFrames.map(\.windowId))
        let missingIds = requestedSet.subtracting(visibleIds).sorted().map { String($0) }
        fputs("Could not find visible frames for window IDs: \(missingIds.joined(separator: ",")).\n", stderr)
        exit(1)
    }

    let orderedFrames = visibleFrames.sorted { first, second in
        if abs(first.x - second.x) > 20 {
            return first.x < second.x
        }
        if abs(first.y - second.y) > 20 {
            return first.y < second.y
        }
        return first.windowId < second.windowId
    }
    for frame in orderedFrames {
        print(frame.windowId)
    }
    exit(0)
}

if !arguments.isEmpty {
    fputs("Usage: rice-v2-window-frames [--window-order <window-id> [...]]\n", stderr)
    exit(2)
}

do {
    let outputFrames: [[String: Any]] = frames.map { frame in
        [
            "windowId": frame.windowId,
            "x": frame.x,
            "y": frame.y,
            "width": frame.width,
            "height": frame.height,
        ]
    }
    let data = try JSONSerialization.data(withJSONObject: outputFrames, options: [.sortedKeys])
    guard let json = String(data: data, encoding: .utf8) else {
        fputs("Could not encode visible window frames as UTF-8.\n", stderr)
        exit(1)
    }
    print(json)
} catch {
    fputs("Could not encode visible window frames: \(error)\n", stderr)
    exit(1)
}
