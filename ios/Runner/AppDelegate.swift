import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Diagnostica: log di avvio e crash handler
    logBoot("didFinishLaunchingWithOptions START")

    NSSetUncaughtExceptionHandler { exception in
      let log = """
      CRASH: \(exception.name.rawValue)
      REASON: \(exception.reason ?? "unknown")
      STACK: \(exception.callStackSymbols.joined(separator: "\n"))
      """
      let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
      if let dir = paths.first {
        try? log.write(toFile: "\(dir)/ideai_crash.log", atomically: true, encoding: .utf8)
      }
      NSLog("[IdeAI] CRASH: %@", log)
    }

    logBoot("calling super.application")
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    logBoot("super.application returned \(result)")
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    logBoot("didInitializeImplicitFlutterEngine START")
    SafePluginRegistrant.register(with: engineBridge.pluginRegistry)
    logBoot("didInitializeImplicitFlutterEngine DONE")
  }

  private func logBoot(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "[\(ts)] \(msg)\n"
    NSLog("[IdeAI] %@", msg)
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    if let dir = paths.first {
      let file = "\(dir)/ideai_boot.log"
      if let handle = FileHandle(forWritingAtPath: file) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
      } else {
        try? line.write(toFile: file, atomically: true, encoding: .utf8)
      }
    }
  }
}
