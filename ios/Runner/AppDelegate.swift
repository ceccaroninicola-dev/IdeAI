import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  lazy var flutterEngine = FlutterEngine(name: "main_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    registerSafePlugins()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerSafePlugins() {
    let pluginNames = [
      "FPPPackageInfoPlusPlugin",
      "FPPSharePlusPlugin"
    ]

    for name in pluginNames {
      guard let pluginClass = NSClassFromString(name) as? NSObject.Type else {
        print("[IdeAI] Plugin \(name) not found, skipping")
        continue
      }

      let sel = NSSelectorFromString("registerWithRegistrar:")
      guard pluginClass.responds(to: sel) else {
        print("[IdeAI] Plugin \(name) no registerWithRegistrar:")
        continue
      }

      guard let registrar = flutterEngine.registrar(forPlugin: name) else {
        print("[IdeAI] No registrar for \(name)")
        continue
      }

      pluginClass.perform(sel, with: registrar)
      print("[IdeAI] Registered \(name)")
    }
  }
}
