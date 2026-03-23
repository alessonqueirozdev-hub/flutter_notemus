#include "flutter_notemus_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

namespace flutter_notemus {
namespace {
constexpr auto kChannelName = "flutter_notemus/native_audio";

bool IsVoidMethod(const std::string& method) {
  return method == "nativeSequencerStart" ||
         method == "nativeSequencerStop" ||
         method == "nativeRelease" ||
         method == "nativeSequencerAddNote" ||
         method == "nativeSequencerAddMetronome" ||
         method == "nativeSequencerSetTempo" ||
         method == "nativeSequencerSetTicksPerQuarter" ||
         method == "nativeSequencerSetTimeSignature" ||
         method == "nativeSequencerClear" ||
         method == "nativeSequencerProcessTies";
}
}  // namespace

void FlutterNotemusPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterNotemusPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterNotemusPlugin::FlutterNotemusPlugin() = default;

FlutterNotemusPlugin::~FlutterNotemusPlugin() = default;

void FlutterNotemusPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  if (method == "nativeInitialize" || method == "nativeIsReady") {
    result->Success(flutter::EncodableValue(false));
    return;
  }
  if (IsVoidMethod(method)) {
    result->Success();
    return;
  }
  result->NotImplemented();
}

}  // namespace flutter_notemus
