import AppKit
import Foundation

@main
@MainActor
struct SetWallpaper {
    static func main() {
        if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--current" {
            let screens = NSScreen.screens
            guard !screens.isEmpty else {
                FileHandle.standardError.write(Data("macOS reports no active displays.\n".utf8))
                exit(1)
            }
            for screen in screens {
                guard let currentImage = NSWorkspace.shared.desktopImageURL(for: screen) else {
                    FileHandle.standardError.write(
                        Data("Could not read the wallpaper on display \(screen.localizedName).\n".utf8)
                    )
                    exit(1)
                }
                print(currentImage.standardizedFileURL.path)
            }
            return
        }

        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("Usage: set-wallpaper <image-file>|--current\n".utf8))
            exit(2)
        }

        let imageURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: imageURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            FileHandle.standardError.write(Data("Wallpaper image does not exist: \(imageURL.path)\n".utf8))
            exit(66)
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            FileHandle.standardError.write(Data("macOS reports no active displays.\n".utf8))
            exit(1)
        }

        for screen in screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
            } catch {
                FileHandle.standardError.write(
                    Data("Could not set wallpaper on display \(screen.localizedName): \(error)\n".utf8)
                )
                exit(1)
            }
        }
    }
}
