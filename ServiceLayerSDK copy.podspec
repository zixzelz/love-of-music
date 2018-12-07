#
# Be sure to run `pod lib lint ServiceLayerSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ServiceLayerSDK'
  s.version          = '0.1.1'
  s.summary          = 'ServiceLayerSDK'
  s.homepage         = 'https://github.com/zixzelz@gmail.com/ServiceLayerSDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'zixzelz' => 'zixzelz@gmail.com' }
  s.source           = { :git => 'https://github.com/zixzelz@gmail.com/ServiceLayerSDK.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.module_name  = 'ServiceLayerSDK'
  s.default_subspec = 'SLCore'

  s.subspec 'SLCore' do |c|
      c.source_files = 'ServiceLayerSDK/Source/SLCore/**/*'
#      c.exclude_files = 'ServiceLayerSDK/Sources/UIKit/**/*'

      c.frameworks = 'Foundation'
      c.dependency 'ReactiveCocoa'
  end
  
  s.subspec 'ServiceLayerUIKit' do |ss|
      ss.source_files = 'ServiceLayerSDK/Source/ServiceLayerUIKit/**/*'
#      ss.exclude_files = 'ServiceLayerSDK/Sources/Core/**/*'

      ss.frameworks = 'UIKit'
      ss.dependency 'ServiceLayerSDK/SLCore'
      ss.dependency 'ReactiveCocoa'
  end
  
  s.subspec 'CoreData' do |cd|
      cd.source_files = 'ServiceLayerSDK/Source/CoreData/**/*'

      cd.frameworks = 'CoreData'
      cd.dependency 'ServiceLayerSDK/SLCore'
  end
end
