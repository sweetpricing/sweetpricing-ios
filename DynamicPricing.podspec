Pod::Spec.new do |s|
  s.name             = "DynamicPricing"
  s.version          = "1.0.0"
  s.summary          = "Client Library to connect to Sweet Pricing."

  s.description      = <<-DESC
                      Sweet Pricing's iOS client library,
                      which allows you to easily get started with dynamic pricing.
                       DESC

  s.homepage         = "https://sweetpricing.com/"
  s.license          =  { :type => 'MIT' }
  s.author           = { "Sweet Pricing" => "support@sweetpricing.com" }
  s.source           = { :git => "https://github.com/sweetpricing/sweetpricing-ios.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/sweetpricing'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
end
