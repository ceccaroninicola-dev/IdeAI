import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Workaround Flutter #183900: no-op swizzle per prevenire crash SIGSEGV
    // in VSyncClient su iOS 26 + dispositivi ProMotion (120Hz).
    // Deve essere applicato PRIMA di super.application() che avvia il motore.
    Self.swizzleVSyncClientSafety()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Registrazione plugin tramite il nuovo callback UIScene.
  // In Flutter 3.41+ i plugin NON vanno registrati in didFinishLaunchingWithOptions
  // perché il motore implicito non è ancora pronto a quel punto.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: - Workaround VSyncClient SIGSEGV (Flutter #183900)

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
    // No-op: previene SIGSEGV su iOS 26 + ProMotion (task runner NULL).
    // PR #184639 contiene il fix ufficiale, non ancora rilasciato.
  }
}
