import AppKit
import CoreGraphics
import Darwin
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Pass the rice-v2-region-screenshot helper path.")
}
guard CGPreflightPostEventAccess() else {
    fatalError("Terminal needs Accessibility permission to post the test mouse drag.")
}

let helper = Process()
helper.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
try helper.run()

func processIDs(named name: String, parentPID: Int32) -> [Int32] {
    let command = Process()
    command.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    command.arguments = ["-P", String(parentPID), "-x", name]
    let output = Pipe()
    command.standardOutput = output
    command.standardError = FileHandle.nullDevice
    do {
        try command.run()
    } catch {
        return []
    }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    command.waitUntilExit()
    return String(data: data, encoding: .utf8)?
        .split(whereSeparator: \.isNewline)
        .compactMap { Int32($0) } ?? []
}

var capturePID: Int32?
for _ in 0..<50 {
    capturePID = processIDs(named: "screencapture", parentPID: helper.processIdentifier).first
    if capturePID != nil {
        break
    }
    Thread.sleep(forTimeInterval: 0.1)
}
guard capturePID != nil else {
    helper.terminate()
    helper.waitUntilExit()
    fatalError("Interactive macOS region selection did not start.")
}

let source = CGEventSource(stateID: .hidSystemState)!
func postMouse(_ type: CGEventType, x: CGFloat, y: CGFloat) {
    let event = CGEvent(
        mouseEventSource: source,
        mouseType: type,
        mouseCursorPosition: CGPoint(x: x, y: y),
        mouseButton: .left
    )!
    event.post(tap: .cghidEventTap)
}

postMouse(.mouseMoved, x: 120, y: 140)
usleep(150_000)
postMouse(.leftMouseDown, x: 120, y: 140)
usleep(150_000)
for step in 1...8 {
    postMouse(.leftMouseDragged, x: 120 + CGFloat(step) * 10, y: 140 + CGFloat(step) * 10)
    usleep(40_000)
}
postMouse(.leftMouseUp, x: 200, y: 220)

for _ in 0..<100 {
    if !helper.isRunning {
        break
    }
    Thread.sleep(forTimeInterval: 0.1)
}
guard !helper.isRunning else {
    if let capturePID {
        kill(capturePID, SIGTERM)
    }
    helper.terminate()
    helper.waitUntilExit()
    fatalError("The screenshot helper did not finish after the region drag.")
}
helper.waitUntilExit()
guard helper.terminationStatus == 0 else {
    fatalError("The screenshot helper exited with status \(helper.terminationStatus).")
}

let pasteboard = NSPasteboard.general
let imageTypes = [
    NSPasteboard.PasteboardType(rawValue: "public.tiff"),
    NSPasteboard.PasteboardType(rawValue: "public.png"),
]
guard
    let imageData = imageTypes.compactMap({ pasteboard.data(forType: $0) }).first,
    let bitmap = NSBitmapImageRep(data: imageData),
    bitmap.pixelsWide > 0,
    bitmap.pixelsHigh > 0
else {
    fatalError("The selected image was not copied to the clipboard.")
}

print("Interactive region copied to the clipboard: \(bitmap.pixelsWide)x\(bitmap.pixelsHigh).")
