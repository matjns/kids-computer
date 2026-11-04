#if os(macOS)
import AppKit
import Darwin
import Foundation
import KidsComputerCore

@main
enum KidsComputerMain {
    static func main() {
        if CommandLine.arguments.contains("--help") {
            print(helpText)
            return
        }
        if CommandLine.arguments.contains("--version") {
            print(LauncherRelease.version)
            return
        }
        if CommandLine.arguments.contains("--reset-parent-password") {
            resetParentPassword()
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    private static func resetParentPassword() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let store = ConfigStore(directory: SupportLayout.directory(home: home))
        do {
            try KeychainPasswordStore.delete()
            var config = try store.loadConfig()
            config.parentPasswordHash = nil
            try store.saveConfig(config)
            print("Parent password cleared for this account.")
            print("The next parent gesture will ask for a new password.")
            print(store.configURL.path)
        } catch {
            fputs("Couldn't clear the parent password: \(error)\n", stderr)
            exit(1)
        }
    }

    private static let helpText = """
    Kids Computer \(LauncherRelease.version)

    With no arguments, opens the full-screen launcher.
    Build the app with ./build.sh and open the copy in /Applications.

      --reset-parent-password   Clear the parent password for this Mac account
      --version                 Print the version
      --help                    Show this help

    Run --reset-parent-password while logged in as the account that uses the launcher.
    """
}
#else
import Glibc

@main
enum KidsComputerMain {
    static func main() {
        let message = "Kids Computer runs on macOS 14 or later. See README.md.\n"
        _ = message.withCString { fputs($0, stderr) }
        exit(1)
    }
}
#endif
