import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web implementation for flutter_notemus native audio channel.
///
/// Web does not provide a native backend in this package yet, so methods
/// return no-op values that keep API behavior consistent across platforms.
class FlutterNotemusWeb {
  static const String _channelName = 'flutter_notemus/native_audio';

  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      _channelName,
      const StandardMethodCodec(),
      registrar,
    );

    channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'nativeInitialize':
      case 'nativeIsReady':
        return false;
      case 'nativeSequencerStart':
      case 'nativeSequencerStop':
      case 'nativeRelease':
      case 'nativeSequencerAddNote':
      case 'nativeSequencerAddMetronome':
      case 'nativeSequencerSetTempo':
      case 'nativeSequencerSetTicksPerQuarter':
      case 'nativeSequencerSetTimeSignature':
      case 'nativeSequencerClear':
      case 'nativeSequencerProcessTies':
        return null;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          message: 'Method ${call.method} is not implemented on web.',
        );
    }
  }
}
