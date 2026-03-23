#include "include/flutter_notemus/flutter_notemus_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_notemus_plugin.h"

void FlutterNotemusPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_notemus::FlutterNotemusPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
