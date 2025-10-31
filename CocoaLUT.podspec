Pod::Spec.new do |s|
  s.name         = "CocoaLUT"
  s.version      = begin; File.read('VERSION'); rescue; '9000.0.0'; end
  s.summary      = "LUTs (1D and 3D color lookup tables) for Cocoa applications."
  s.homepage     = "https://github.com/videovillage/CocoaLUT-swift"
  s.license      = 'MIT'
  s.author       = { "Wil Gieseler" => "wil@wilgieseler.com", "Greg Cotten" => "greg@gregcotten.com"}
  s.source       = { :git => "https://github.com/videovillage/CocoaLUT-swift.git", :tag => s.version }

  s.resource_bundle = {'TransferFunctionLUTs' => 'Assets/TransferFunctionLUTs/*.cube'}

  s.swift_version = '6.0'
  s.requires_arc = true
  s.source_files = 'Sources/CocoaLUT-swift/**/*.swift'
  s.frameworks = ['QuartzCore']

  s.platforms = {
    :ios => '13.0',
    :osx => '10.15',
    :tvos => '13.0',
    :watchos => '6.0',
    :visionos => '1.0'
  }

end
