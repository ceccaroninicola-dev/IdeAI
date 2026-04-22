import UIKit
import Flutter

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {

  let flutterEngine = FlutterEngine(name: "main_engine")
  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    registerSafePlugins()
    return true
  }

  private func registerSafePlugins() {
    // Plugin da ESCLUDERE (crash SIGSEGV su iOS 26)
    // Quando il bug sarà fixato, rimuovere dalla lista e tornare a GeneratedPluginRegistrant
    let excludedPlugins: Set<String> = [
      "WebViewFlutterPlugin",
      "FLTWebViewFlutterPlugin"
    ]

    let safePlugins = [
      "FPPPackageInfoPlusPlugin",
      "FPPSharePlusPlugin"
    ]

    for name in safePlugins {
      if excludedPlugins.contains(name) { continue }
      if let registrar = flutterEngine.registrar(forPlugin: name),
         let cls = NSClassFromString(name) as? NSObjectProtocol {
        cls.perform(NSSelectorFromString("registerWithRegistrar:"), with: registrar)
      }
    }
  }
}
