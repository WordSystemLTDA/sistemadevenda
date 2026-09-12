import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var canalSincronizacao: FlutterMethodChannel?
  private var envios: [Int: UIBackgroundTaskIdentifier] = [:]
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let canal = FlutterMethodChannel(
      name: "bigchef/sincronizacao",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    canalSincronizacao = canal
    canal.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "iniciarEnvio":
        var tarefa = UIBackgroundTaskIdentifier.invalid
        tarefa = UIApplication.shared.beginBackgroundTask(withName: "Enviar pedidos") { [weak self] in
          self?.concluirEnvio(tarefa.rawValue)
        }
        if tarefa == .invalid {
          result(nil)
        } else {
          self.envios[tarefa.rawValue] = tarefa
          result(tarefa.rawValue)
        }
      case "concluirEnvio":
        if let id = call.arguments as? Int { self.concluirEnvio(id) }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func concluirEnvio(_ id: Int) {
    guard let tarefa = envios.removeValue(forKey: id) else { return }
    UIApplication.shared.endBackgroundTask(tarefa)
  }
}
