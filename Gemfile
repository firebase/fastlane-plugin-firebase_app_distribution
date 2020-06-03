source('https://rubygems.org')

gemspec
gem 'google-api-client', '~> 0.34'

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
