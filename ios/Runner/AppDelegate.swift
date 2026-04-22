import UIKit
import Flutter
import package_info_plus
import share_plus

@main
@objc class AppDelegate: FlutterAppDelegate {
  lazy var flutterEngine = FlutterEngine(name: "main_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()

    // Registrazione manuale — NO GeneratedPluginRegistrant
    // WebViewFlutterPlugin escluso: crash SIGSEGV su iOS 26
    FPPPackageInfoPlusPlugin.register(
      with: flutterEngine.registrar(forPlugin: "FPPPackageInfoPlusPlugin")!)
    FPPSharePlusPlugin.register(
      with: flutterEngine.registrar(forPlugin: "FPPSharePlusPlugin")!)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
