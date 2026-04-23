import Flutter
import UIKit

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
  let flutterEngine = FlutterEngine(name: "main")

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Workaround Flutter #183900: swizzle per prevenire crash VSyncClient
    // su iOS 26 + dispositivi ProMotion. Aggiunge guard nil engine prima
    // di creare il VSync client per touch rate correction.
    Self.swizzleVSyncClientSafety()

    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    return true
  }

  private static var hasSwizzled = false

  private static func swizzleVSyncClientSafety() {
    guard !hasSwizzled else { return }
    hasSwizzled = true

    let original = NSSelectorFromString("createTouchRateCorrectionVSyncClientIfNeeded")
    let safe = #selector(FlutterViewController.ideai_safeCreateTouchRateCorrectionVSyncClient)

    guard let originalMethod = class_getInstanceMethod(FlutterViewController.self, original),
          let safeMethod = class_getInstanceMethod(FlutterViewController.self, safe) else {
      return
    }

    method_exchangeImplementations(originalMethod, safeMethod)
  }
}

extension FlutterViewController {
  @objc func ideai_safeCreateTouchRateCorrectionVSyncClient() {
    // No-op: salta completamente createTouchRateCorrectionVSyncClientIfNeeded
    // per evitare SIGSEGV su iOS 26 + ProMotion (task runner NULL).
    // Sacrifica touch rate correction ma previene il crash.
  }
}
