import Cocoa
import FlutterMacOS

public class FlutterNotemusPlugin: NSObject, FlutterPlugin {
  private static let channelName = "flutter_notemus/native_audio"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger)
    let instance = FlutterNotemusPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "nativeInitialize", "nativeIsReady":
      result(false)
    case "nativeSequencerStart",
         "nativeSequencerStop",
         "nativeRelease",
         "nativeSequencerAddNote",
         "nativeSequencerAddMetronome",
         "nativeSequencerSetTempo",
         "nativeSequencerSetTicksPerQuarter",
         "nativeSequencerSetTimeSignature",
         "nativeSequencerClear",
         "nativeSequencerProcessTies":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
