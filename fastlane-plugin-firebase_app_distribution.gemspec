# coding: utf-8

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/firebase_app_distribution/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-firebase_app_distribution'
  spec.version       = Fastlane::FirebaseAppDistribution::VERSION
  spec.authors       = ['Stefan Natchev','Manny Jimenez', 'Alonso Salas Infante']
  spec.email         = ['snatchev@google.com', 'mannyjimenez@google.com', 'alonsosi@google.com']

  spec.summary       = 'Release your beta builds to Firebase App Distribution. https://firebase.google.com/docs/app-distribution'
  spec.homepage      = "https://github.com/fastlane/fastlane-plugin-firebase_app_distribution"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency('pry')
  spec.add_development_dependency('bundler')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rspec_junit_formatter')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rubocop', '0.49.1')
  spec.add_development_dependency('rubocop-require_tools')
  spec.add_development_dependency('simplecov')
  spec.add_development_dependency('fastlane', '>= 2.127.1')
end
