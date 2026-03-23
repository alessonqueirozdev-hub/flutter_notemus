#ifndef FLUTTER_PLUGIN_FLUTTER_NOTEMUS_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_NOTEMUS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_notemus {

class FlutterNotemusPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  FlutterNotemusPlugin();
  ~FlutterNotemusPlugin() override;

  FlutterNotemusPlugin(const FlutterNotemusPlugin&) = delete;
  FlutterNotemusPlugin& operator=(const FlutterNotemusPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_notemus

#endif  // FLUTTER_PLUGIN_FLUTTER_NOTEMUS_PLUGIN_H_
