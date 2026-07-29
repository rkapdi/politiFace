import Flutter
import UIKit
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  // Push bridge (see lib/features/notifications/data/push_service.dart):
  // forwards the APNs device token and any silent (content-available)
  // remote notification to Dart over one MethodChannel. No Firebase, no
  // third-party push SDK: APNs registration and delivery are plain
  // UIApplication / UIApplicationDelegate APIs, so a thin native bridge is
  // all a Flutter app needs here. flutter_apns_only (the APNs-only,
  // no-Firebase package that would otherwise fit) is discontinued and
  // three years stale, so this is hand-rolled instead of pulling in an
  // unmaintained dependency.
  private static let pushChannelName = "app.politiface/push"
  private var pushChannel: FlutterMethodChannel?
  private var lastApnsToken: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: AppDelegate.pushChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getApnsToken":
          // Answers with whatever token has been seen so far (nil if
          // registration hasn't completed yet); PushService re-checks on
          // its next activation rather than blocking on this.
          result(self?.lastApnsToken)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      pushChannel = channel
    }

    // Washington Watch: register the BGAppRefresh handler for the task id
    // declared in Info.plist's BGTaskSchedulerPermittedIdentifiers. Apple
    // requires this registration to happen before the app finishes
    // launching, unconditionally — it only wires up the handler and the
    // recurring frequency it falls back to. Whether a refresh is actually
    // *scheduled* right now is a Dart-side decision gated by the "What
    // Washington did" master switch in Settings (see main.dart /
    // WashingtonWatchService, which calls Workmanager().registerPeriodicTask
    // / cancelByUniqueName). Push registration below is a faster path to
    // the same check; this BGAppRefresh task stays wired as the fallback
    // for when push is off or unavailable.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "app.politiface.washingtonRefresh",
      frequency: NSNumber(value: 4 * 60 * 60)
    )

    // Registering for remote notifications is independent of alert/badge/
    // sound permission (that's requested Dart-side by NotificationService):
    // every push this app sends is silent (content-available only, no
    // alert text), and the OS allows registering for + receiving those
    // without ever prompting the user.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    lastApnsToken = token
    pushChannel?.invokeMethod("apnsToken", arguments: token)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    // Best-effort: PushService just finds no token on its next activation
    // (sign-in, foreground) and tries again later. Nothing to surface to
    // the user for a silent, background-only wake mechanism.
  }

  // Silent (content-available) remote notification: wake and run the same
  // Washington Watch check the BGAppRefresh path runs (see
  // WashingtonWatchService, main.dart). Forwarded to Dart; the completion
  // handler waits on that check so iOS can measure whether the wake found
  // new data, within its background-fetch time budget.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    guard let channel = pushChannel else {
      completionHandler(.noData)
      return
    }
    channel.invokeMethod("silentPush", arguments: userInfo) { result in
      if let handled = result as? Bool, handled {
        completionHandler(.newData)
      } else {
        completionHandler(.noData)
      }
    }
  }
}
