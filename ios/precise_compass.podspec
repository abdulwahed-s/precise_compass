#
# precise_compass — iOS plugin podspec.
# See http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'precise_compass'
  s.version          = '0.1.0'
  s.summary          = 'Honest, high-accuracy Flutter compass.'
  s.description      = <<-DESC
Continuous heading accuracy in degrees, confidence scoring, sensor fusion and
reliable calibration detection for Flutter.
                       DESC
  s.homepage         = 'https://github.com/abdulwahed-s/precise_compass'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'precise_compass authors' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  # Sources live in the Swift Package layout so the plugin supports both
  # Swift Package Manager and CocoaPods from a single source of truth.
  s.source_files     = 'precise_compass/Sources/precise_compass/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
