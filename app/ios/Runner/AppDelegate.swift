import Flutter
import UIKit
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Washington Watch: register the BGAppRefresh handler for the task id
    // declared in Info.plist's BGTaskSchedulerPermittedIdentifiers. Apple
    // requires this registration to happen before the app finishes
    // launching, unconditionally — it only wires up the handler and the
    // recurring frequency it falls back to. Whether a refresh is actually
    // *scheduled* right now is a Dart-side decision gated by the "What
    // Washington did" master switch in Settings (see main.dart /
    // WashingtonWatchService, which calls Workmanager().registerPeriodicTask
    // / cancelByUniqueName).
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "app.politiface.washingtonRefresh",
      frequency: NSNumber(value: 4 * 60 * 60)
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
