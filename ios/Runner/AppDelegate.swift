import Flutter
import UIKit

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
  let flutterEngine = FlutterEngine(name: "main")

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    return true
  }
}
