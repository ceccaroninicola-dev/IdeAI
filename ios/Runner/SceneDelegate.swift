import UIKit
import Flutter

class SceneDelegate: FlutterSceneDelegate {
  let flutterEngine = FlutterEngine(name: "main_engine")

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    window = UIWindow(windowScene: windowScene)

    flutterEngine.run()
    registerSafePlugins()
    self.registerSceneLifeCycle(with: flutterEngine)

    window?.rootViewController = FlutterViewController(
      engine: flutterEngine, nibName: nil, bundle: nil)
    window?.makeKeyAndVisible()
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  private func registerSafePlugins() {
    // Registra i plugin uno per uno, saltando quelli che crashano su iOS 26.
    // Quando il bug webview sarà fixato, sostituire con:
    //   GeneratedPluginRegistrant.register(with: flutterEngine)
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
