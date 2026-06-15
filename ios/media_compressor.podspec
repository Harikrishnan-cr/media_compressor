Pod::Spec.new do |s|
  s.name             = 'media_compressor'
  s.version          = '1.1.0-beta.1'
  s.summary          = 'A Flutter plugin for efficient image and video compression.'
  s.description      = <<-DESC
Compress images and videos on Android, iOS, and Web using native platform
implementations. Supports quality presets, progress, cancel, and release.
                       DESC
  s.homepage         = 'https://github.com/Harikrishnan-cr/media_compressor'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Harikrishnan C R' => 'https://harikrishnancr.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end



# #
# # To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# # Run `pod lib lint media_compressor.podspec` to validate before publishing.
# #
# Pod::Spec.new do |s|
#   s.name             = 'media_compressor'
#   s.version          = '1.0.1'
#   s.summary          = 'A Flutter plugin for efficient image and video compression'
#   s.description      = <<-DESC
# A Flutter plugin for efficient image and video compression
#                        DESC
#   s.homepage         = 'http://example.com'
#   s.license          = { :file => '../LICENSE' }
#   s.author           = { 'Your Company' => 'email@example.com' }
#   s.source           = { :path => '.' }
#   s.source_files = 'Classes/**/*'
#   s.dependency 'Flutter'
#   s.platform = :ios, '13.0'

#   # Flutter.framework does not contain a i386 slice.
#   s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
#   s.swift_version = '5.0'

#   # If your plugin requires a privacy manifest, for example if it uses any
#   # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
#   # plugin's privacy impact, and then uncomment this line. For more information,
#   # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
#   # s.resource_bundles = {'media_compressor_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
# end
