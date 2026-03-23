Pod::Spec.new do |s|
  s.name             = 'flutter_notemus'
  s.version          = '2.0.0'
  s.summary          = 'Native MIDI backend bridge for Flutter Notemus.'
  s.description      = <<-DESC
Native bridge for low-latency MIDI playback in flutter_notemus.
                       DESC
  s.homepage         = 'https://github.com/alessonqueirozdev-hub/flutter_notemus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Alesson Queiroz' => 'support@musimind.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency       'Flutter'
  s.platform         = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = {'flutter_notemus_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
