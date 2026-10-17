import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // تسجيل إضافات Flutter قبل بدء التطبيق على iOS.
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
