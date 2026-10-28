# Amortix — Unity LevelPlay mediation, mirroring the Capital setup.
#
# amortix ships at iOS 16.6, so the pods are pinned there rather than to
# Capital's 17.0. Every pod below supports it (the highest floor in the tree is
# Google-Mobile-Ads-SDK, at iOS 15).
#
# After `pod install` the project must be opened as amortix.xcworkspace —
# building amortix.xcodeproj directly leaves the SDKs unlinked, which compiles
# (every ads file is guarded by `#if canImport(IronSource)`) but silently ships
# an app with no ads at all.
platform :ios, '16.6'
use_frameworks!

target 'amortix' do
  # Unity LevelPlay mediation SDK
  pod 'IronSourceSDK', '~> 8.7'

  # Ad network adapters (compete in LevelPlay auction)
  pod 'IronSourceUnityAdsAdapter' # Unity Ads (same Unity account, no extra signup)
  pod 'IronSourceAdMobAdapter'    # Google AdMob
  pod 'IronSourceFacebookAdapter' # Meta Audience Network

  # Google-certified CMP. Required to serve ads to EEA/UK users; without it
  # AdMob returns no fill (or non-personalised only) for European traffic.
  pod 'GoogleUserMessagingPlatform'

  # The test target only needs the framework search paths — without this it
  # fails with "unable to resolve module dependency: 'IronSource'".
  target 'amortixTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.6'
    end
  end
end
