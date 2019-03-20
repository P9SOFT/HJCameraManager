Pod::Spec.new do |s|

  s.name         = "HJCameraManager"
  s.version      = "2.0.0"
  s.summary      = "HJCameraManager is handling module for iOS Camera."
  s.homepage     = "https://github.com/P9SOFT/HJCameraManager"
  s.license      = { :type => 'MIT' }
  s.author       = { "Tae Hyun Na" => "taehyun.na@gmail.com" }

  s.ios.deployment_target = '8.0'
  s.requires_arc = true

  s.source       = { :git => "https://github.com/P9SOFT/HJCameraManager.git", :tag => "2.0.0" }
  s.source_files  = "Sources/*.{h,m}"
  s.public_header_files = "Sources/*.h"

end
